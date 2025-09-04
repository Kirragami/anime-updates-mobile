package com.aura.anime_updates

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aura.anime_updates/torrent"
    private val TORRENT_EVENT_CHANNEL = "com.aura.anime_updates/torrentEvents"

    private lateinit var torrentManager: TorrentManager
    private var torrentEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        torrentManager = TorrentManager(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startSession" -> {
                    // val savedSessionState = torrentManager.loadSessionState() // <-- load from disk
                    torrentManager.startSession()
                    result.success(null)
                }
                "addTorrent" -> {
                    val releaseId = call.argument<String>("releaseId")!!
                    val magnetUrl = call.argument<String>("magnetUrl")!!
                    val savePath = call.argument<String>("savePath")!!
                    val fileName = call.argument<String>("fileName")!!
                    torrentManager.addTorrent(releaseId, magnetUrl, savePath, fileName)
                    result.success(null)
                }
                "pauseTorrent" -> {
                    val releaseId = call.argument<String>("releaseId")!!
                    torrentManager.pauseTorrent(releaseId)
                    result.success(null)
                }
                "resumeTorrent" -> {
                    val releaseId = call.argument<String>("releaseId")!!
                    torrentManager.resumeTorrent(releaseId)
                    result.success(null)
                }
                "pauseAllTorrents" -> {
                    torrentManager.pauseAll()
                    result.success(null)
                }
                "resumeAllTorrents" -> {
                    torrentManager.resumeAll()
                    result.success(null)
                }
                "getProgress" -> {
                    val releaseId = call.argument<String>("releaseId")!!
                    val progress = torrentManager.getProgress(releaseId)
                    result.success(progress)
                }
                "getDownloadSpeed" -> {
                    val releaseId = call.argument<String>("releaseId")!!
                    // ishowspeed
                    result.success(null)
                }
                "getCompletedTorrents" -> {
                    try {
                        val completed = torrentManager.loadCompleted()
                        val completedList = completed.map { mapOf("releaseId" to it.releaseId, "fileName" to it.fileName) }
                        result.success(completedList)
                    } catch (e: Exception) {
                        result.error("LOAD_ERROR", "Failed to load completed torrents", e.message)
                    }
                }

                "getManagedTorrents" -> {
                    try {
                        val torrents = torrentManager.getManagedTorrents()
                
                        val torrentsList = torrents.map { torrent ->
                            mapOf(
                                "uniqueId" to torrent.uniqueId,
                                "fileName" to torrent.fileName,
                                "sha1" to torrent.sha1.toString(),
                                "progress" to torrent.progress
                            )
                        }
                        result.success(torrentsList)
                    } catch (e: Exception) {
                        result.error("GET_ERROR", "Failed to get managed torrents", e.message)
                    }
                }

                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, TORRENT_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    torrentEventSink = events
                    torrentManager.torrentEventSink = torrentEventSink
                }

                override fun onCancel(arguments: Any?) {
                    torrentEventSink = null
                    torrentManager.torrentEventSink = null
                }
            })

    }

    override fun onStop() {
        super.onStop()
        torrentManager.persistSessionState()
    }
}
