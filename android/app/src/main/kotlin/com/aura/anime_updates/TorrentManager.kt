package com.aura.anime_updates

import android.content.Context
import com.frostwire.jlibtorrent.*
import com.frostwire.jlibtorrent.alerts.*
import com.frostwire.jlibtorrent.swig.torrent_flags_t
import android.util.Log
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import kotlinx.serialization.*
import kotlinx.serialization.json.*

class TorrentManager (private val context: Context) {

    private val sessionManager: SessionManager = SessionManager()
    private val torrentHandles: MutableMap<String, TorrentHandle> = ConcurrentHashMap()
    private val resumeDataMap: MutableMap<String, ByteArray> = ConcurrentHashMap()
    private val managedTorrents = ConcurrentHashMap<String, ManagedTorrent>()
    private val sessionStateSaveFile = File(context.filesDir, "session.state")
    private val managedTorrentsSaveFile = File(context.filesDir, "managedTorrents.json")
    private val torrentFileLocation = File(context.getExternalFilesDir(null), "TorrentFileDownloads")
    private var isSessionStarted = false

    init {
        setupListener()
        loadManagedTorrentsSaveFile()
    }

    /**
     * Start the session. Optionally restore from saved state bytes.
     */
    fun startSession() {
        try {
            println("Trying to start session")
            val savedState = loadSessionState()
            if (savedState == null) {
                sessionManager?.start()
            } else {
                sessionManager?.start(SessionParams(loadSessionState()))
                for (torrent in managedTorrents.values) {
                    sessionManager?.download(TorrentInfo(loadResumeData(torrent.uniqueId)), torrentFileLocation)
                }
            }
            sessionManager?.resume()
        } catch(e: Exception) {
            println(e)
        }
        println("session created kirra sama > <")
        println(sessionManager)
        isSessionStarted = true
    }

    /**
     * Add a torrent to the session with optional resume data
     */
    fun addTorrent(uniqueId: String, magnetUrl: String, savePath: String, fileName: String) {
        sessionManager?.download(magnetUrl, File(savePath), torrent_flags_t())
        val mt = ManagedTorrent(uniqueId, fileName, "", 0.0)
        managedTorrents[uniqueId] = mt
        println("status in addTorrent method")
        println(managedTorrents)
    }

    /**
     * Pause a single torrent
     */
    fun pauseTorrent(uniqueId: String) {
        println("trying to pause " + uniqueId)
        sessionManager?.find(Sha1Hash(managedTorrents[uniqueId]?.sha1))?.pause()
    }

    /**
     * Resume a single torrent
     */
    fun resumeTorrent(uniqueId: String) {
        println("Resuming id " + uniqueId)
        sessionManager?.find(Sha1Hash(managedTorrents[uniqueId]?.sha1))?.resume()
    }

    /**
     * Pause all torrents in the session
     */
    fun pauseAll() {
        for (torrent in managedTorrents.values) {
            sessionManager?.find(Sha1Hash(torrent.sha1))?.pause()
        }
    }

    /**
     * Resume all torrents
     */
    fun resumeAll() {
        for (torrent in managedTorrents.values) {
            sessionManager?.find(Sha1Hash(torrent.sha1))?.resume()
        }
    }

    /**
     * Stop the session entirely (pauses all and stops alerts)
     */
    fun stopSession() {
        sessionManager.stop()
        torrentHandles.clear()
    }

    /**
     * Get the latest progress for a torrent (0.0–100.0)
     */
    fun getProgress(uniqueId: String): Double {
        return managedTorrents[uniqueId]?.progress ?: 0.0
    }

    /**
     * Save resume data for all torrents
     */
    fun saveAllResumeData() {
        torrentHandles.forEach { (_, handle) ->
            handle.saveResumeData()
        }
    }

    /**
     * Save global session state
     */
    fun saveSessionState(): ByteArray {
        return sessionManager.saveState()
    }

    /**
     * Restore a single torrent with saved resume data
     */
    // fun restoreTorrent(uniqueId: String, torrentFile: File, savePath: String, resumeData: ByteArray) {
    //     addTorrent(uniqueId, torrentFile, savePath, resumeData)
    // }

