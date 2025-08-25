package com.aura.anime_updates

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.frostwire.jlibtorrent.SessionManager
import com.frostwire.jlibtorrent.TorrentHandle
import com.frostwire.jlibtorrent.TorrentInfo
import com.frostwire.jlibtorrent.AddTorrentParams

import java.io.File

class MainActivity: FlutterActivity() {

    private val CHANNEL = "torrent"
    private var sessionManager: SessionManager? = null
    private var handle: TorrentHandle? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startTorrent" -> {
                        val torrentPath: String? = call.argument("torrentPath")
                        val savePath: String? = call.argument("savePath")
                        if (torrentPath != null && savePath != null) {
                            startTorrent(torrentPath, savePath)
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGS", "Missing torrentPath or savePath", null)
                        }
                    }
                    "getProgress" -> {
                        // Note: progress() is now a function
                        result.success(handle?.status()?.progress() ?: 0.0)
                    }
                    "stopTorrent" -> {
                        stopTorrent()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startTorrent(torrentPath: String, savePath: String) {
        sessionManager = SessionManager()

        sessionManager!!.start()

        val ti = TorrentInfo(File(torrentPath))
        val saveDir = File(savePath)

        // Add listener to get the TorrentHandle when ready
        sessionManager!!.addListener(object : SessionManager.Listener {
            override fun onAddTorrent(t: TorrentHandle) {
                handle = t
            }
        })

        // Start the download (no return value)
        sessionManager!!.download(ti, saveDir)
    }



    private fun stopTorrent() {
        handle?.let {
            if (!it.isValid) return
            it.pause()
            sessionManager?.stop()
        }
    }
}
