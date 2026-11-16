package cc.xcouture.tink

import org.json.JSONObject

data class TinkMessage(
    val id: String,
    val title: String,
    val body: String,
    val group: String?,
    val url: String?,
    val createdAt: Long
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("title", title)
        put("body", body)
        put("group", group)
        put("url", url)
        put("created_at", createdAt)
    }

    companion object {
        fun fromJson(data: String): TinkMessage = fromJson(JSONObject(data))

        fun fromJson(data: JSONObject): TinkMessage = TinkMessage(
            id = data.get("id").toString(),
            title = data.optString("title"),
            body = data.optString("body"),
            group = data.optString("group").takeIf { it.isNotBlank() },
            url = data.optString("url").takeIf { it.isNotBlank() },
            createdAt = data.optLong("created_at")
        )
    }
}