    private fun setupListener() {
        sessionManager.addListener(object : AlertListener {
            override fun types(): IntArray? = null

            override fun alert(alert: Alert<*>) {
                when (alert.type()) {

                    AlertType.ADD_TORRENT -> {
                        println("Received add torrent alert")
                        val addAlert = alert as AddTorrentAlert
                        val handle = addAlert.handle()
                        handle.unsetFlags(TorrentFlags.AUTO_MANAGED)
                        handle.resume()
                        managedTorrents.values.find { it.fileName == handle.name() }?.sha1 = handle.infoHash().toHex()
                        println("This is status in handle, kirra-sama > <")
                        println(managedTorrents)
                    }

                    AlertType.BLOCK_FINISHED -> {
                        val blockAlert = alert as BlockFinishedAlert
                        val handle = blockAlert.handle()
                        // val uniqueId = findIdByHandle(handle)
                        managedTorrents.values.find { it.fileName == handle.name() }?.progress = handle.status().progress() * 100.toDouble()
                        // persistSessionState()
                        if (handle.needSaveResumeData()) {
                            println("Need save")
                            handle.saveResumeData()
                            persistSessionState()
                            saveManagedTorrents()
                        }
                        
                        // if (uniqueId != null) {
                        //     lastProgressMap[uniqueId] = (handle.status().progress() * 100).toDouble()
                        // }
                    }
                    

                    // AlertType.STATS -> {
                    //     val stats = alert as StatsAlert
                    //     val handle = stats.handle()
                    //     val uniqueId = findIdByHandle(handle)
                    //     if (uniqueId != null) {
                    //         lastProgressMap[uniqueId] = (handle.status().progress() * 100).toDouble()
                    //     }
                    // }


                    AlertType.TORRENT_FINISHED -> {
                        val finishedAlert = alert as TorrentFinishedAlert
                        val handle = finishedAlert.handle()
                        managedTorrents.values.find { it.fileName == handle.name() }?.progress = 100.0         
                    }

                    AlertType.SAVE_RESUME_DATA -> {
                        val saveAlert = alert as SaveResumeDataAlert
                        val handle = saveAlert.handle()
                        val params = saveAlert.params()
                        val releaseId = managedTorrents.values.find { it.fileName == handle.name() }?.uniqueId
                        if (releaseId != null) {
                            persistResumeData(releaseId, AddTorrentParams.writeResumeData(params).bencode())
                        }
                    }

                    AlertType.TORRENT_ERROR -> {
                        val err = alert as TorrentErrorAlert
                        val handle = err.handle()
                        val uniqueId = findIdByHandle(handle)
                        Log.e("TorrentManager", "Torrent $uniqueId error: ${err.error().message()}")
                    }

                    else -> {}
                }
            }
        })
    }

    /**
     * Helper: find the uniqueId associated with a TorrentHandle
     */
    private fun findIdByHandle(handle: TorrentHandle): String? {
        return torrentHandles.entries.firstOrNull { it.value == handle }?.key
    }

    /**
     * Persistence: Methods to persist the torrent's byte array data and the in-momory mapping
     *              being used for management.
     */
    fun persistSessionState() {
        sessionStateSaveFile.writeBytes(sessionManager.saveState())
    }
    
    fun loadSessionState(): ByteArray? {
        return if (sessionStateSaveFile.exists()) sessionStateSaveFile.readBytes() else null
    }

    fun persistResumeData(releaseId: String, data: ByteArray) {
        println("Persisting resume data")
        File(context.filesDir, "${releaseId}.resumedata").writeBytes(data)
    }

    fun loadResumeData(releaseId: String): ByteArray? {
        println("Loading resume data for ${releaseId}")
        return if (File(context.filesDir, "${releaseId}.resumedata").exists()) File(context.filesDir, "${releaseId}.resumedata").readBytes() else null
    }

    fun saveManagedTorrents() {
        Thread {
            val json = Json.encodeToString(managedTorrents.values.toList())
            managedTorrentsSaveFile.writeText(json)
            println("Managed torrents saved at: ${managedTorrentsSaveFile.absolutePath}")
        }.start()
    }

    fun loadManagedTorrentsSaveFile() {
        println("loading managed torrents")
        if (!managedTorrentsSaveFile.exists()) return
        // Nope, I dont want to "store it in a vArIaBlE", fuck GC
        Json.decodeFromString<List<ManagedTorrent>>(managedTorrentsSaveFile.readText()).forEach { mt ->
            managedTorrents[mt.uniqueId] = mt
        }
        println("loaded managed torrents")
        println(managedTorrents)
    }
}

@Serializable
data class ManagedTorrent (
    val uniqueId: String,
    val fileName: String,
    var sha1: String,
    var progress: Double
)