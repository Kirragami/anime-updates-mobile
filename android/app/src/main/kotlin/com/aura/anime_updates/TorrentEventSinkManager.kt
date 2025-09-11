package com.aura.anime_updates

import io.flutter.plugin.common.EventChannel
import android.util.Log

class TorrentEventSinkManager private constructor() {
    companion object {
        @JvmStatic
        val instance = TorrentEventSinkManager()
    }
    
    private var eventSink: EventChannel.EventSink? = null
    
    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }
    
    fun sendEvent(event: Map<String, Any?>) {
        try {
            eventSink?.success(event)
        } catch (e: Exception) {
            // Handle case where event sink is no longer valid
            // This can happen during engine restarts
            Log.d("TorrentEventSinkManager", "Failed to send event: ${e.message}")
        }
    }
    
    fun clearEventSink() {
        eventSink = null
    }
}