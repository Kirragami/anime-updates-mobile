package com.aura.anime_updates

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.frostwire.jlibtorrent.*;
import com.frostwire.jlibtorrent.alerts.AddTorrentAlert;
import com.frostwire.jlibtorrent.alerts.Alert;
import com.frostwire.jlibtorrent.alerts.AlertType;
import com.frostwire.jlibtorrent.alerts.BlockFinishedAlert;
import com.frostwire.jlibtorrent.swig.torrent_flags_t;
import com.frostwire.jlibtorrent.TorrentFlags
import java.io.File
import android.util.Log

class MainActivity : FlutterActivity() {    
    private val CHANNEL = "torrent"
    private var torrentHandle: TorrentHandle? = null
    private var lastProgress: Double = 0.0

    private val sessionManager: SessionManager? by lazy {
        try {
            SessionManager()
        } catch (e: Throwable) {
            e.printStackTrace()
            null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        Log.w("Kirra's Log: ", "configureFlutterEngine called")
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTorrent" -> {
                    Log.w("Kirra's Log: ", "Entered into startTorrent event in Kotlin.")
                    val torrentPath = call.argument<String>("torrentPath") ?: return@setMethodCallHandler
                    val savePath = call.argument<String>("savePath") ?: filesDir.absolutePath

                    startTorrent(torrentPath, savePath)
                    Log.w("Kirra's Log: ", "Started torrent onKotlin side.")
                    result.success("Started")
                }
                "pauseTorrent" -> {
                    pauseTorrent()
                    result.success("Paused")
                }
                "resumeTorrent" -> {
                    resumeTorrent()
                    result.success("Resumed")
                }
                "stopTorrent" -> {
                    stopTorrent()
                    result.success("Stopped")
                }
                "getProgress" -> {
                    result.success(lastProgress)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startTorrent(torrentPath: String, savePath: String) {
        sessionManager?.addListener(object : AlertListener {
            override fun types(): IntArray? = null

            override fun alert(alert: Alert<*>) {
                when (alert.type()) {
                    com.frostwire.jlibtorrent.alerts.AlertType.ADD_TORRENT -> {
                        torrentHandle = (alert as AddTorrentAlert).handle()
                        torrentHandle?.resume()
                    }
                    com.frostwire.jlibtorrent.alerts.AlertType.BLOCK_FINISHED -> {
                        val a = (alert as com.frostwire.jlibtorrent.alerts.BlockFinishedAlert)
                        lastProgress = (a.handle().status().progress() * 100).toDouble()
                    }
                    com.frostwire.jlibtorrent.alerts.AlertType.TORRENT_FINISHED -> {
                        println("Torrent finished")
                    }
                    else -> { /* ignore */ }
                }
            }
        })

        sessionManager?.start()

        val ti = TorrentInfo(File(torrentPath))
        val saveDir = File(savePath)

        sessionManager?.download(ti, saveDir)
    }

    

    private fun pauseTorrent() {
        sessionManager?.pause()
    }



    private fun resumeTorrent() {
        sessionManager?.resume()
    }

    private fun stopTorrent() {
        sessionManager?.stop()
    }
}
