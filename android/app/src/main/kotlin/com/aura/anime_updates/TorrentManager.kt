package com.aura.anime_updates

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.frostwire.jlibtorrent.*
import com.frostwire.jlibtorrent.alerts.*
import com.frostwire.jlibtorrent.swig.torrent_flags_t
import com.frostwire.jlibtorrent.swig.add_torrent_params
import com.frostwire.jlibtorrent.ErrorCode
import com.frostwire.jlibtorrent.swig.error_code
import com.frostwire.jlibtorrent.Vectors
import android.util.Log
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import kotlinx.serialization.*
import kotlinx.serialization.json.*
import io.flutter.plugin.common.EventChannel


class TorrentManager (private val context: Context) {

    private val sessionManager: SessionManager = SessionManager()
    private val torrentHandles: MutableMap<String, TorrentHandle> = ConcurrentHashMap()
    private val resumeDataMap: MutableMap<String, ByteArray> = ConcurrentHashMap()
    private val managedTorrents = ConcurrentHashMap<String, ManagedTorrent>()
    private val sessionStateSaveFile = File(context.filesDir, "session.state")
    private val managedTorrentsSaveFile = File(context.filesDir, "managedTorrents.json")
    private val completedTorrentsFile = File(context.filesDir, "completedTorrents.json")
    private val torrentFileLocation = File(context.getExternalFilesDir(null), "TorrentFileDownloads")
    private var isSessionStarted = false
    private val newTorrents = mutableSetOf<String>()
    private val mainHandler = Handler(Looper.getMainLooper())
    var torrentEventSink: EventChannel.EventSink? = null

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
                    val ec = error_code()
                    val vec = Vectors.bytes2byte_vector(loadResumeData(torrent.uniqueId))
                    val params = add_torrent_params.read_resume_data(vec, ec)
                    sessionManager?.swig()?.add_torrent(params, ec)
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
    fun addTorrent(releaseId: String, magnetUrl: String, savePath: String, fileName: String) {
        newTorrents.add(releaseId)
        sessionManager?.download(magnetUrl, File(savePath), torrent_flags_t())
        val mt = ManagedTorrent(releaseId, fileName, "", 0.0)
        managedTorrents[releaseId] = mt
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
                        handle.pause()
                        val releaseId = managedTorrents.values.find { it.fileName == handle.name() }?.uniqueId
                        println("This is the releaseId we are checking > < ${releaseId}")
                        println("THis is the list > < ${newTorrents}")
                        if (newTorrents.contains(releaseId)) {
                            handle.resume()
                            newTorrents.remove(releaseId)
                        }
                        managedTorrents.values.find { it.fileName == handle.name() }?.sha1 = handle.infoHash().toHex()
                        println("This is status in handle, kirra-sama > <")
                        println(managedTorrents)
                    }

                    AlertType.BLOCK_FINISHED -> {
                        val blockAlert = alert as BlockFinishedAlert
                        val handle = blockAlert.handle()
                        // val uniqueId = findIdByHandle(handle)
                        val mt = managedTorrents.values.find { it.fileName == handle.name() }
                        mt?.progress = handle.status().progress() * 100.toDouble()
                        // persistSessionState()
                        if (handle.needSaveResumeData()) {
                            println("Need save")
                            handle.saveResumeData()
                            persistSessionState()
                            saveManagedTorrents()
                        }

                        mt?.uniqueId?.let { id ->
                            mainHandler.post {
                                torrentEventSink?.success(
                                    mapOf("releaseId" to id, "progress" to mt.progress, "status" to "downloading", "speed" to handle.status().downloadRate())
                                )
                            }
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
                        val mt = managedTorrents.values.find { it.fileName == handle.name() }
                        mt?.progress = 100.0
                        sessionManager.remove(handle)
                        mt?.uniqueId?.let { id ->
                            torrentEventSink?.success(
                                mapOf("releaseId" to id, "progress" to 100.0, "status" to "completed")
                            )
                        }
                        managedTorrents?.remove(mt?.uniqueId)
                        saveManagedTorrents()
                        saveCompletedTorrent(mt?.uniqueId, mt?.fileName)
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

    fun getManagedTorrents(): Collection<ManagedTorrent> {
        return managedTorrents.values
    }

    fun saveCompletedTorrent(releaseId: String?, fileName: String?) {
        try {
            
            val currentList: MutableList<CompletedTorrent> = if (completedTorrentsFile.exists()) {
                completedTorrentsFile.inputStream().use { Json.decodeFromStream(it) }
            } else {
                mutableListOf()
            }
            currentList.add(CompletedTorrent(releaseId, fileName))
            completedTorrentsFile.writeText(Json.encodeToString(currentList))
        } catch (e: Exception) {
            println("Error saving completed torrent: $e")
        }
    }

    fun loadCompleted(): List<CompletedTorrent> {
        if (!completedTorrentsFile.exists()) return emptyList()
        val json = completedTorrentsFile.readText()
        return if (json.isEmpty()) emptyList() else Json.decodeFromString(json)
    }

}

@Serializable
data class ManagedTorrent (
    val uniqueId: String,
    val fileName: String,
    var sha1: String,
    var progress: Double
)

@Serializable
data class CompletedTorrent (
    val releaseId: String?,
    val fileName: String?
)