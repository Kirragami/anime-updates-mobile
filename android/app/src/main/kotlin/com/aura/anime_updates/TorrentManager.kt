package com.aura.anime_updates

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.frostwire.jlibtorrent.*
import com.frostwire.jlibtorrent.alerts.*
import com.frostwire.jlibtorrent.swig.torrent_flags_t
import com.frostwire.jlibtorrent.swig.remove_flags_t
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
import java.net.URL
import java.net.HttpURLConnection
import java.io.BufferedInputStream
import java.io.FileOutputStream


class TorrentManager private constructor(private val context: Context) {
    
    companion object {
        @Volatile
        private var INSTANCE: TorrentManager? = null
        
        fun getInstance(context: Context): TorrentManager {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: TorrentManager(context.applicationContext).also { INSTANCE = it }
            }
        }
    }

    private val sessionManager: SessionManager = SessionManager()
    private val torrentHandles: MutableMap<String, TorrentHandle> = ConcurrentHashMap()
    private val resumeDataMap: MutableMap<String, ByteArray> = ConcurrentHashMap()
    private val managedTorrents = ConcurrentHashMap<String, ManagedTorrent>()
    private val sessionStateSaveFile = File(context.filesDir, "session.state")
    private val managedTorrentsSaveFile = File(context.filesDir, "managedTorrents.json")
    private val completedTorrentsFile = File(context.filesDir, "completedTorrents.json")
    private val torrentFileLocation = File(context.getExternalFilesDir(null), "TorrentFileDownloads")
    private val animeImagesDir = File(context.getExternalFilesDir(null), "AnimeImages")
    private var isSessionStarted = false
    private val newTorrents = mutableSetOf<String>()
    private val mainHandler = Handler(Looper.getMainLooper())
    var torrentEventSink: EventChannel.EventSink? = null

    init {
        setupListener()
        loadManagedTorrentsSaveFile()
        if (!animeImagesDir.exists()) {
            animeImagesDir.mkdirs()
        }
    }

    fun startSession() {
        if (isSessionStarted) {
            return
        }
        
        try {
            val savedState = loadSessionState()
            if (savedState == null) {
                sessionManager?.start()
            } else {
                sessionManager?.start(SessionParams(loadSessionState()))
                for (torrent in managedTorrents.values) {
                    val ec = error_code()
                    val vec = Vectors.bytes2byte_vector(loadResumeData(torrent.releaseId))
                    val params = add_torrent_params.read_resume_data(vec, ec)
                    sessionManager?.swig()?.add_torrent(params, ec)
                }
            }
            sessionManager?.resume()
        } catch(e: Exception) {
            println(e)
        }
        isSessionStarted = true
    }

    fun addTorrent(releaseId: String, magnetUrl: String, savePath: String, fileName: String, showName: String, episode: String, animeShowId: String, imageUrl: String) {
        startForegroundService()
        newTorrents.add(releaseId)
        sessionManager?.download(magnetUrl, File(savePath), torrent_flags_t())
        
        val mt = ManagedTorrent(releaseId, fileName, showName, episode, TorrentUtils.getSha1FromMagnet(magnetUrl)?.toHex() ?: "", 0.0, 0, "downloading", animeShowId)
        managedTorrents[releaseId] = mt
        emitManagedTorrentEvent("added", mt)
  
        if (animeShowId.isNotEmpty() && imageUrl.isNotEmpty()) {
            downloadAnimeImage(animeShowId, imageUrl)
        }
    }
    
    
    private fun downloadAnimeImage(animeShowId: String, imageUrl: String) {
        Thread {
            try {
                val imageFile = File(animeImagesDir, "$animeShowId.jpg")
                
            
                if (imageFile.exists()) {
                    Log.d("TorrentManager", "Image already exists for animeShowId: $animeShowId")
                    return@Thread
                }
                
        
                val url = URL(imageUrl)
                val connection = url.openConnection() as HttpURLConnection
                connection.connectTimeout = 10000
                connection.readTimeout = 10000
                connection.connect()
                
                if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                    val inputStream = BufferedInputStream(connection.inputStream)
                    val outputStream = FileOutputStream(imageFile)
                    
                    val buffer = ByteArray(8192)
                    var bytesRead: Int
                    while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                        outputStream.write(buffer, 0, bytesRead)
                    }
                    
                    outputStream.close()
                    inputStream.close()
                    connection.disconnect()
                    
                    Log.d("TorrentManager", "Successfully downloaded image for animeShowId: $animeShowId")
                } else {
                    Log.e("TorrentManager", "Failed to download image. Response code: ${connection.responseCode}")
                }
            } catch (e: Exception) {
                Log.e("TorrentManager", "Error downloading anime image: ${e.message}", e)
            }
        }.start()
    }
    
    fun getAnimeImagePath(animeShowId: String): String? {
        val imageFile = File(animeImagesDir, "$animeShowId.jpg")
        return if (imageFile.exists()) imageFile.absolutePath else null
    }

    fun pauseTorrent(releaseId: String) {
        sessionManager?.find(Sha1Hash(managedTorrents[releaseId]?.sha1))?.pause()
    }

    fun resumeTorrent(releaseId: String) {
        sessionManager?.find(Sha1Hash(managedTorrents[releaseId]?.sha1))?.resume()
    }

    fun deleteTorrent(releaseId: String) {
        try {
            val mt = managedTorrents[releaseId]
            if (mt != null) {
                managedTorrents.remove(releaseId)
                val handle = sessionManager.find(Sha1Hash(mt?.sha1))
                val deleteFilesFlag = remove_flags_t.from_int(1)
                handle?.let { sessionManager.remove(it, deleteFilesFlag) }
                saveManagedTorrents()
                return
            }

            val completedList: MutableList<CompletedTorrent> =
                if (completedTorrentsFile.exists()) {
                    completedTorrentsFile.inputStream().use { Json.decodeFromStream(it) }
                } else {
                    mutableListOf()
                }

            val iterator = completedList.iterator()
            var found = false
            while (iterator.hasNext()) {
                val ct = iterator.next()
                if (ct.releaseId.equals(releaseId)) {
                    iterator.remove()
                    found = true
                    val f = File(torrentFileLocation, ct.fileName ?: "")
                    if (f.exists()) {
                        f.delete()
                    }
                }
            }

            if (found) {
                val jsonString = Json.encodeToString(completedList)
                completedTorrentsFile.writeText(jsonString)
            }

        } catch (e: Exception) {
            println("Error deleting torrent: $e")
        }
    }

    fun pauseAll() {
        for (torrent in managedTorrents.values) {
            sessionManager?.find(Sha1Hash(torrent.sha1))?.pause()
        }
    }

    fun resumeAll() {
        for (torrent in managedTorrents.values) {
            sessionManager?.find(Sha1Hash(torrent.sha1))?.resume()
        }
    }

    fun setDownloadSpeedLimit(limit: Int) {
        sessionManager?.downloadRateLimit(limit)
    }

    fun stopSession() {
        sessionManager.stop()
        torrentHandles.clear()
    }

    fun getProgress(releaseId: String): Double {
        return managedTorrents[releaseId]?.progress ?: 0.0
    }

    private fun startForegroundService() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(context, TorrentForegroundService::class.java)
            context.startForegroundService(intent)
        } else {
            val intent = Intent(context, TorrentForegroundService::class.java)
            context.startService(intent)
        }
    }


    private fun setupListener() {
        sessionManager.addListener(object : AlertListener {
            override fun types(): IntArray? = null

            override fun alert(alert: Alert<*>) {
                when (alert.type()) {

                    AlertType.ADD_TORRENT -> {
                        Log.d("TorrentManager", "Add Event triggered")
                        val addAlert = alert as AddTorrentAlert
                        val handle = addAlert.handle()
                        handle.unsetFlags(TorrentFlags.AUTO_MANAGED)
                        handle.pause()

                        val mt = managedTorrents.values.find { it.sha1 == handle.infoHash().toHex() }
                        if (newTorrents.contains(mt?.releaseId)) {
                            handle.resume()
                            newTorrents.remove(mt?.releaseId)
                        }
                    }

                    AlertType.BLOCK_FINISHED -> {
                        val blockAlert = alert as BlockFinishedAlert
                        val handle = blockAlert.handle()
                        val mt = managedTorrents.values.find { it.sha1 == handle.infoHash().toHex() }
                        mt?.status = "downloading"
                        mt?.progress = handle.status().progress() * 100.toDouble()
                        mt?.speed = handle.status().downloadRate()
                        if (handle.needSaveResumeData()) {
                            handle.saveResumeData()
                            persistSessionState()
                            saveManagedTorrents()
                        }

                        emitManagedTorrentEvent("progressed", mt)
                    }

                    AlertType.TORRENT_PAUSED -> {
                        val pauseAlert = alert as TorrentPausedAlert
                        val handle = pauseAlert.handle()
                        val mt = managedTorrents.values.find { it.sha1 == handle.infoHash().toHex() }
                        mt?.speed = 0
                        mt?.status = "paused"
                        emitManagedTorrentEvent("paused", mt)
                    }

                    AlertType.TORRENT_RESUMED -> {
                        val resumeAlert = alert as TorrentResumedAlert
                        val handle = resumeAlert.handle()
                        val mt = managedTorrents.values.find { it.sha1 == handle.infoHash().toHex() }
                        mt?.status = "downloading"
                        emitManagedTorrentEvent("resumed", mt)
                    }

                    AlertType.TORRENT_FINISHED -> {
                        val finishedAlert = alert as TorrentFinishedAlert
                        val handle = finishedAlert.handle()
                        val mt = managedTorrents.values.find { it.sha1 == handle.infoHash().toHex() }
                        mt?.progress = 100.0
                        mt?.status = "completed"
                        sessionManager.remove(handle)
                        emitManagedTorrentEvent("completed", mt)
                        managedTorrents?.remove(mt?.releaseId)
                        saveManagedTorrents()
                        saveCompletedTorrent(mt?.releaseId, mt?.fileName, mt?.showName, mt?.episode, mt?.animeShowId)
                    }

                    AlertType.TORRENT_DELETED -> {
                        val deletedAlert = alert as TorrentDeletedAlert
                        val sha1 = deletedAlert.getInfoHashes().getBest().toHex()
                        val releaseId = managedTorrents.values.find { it.sha1 == sha1 }?.releaseId
                        val mt = managedTorrents[releaseId]
                        mt?.status = "deleted"
                        mt?.speed = 0
                        emitManagedTorrentEvent("deleted", mt)
                        managedTorrents.remove(releaseId)
                        saveManagedTorrents()
                    }

                    AlertType.SAVE_RESUME_DATA -> {
                        val saveAlert = alert as SaveResumeDataAlert
                        val handle = saveAlert.handle()
                        val params = saveAlert.params()
                        val releaseId = managedTorrents.values.find { it.sha1 == handle.infoHash().toHex() }?.releaseId
                        if (releaseId != null) {
                            persistResumeData(releaseId, AddTorrentParams.writeResumeData(params).bencode())
                        }
                    }

                    AlertType.TORRENT_ERROR -> {
                        val err = alert as TorrentErrorAlert
                        Log.e("TorrentManager", "Torrent error: ${err.error().message()}")
                    }

                    else -> {}
                }
            }
        })
    }

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
            managedTorrents[mt.releaseId] = mt
        }
        
        println("loaded managed torrents")
        println(managedTorrents)
    }

    fun getManagedTorrents(): Collection<ManagedTorrent> {
        return managedTorrents.values
    }

    fun saveCompletedTorrent(releaseId: String?, fileName: String?, showName: String?, episode:String?, animeShowId: String?) {
        try {
            
            val currentList: MutableList<CompletedTorrent> = if (completedTorrentsFile.exists()) {
                completedTorrentsFile.inputStream().use { Json.decodeFromStream(it) }
            } else {
                mutableListOf()
            }
            currentList.add(CompletedTorrent(releaseId, fileName, showName, episode, animeShowId))
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

    fun emitManagedTorrentEvent(type: String, mt: ManagedTorrent?) {
        mt?.let {
            torrent -> 
                mainHandler.post {
                    TorrentEventSinkManager.instance.sendEvent(
                        mapOf(
                            "type" to type,
                            "managedTorrent" to torrent.toMap()
                        )
                    )
                }
        }
    }

}

@Serializable
data class ManagedTorrent (
    val releaseId: String,
    val fileName: String,
    val showName: String,
    val episode: String,
    var sha1: String,
    var progress: Double,
    var speed: Int,
    var status: String,
    val animeShowId: String = ""
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "releaseId" to releaseId,
        "fileName" to fileName,
        "showName" to showName,
        "episode" to episode,
        "sha1" to sha1,
        "progress" to progress,
        "speed" to speed,
        "status" to status,
        "animeShowId" to animeShowId
    )
}

@Serializable
data class CompletedTorrent (
    val releaseId: String?,
    val fileName: String?,
    val showName: String?,
    val episode: String?,
    val animeShowId: String? = null
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "releaseId" to releaseId,
        "fileName" to fileName,
        "showName" to showName,
        "episode" to episode,
        "animeShowId" to animeShowId
    )
}