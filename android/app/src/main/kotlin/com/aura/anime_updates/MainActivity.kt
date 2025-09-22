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

        torrentManager = TorrentManager.getInstance(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startSession" -> {
                    torrentManager.startSession()
                    result.success(null)
                }
                "addTorrent" -> {
                    val releaseId = call.argument<String>("releaseId")!!
                    val magnetUrl = call.argument<String>("magnetUrl")!!
                    val savePath = call.argument<String>("savePath")!!
                    val fileName = call.argument<String>("fileName")!!
                    val showName = call.argument<String>("showName")!!
                    val episode = call.argument<String>("episode")!!
                    torrentManager.addTorrent(releaseId, magnetUrl, savePath, fileName, showName, episode)
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
                "deleteTorrentFile" -> {
                    val releaseId = call.argument<String>("releaseId")!!
                    torrentManager.deleteTorrent(releaseId)
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
                "setDownloadSpeedLimit" -> {
                    val limit = call.argument<Int>("speedLimit")!!
                    torrentManager.setDownloadSpeedLimit(limit)
                    result.success(null)
                }
                "getCompletedTorrents" -> {
                    try {
                        val completed = torrentManager.loadCompleted()
                        val completedList = completed.map { it.toMap() }
                        result.success(completedList)
                    } catch (e: Exception) {
                        result.error("LOAD_ERROR", "Failed to load completed torrents", e.message)
                    }
                }

                "getManagedTorrents" -> {
                    try {
                        val torrents = torrentManager.getManagedTorrents()
                
                        val torrentsList = torrents.map { torrent ->
                            torrent.toMap()
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
                    TorrentEventSinkManager.instance.setEventSink(events)
                    torrentManager.torrentEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    TorrentEventSinkManager.instance.clearEventSink()
                    torrentManager.torrentEventSink = null
                }
            })

    }

    override fun onStop() {
        super.onStop()
        torrentManager.persistSessionState()
    }
}
