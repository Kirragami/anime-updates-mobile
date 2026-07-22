package com.aura.anime_updates

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment

object UpdateDownloadManager {
    private const val PREFS_NAME = "update_download"
    private const val DOWNLOAD_ID_KEY = "download_id"
    private const val APK_FILE_NAME = "anime_updates_update.apk"

    fun enqueue(context: Context, downloadUrl: String): Map<String, Any> {
        val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val previousId = prefs.getLong(DOWNLOAD_ID_KEY, -1L)
        if (previousId != -1L) {
            manager.remove(previousId)
        }

        val request = DownloadManager.Request(Uri.parse(downloadUrl))
            .setTitle("Anime Updates update")
            .setDescription("Downloading the latest version")
            .setMimeType(APK_MIME_TYPE)
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
            .setDestinationInExternalFilesDir(
                context,
                Environment.DIRECTORY_DOWNLOADS,
                APK_FILE_NAME,
            )

        val downloadId = manager.enqueue(request)
        prefs.edit().putLong(DOWNLOAD_ID_KEY, downloadId).apply()

        return mapOf(
            "success" to true,
            "downloadId" to downloadId,
            "status" to "queued",
        )
    }

    fun getStatus(context: Context): Map<String, Any> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val downloadId = prefs.getLong(DOWNLOAD_ID_KEY, -1L)
        if (downloadId == -1L) {
            return mapOf("status" to "none")
        }

        val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val query = DownloadManager.Query().setFilterById(downloadId)
        manager.query(query).use { cursor ->
            if (!cursor.moveToFirst()) {
                return mapOf("status" to "none")
            }

            val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
            val downloaded =
                cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
            val total =
                cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
            val reason = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))

            return mapOf(
                "status" to statusName(status),
                "downloadedBytes" to downloaded,
                "totalBytes" to total,
                "reason" to reason,
                "downloadId" to downloadId,
            )
        }
    }

    fun isTrackedDownload(context: Context, downloadId: Long): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getLong(DOWNLOAD_ID_KEY, -1L) == downloadId
    }

    fun getDownloadedApkUri(context: Context, downloadId: Long): Uri? {
        val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        return manager.getUriForDownloadedFile(downloadId)
    }

    fun openCompletedUpdate(context: Context): Map<String, Any> {
        val status = getStatus(context)
        if (status["status"] != "completed") {
            return mapOf(
                "success" to false,
                "message" to "The update download is not ready to install.",
            )
        }

        val downloadId = status["downloadId"] as? Long
            ?: return mapOf(
                "success" to false,
                "message" to "The update download could not be found.",
            )
        val apkUri = getDownloadedApkUri(context, downloadId)
            ?: return mapOf(
                "success" to false,
                "message" to "The downloaded update file could not be opened.",
            )

        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, APK_MIME_TYPE)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(installIntent)

        return mapOf("success" to true)
    }

    private fun statusName(status: Int): String = when (status) {
        DownloadManager.STATUS_PENDING -> "queued"
        DownloadManager.STATUS_RUNNING -> "downloading"
        DownloadManager.STATUS_PAUSED -> "paused"
        DownloadManager.STATUS_SUCCESSFUL -> "completed"
        DownloadManager.STATUS_FAILED -> "failed"
        else -> "unknown"
    }

    const val APK_MIME_TYPE = "application/vnd.android.package-archive"
}
