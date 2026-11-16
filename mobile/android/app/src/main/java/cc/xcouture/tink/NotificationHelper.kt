package cc.xcouture.tink

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build

internal class NotificationHelper(private val context: Context) {
    private val manager = context.getSystemService(NotificationManager::class.java)

    init {
        manager.createNotificationChannel(
            NotificationChannel("tink_messages", "Tink 消息", NotificationManager.IMPORTANCE_DEFAULT)
        )
    }

    fun display(message: TinkMessage) {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return

        val link = message.url?.let { runCatching { Uri.parse(it) }.getOrNull() }
        val intent = if (link?.scheme == "https") {
            Intent(Intent.ACTION_VIEW, link)
        } else {
            Intent(context, MainActivity::class.java)
        }

        val pending = PendingIntent.getActivity(
            context,
            message.id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = Notification.Builder(context, "tink_messages")
            .setSmallIcon(R.drawable.ic_stat_tink)
            .setContentTitle(message.title.ifBlank { "Tink" })
            .setContentText(message.body)
            .setStyle(Notification.BigTextStyle().bigText(message.body))
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()

        manager.notify(message.id.hashCode(), notification)
    }
}
