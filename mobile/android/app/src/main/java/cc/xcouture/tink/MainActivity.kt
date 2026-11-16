package cc.xcouture.tink

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import java.text.DateFormat
import java.util.Date

class MainActivity : ComponentActivity() {
    private val controller by lazy { TinkController(applicationContext) }
    private val permission = registerForActivityResult(ActivityResultContracts.RequestPermission()) {}

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme { TinkScreen(controller, ::requestNotifications) }
        }
    }

    override fun onStart() {
        super.onStart()
        controller.start()
    }

    override fun onStop() {
        controller.stop()
        super.onStop()
    }

    private fun requestNotifications() {
        if (Build.VERSION.SDK_INT >= 33) permission.launch(Manifest.permission.POST_NOTIFICATIONS)
    }
}

@Composable
private fun TinkScreen(controller: TinkController, requestNotificationPermission: () -> Unit) {
    var server by remember { mutableStateOf(controller.serverUrl) }
    var token by remember { mutableStateOf(controller.readToken()) }

    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Text("Tink Mobile", style = MaterialTheme.typography.headlineMedium)
            Text("Android · 前台实时 SSE", style = MaterialTheme.typography.bodySmall)
        }
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("连接状态：" + controller.status)
                    OutlinedTextField(
                        server, { server = it },
                        label = { Text("服务器 HTTPS 地址") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    OutlinedTextField(
                        token, { token = it },
                        label = { Text("Bearer Secret Key") },
                        visualTransformation = PasswordVisualTransformation(),
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    Button(onClick = {
                        requestNotificationPermission()
                        controller.configure(server, token)
                    }) { Text("保存并连接") }
                    TextButton(onClick = { controller.sendTest() }) {
                        Text("发送测试通知")
                    }
                    if (controller.lastError.isNotBlank()) {
                        Text(controller.lastError, color = MaterialTheme.colorScheme.error)
                    }
                    Text(
                        "提示：此版本仅在 App 前台接收实时消息。熄屏推送需要后续接入 FCM / 国产厂商推送。",
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
        }
        item {
            Text("消息记录（本机最多 250 条）", style = MaterialTheme.typography.titleMedium)
            HorizontalDivider()
        }
        if (controller.messages.isEmpty()) {
            item { Text("暂无通知。连接后可发送一条测试通知。") }
        }
        items(controller.messages, key = { it.id }) { message ->
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Text(message.title.ifBlank { "Tink" }, style = MaterialTheme.typography.titleMedium)
                    if (message.body.isNotBlank()) Text(message.body)
                    if (!message.group.isNullOrBlank()) Text(message.group, style = MaterialTheme.typography.labelMedium)
                    if (message.createdAt > 0) {
                        Text(
                            DateFormat.getDateTimeInstance().format(Date(message.createdAt)),
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }
            }
        }
    }
}
