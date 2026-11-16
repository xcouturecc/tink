package cc.xcouture.tink

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import okhttp3.sse.EventSource
import okhttp3.sse.EventSourceListener
import okhttp3.sse.EventSources
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.util.UUID
import java.util.concurrent.TimeUnit

/**
 * Foreground SSE client only. Android background delivery needs a separate FCM or OEM push
 * integration; Android does not guarantee a permanent SSE connection after the UI stops.
 */
class TinkController(context: Context) {
    private val app = context.applicationContext
    private val prefs = app.getSharedPreferences("tink_mobile", Context.MODE_PRIVATE)
    private val vault = TokenVault(app)
    private val notifications = NotificationHelper(app)
    private val handler = Handler(Looper.getMainLooper())
    private val http = OkHttpClient.Builder().callTimeout(15, TimeUnit.SECONDS).build()
    private val streamClient = OkHttpClient.Builder().readTimeout(0, TimeUnit.SECONDS).build()
    private val eventsFactory = EventSources.createFactory(streamClient)
    private var call: Call? = null
    private var eventSource: EventSource? = null
    private var active = false
    private var generation = 0
    private var failures = 0
    private val retry = Runnable { registerDevice() }

    val messages = mutableStateListOf<TinkMessage>()
    var status by mutableStateOf("未配置")
        private set
    var lastError by mutableStateOf("")
        private set

    val serverUrl: String
        get() = prefs.getString("server_url", "") ?: ""
    val deviceId: String
        get() {
            val existing = prefs.getString("device_id", null)
            if (existing != null) return existing
            return UUID.randomUUID().toString().also {
                prefs.edit().putString("device_id", it).apply()
            }
        }

    init {
        val stored = prefs.getString("messages", "[]") ?: "[]"
        runCatching {
            val entries = JSONArray(stored)
            for (i in 0 until entries.length()) {
                messages.add(TinkMessage.fromJson(entries.getJSONObject(i)))
            }
        }
    }

    fun readToken(): String = vault.read()

    fun configure(url: String, token: String) {
        val cleaned = url.trim().trimEnd('/')
        val valid = runCatching {
            val parsed = java.net.URI(cleaned)
            parsed.scheme == "https" && !parsed.host.isNullOrBlank() && parsed.userInfo == null &&
                parsed.rawQuery == null && parsed.rawFragment == null && (parsed.path.isNullOrEmpty() || parsed.path == "/")
        }.getOrDefault(false)
        if (!valid || token.isBlank()) {
            lastError = "请输入 HTTPS 服务器根地址及 Bearer Secret Key"
            return
        }
        stop()
        vault.save(token.trim())
        prefs.edit().putString("server_url", cleaned).putString("last_id", "0").apply()
        messages.clear()
        persist()
        lastError = ""
        start()
    }

    fun start() {
        if (active) return
        if (serverUrl.isBlank() || readToken().isBlank()) {
            status = "等待配置"
            return
        }
        active = true
        generation++
        status = "连接中…"
        failures = 0
        registerDevice()
    }

    fun stop() {
        active = false
        generation++
        handler.removeCallbacks(retry)
        call?.cancel()
        call = null
        eventSource?.cancel()
        eventSource = null
        status = "已暂停（后台）"
    }

    private fun request(path: String, method: String = "GET", payload: JSONObject? = null): Request {
        val builder = Request.Builder()
            .url(serverUrl + path)
            .header("Authorization", "Bearer " + readToken())
            .header("X-Device-ID", deviceId)
        if (method == "POST") {
            builder.post((payload ?: JSONObject()).toString().toRequestBody("application/json".toMediaType()))
        }
        return builder.build()
    }

    private fun registerDevice() {
        if (!active) return
        val currentGeneration = generation
        status = "注册设备…"
        val body = JSONObject()
            .put("id", deviceId)
            .put("name", "Android " + android.os.Build.MODEL)
        val pending = http.newCall(request("/api/v1/devices", "POST", body))
        call = pending
        pending.enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                handler.post {
                    if (active && currentGeneration == generation) reconnect("连接失败，请检查网络")
                }
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    val statusCode = it.code
                    handler.post {
                        if (!active || currentGeneration != generation) return@post
                        if (statusCode in 200..299) {
                            openEvents()
                        } else if (statusCode == 401 || statusCode == 403) {
                            lastError = "认证失败（HTTP " + statusCode + "），请检查密钥"
                            status = "认证失败"
                            active = false
                        } else {
                            reconnect("设备注册失败（HTTP " + statusCode + "）")
                        }
                    }
                }
            }
        })
    }

    private fun openEvents() {
        if (!active) return
        val currentGeneration = generation
        val lastID = prefs.getString("last_id", "0") ?: "0"
        val eventRequest = request("/api/v1/events")
            .newBuilder()
            .header("Accept", "text/event-stream")
            .header("Last-Event-ID", lastID)
            .build()
        eventSource?.cancel()
        eventSource = eventsFactory.newEventSource(eventRequest, object : EventSourceListener() {
            override fun onOpen(eventSource: EventSource, response: Response) {
                handler.post {
                    if (active && currentGeneration == generation) {
                        status = "已连接（前台）"
                        lastError = ""
                        failures = 0
                    }
                }
            }

            override fun onEvent(eventSource: EventSource, id: String?, type: String?, data: String) {
                if (type != "notification") return
                val message = runCatching { TinkMessage.fromJson(data) }.getOrNull() ?: return
                handler.post {
                    if (!active || currentGeneration != generation) return@post
                    if (messages.none { it.id == message.id }) {
                        messages.add(0, message)
                        while (messages.size > 250) messages.removeAt(messages.lastIndex)
                        persist()
                        notifications.display(message)
                    }
                    // Update cursor only after the message has been stored locally.
                    prefs.edit().putString("last_id", id ?: message.id).apply()
                }
            }

            override fun onClosed(eventSource: EventSource) {
                handler.post {
                    if (active && currentGeneration == generation) reconnect("连接已关闭")
                }
            }

            override fun onFailure(eventSource: EventSource, t: Throwable?, response: Response?) {
                handler.post {
                    if (!active || currentGeneration != generation) return@post
                    if (response?.code == 401 || response?.code == 403) {
                        active = false
                        status = "认证失败"
                        lastError = "推送流认证失败（HTTP " + response.code + "）"
                    } else {
                        reconnect("连接中断，准备重试")
                    }
                }
            }
        })
    }

    private fun reconnect(reason: String) {
        if (!active) return
        lastError = reason
        status = "重连中…"
        handler.removeCallbacks(retry)
        val delaySeconds = minOf(60, 1 shl minOf(failures, 6))
        failures++
        handler.postDelayed(retry, delaySeconds * 1000L)
    }

    private fun persist() {
        val array = JSONArray()
        messages.forEach { array.put(it.toJson()) }
        prefs.edit().putString("messages", array.toString()).apply()
    }

    fun sendTest() {
        if (!active) {
            lastError = "请先连接服务器"
            return
        }
        val body = JSONObject()
            .put("devices", JSONArray().put(deviceId))
            .put("title", "Tink Android 测试")
            .put("body", "客户端消息发送与接收测试")
        http.newCall(request("/api/v1/messages", "POST", body)).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                handler.post { lastError = "测试消息发送失败" }
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    val code = it.code
                    handler.post {
                        if (code !in 200..299) lastError = "发送测试消息失败（HTTP " + code + "）"
                    }
                }
            }
        })
    }
}
