package com.aura.anime_updates

import android.app.DownloadManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

class UpdateDownloadReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != DownloadManager.ACTION_DOWNLOAD_COMPLETE) return

        val downloadId = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
        if (downloadId == -1L || !UpdateDownloadManager.isTrackedDownload(context, downloadId)) {
            return
        }

        val status = UpdateDownloadManager.getStatus(context)
        if (status["status"] != "completed") return

        val apkUri = UpdateDownloadManager.getDownloadedApkUri(context, downloadId) ?: return
        showInstallNotification(context, apkUri)
    }

    private fun showInstallNotification(context: Context, apkUri: android.net.Uri) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, UpdateDownloadManager.APK_MIME_TYPE)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            INSTALL_REQUEST_CODE,
            installIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notificationManager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "App updates",
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
        }

        val notificationBuilder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }
        val notification = notificationBuilder
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle("Update ready")
            .setContentText("Tap to install the latest Anime Updates version.")
            .setStyle(
                Notification.BigTextStyle()
                    .bigText("Tap to install the latest Anime Updates version."),
            )
            .setPriority(Notification.PRIORITY_HIGH)
            .setCategory(Notification.CATEGORY_STATUS)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private companion object {
        const val CHANNEL_ID = "app_update_downloads"
        const val NOTIFICATION_ID = 4101
        const val INSTALL_REQUEST_CODE = 4102
    }
}
