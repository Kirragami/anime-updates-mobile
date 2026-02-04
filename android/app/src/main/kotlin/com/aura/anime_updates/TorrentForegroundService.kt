package com.aura.anime_updates

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.Timer
import java.util.TimerTask

class TorrentForegroundService : Service() {
    companion object {
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID = "torrent_download_channel"
        const val CHANNEL_NAME = "Torrent Downloads"
    }

    private lateinit var torrentManager: TorrentManager
    private lateinit var notificationManager: NotificationManager
    private var updateTimer: Timer? = null

    override fun onCreate() {
        super.onCreate()
        torrentManager = TorrentManager.getInstance(this)
        notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, createInitialNotification())
        
        updateTimer = Timer().apply {
            scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    updateNotification()
                }
            }, 0, 2000)
        }

        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notifications for active torrent downloads"
                enableLights(true)
                lightColor = Color.BLUE
                enableVibration(false)
                setSound(null, null)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createInitialNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            action = "DOWNLOAD_MANAGER"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Torrent Downloads")
            .setContentText("Initializing...")
            .setSmallIcon(R.drawable.ic_download_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification() {
        CoroutineScope(Dispatchers.Main).launch {
            try {
                val allTorrents = torrentManager.getManagedTorrents().filter { 
                    it.status != "completed" && it.status != "deleted" 
                }
                
         
                val activeTorrents = allTorrents.filter { it.status == "downloading" }
                val pausedTorrents = allTorrents.filter { it.status == "paused" }
                val completedTorrents = torrentManager.getManagedTorrents().filter { it.status == "completed" }
                
                if (activeTorrents.isEmpty() && pausedTorrents.isEmpty()) {
                 
                    if (completedTorrents.isNotEmpty()) {
                    
                        val intent = Intent(this@TorrentForegroundService, MainActivity::class.java).apply {
                            action = "DOWNLOAD_MANAGER"
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                        }
                        val pendingIntent = PendingIntent.getActivity(
                            this@TorrentForegroundService, 0, intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )

                        val notification = NotificationCompat.Builder(this@TorrentForegroundService, CHANNEL_ID)
                            .setContentTitle("Downloads completed!")
                            .setContentText("All requested downloads are finished")
                            .setSmallIcon(R.drawable.ic_download_notification)
                            .setContentIntent(pendingIntent)
                            .setAutoCancel(true)
                            .build()
                        
                        notificationManager.notify(NOTIFICATION_ID, notification)
                        
              
                        Handler(Looper.getMainLooper()).postDelayed({
                            notificationManager.cancel(NOTIFICATION_ID) 
                            stopSelf()
                        }, 5000) 
                    } else {
                    
                        stopSelf()
                    }
                    return@launch
                }

            
                val totalProgress = if (allTorrents.isNotEmpty()) {
                    allTorrents.sumOf { it.progress } / allTorrents.size
                } else 0.0

                val activeTorrentsCount = allTorrents.filter { it.status == "downloading" }.size
                val pausedTorrentsCount = allTorrents.filter { it.status == "paused" }.size

                val title = if (activeTorrentsCount > 0) {
                    "Downloading (${activeTorrentsCount} active)"
                } else {
                    "Paused (${pausedTorrentsCount} paused)"
                }

                val text = if (allTorrents.size == 1) {
                    "${allTorrents.first().showName} - ${allTorrents.first().episode} - ${String.format("%.1f", totalProgress)}%"
                } else {
                    "${allTorrents.size} torrents - ${String.format("%.1f", totalProgress)}%"
                }

                val intent = Intent(this@TorrentForegroundService, MainActivity::class.java).apply {
                    action = "DOWNLOAD_MANAGER"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                }
                val pendingIntent = PendingIntent.getActivity(
                    this@TorrentForegroundService, 0, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

          
                val expandedText = StringBuilder()
                allTorrents.forEach { torrent ->
                    expandedText.append("${torrent.showName} - E${torrent.episode}: ${String.format("%.1f", torrent.progress)}%\n")
                }
                expandedText.append("\nTotal: ${allTorrents.size} | Active: $activeTorrentsCount | Paused: $pausedTorrentsCount")

                val notification = NotificationCompat.Builder(this@TorrentForegroundService, CHANNEL_ID)
                    .setContentTitle(title)
                    .setContentText(text) 
                    .setSmallIcon(R.drawable.ic_download_notification)
                    .setContentIntent(pendingIntent)
                    .setOngoing(true)
                    .setProgress(100, totalProgress.toInt(), false)
                    .setStyle(NotificationCompat.BigTextStyle().bigText(expandedText.toString()))
                    .setCategory(NotificationCompat.CATEGORY_PROGRESS)
                    .build()

                notificationManager.notify(NOTIFICATION_ID, notification)
            } catch (e: Exception) {
             
                e.printStackTrace()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        updateTimer?.cancel()
        torrentManager.persistSessionState()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}