package com.aura.anime_updates

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aura.anime_updates/torrent"

    private lateinit var torrentManager: TorrentManager

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
                "getStatus" -> {
                    // Load conc hash map metadata from json to memory and return that | or nvm, this can only return strings
                    // platform channels suck, man
                    torrentManager.loadManagedTorrentsSaveFile()
                    result.success("null")
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onStop() {
        super.onStop()
        torrentManager.persistSessionState()
    }
}
