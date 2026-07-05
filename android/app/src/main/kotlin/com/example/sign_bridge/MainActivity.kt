package com.example.sign_bridge
 
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import org.webrtc.VideoTrack

class MainActivity : FlutterActivity() {
    private val handler = Handler(Looper.getMainLooper())
    private var isTracking = false
    private var activeTrack: VideoTrack? = null
    private var activeSink: org.webrtc.VideoSink? = null
    private lateinit var landmarkerHelper: HandLandmarkerHelper
    
    private val LANDMARK_CHANNEL = "com.example.sign_bridge/landmarks"
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.i("MainActivity", "Configuring Flutter engine and initializing MediaPipe Landmarker")
        landmarkerHelper = HandLandmarkerHelper.getInstance(this)
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, LANDMARK_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    Log.i("MainActivity", "EventChannel onListen: client subscribed")
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    Log.i("MainActivity", "EventChannel onCancel: client unsubscribed")
                    eventSink = null
                }
            }
        )

        landmarkerHelper.onLandmarksDetected = { landmarksData ->
            runOnUiThread {
                eventSink?.success(landmarksData)
            }
        }
        
        startTrackDiscovery()
    }

    private fun startTrackDiscovery() {
        isTracking = true
        val discoveryRunnable = object : Runnable {
            override fun run() {
                if (!isTracking) return
                checkAndAttachVideoSink()
                handler.postDelayed(this, 1000) // check every 1 second
            }
        }
        handler.post(discoveryRunnable)
    }

    private fun checkAndAttachVideoSink() {
        try {
            val plugin = FlutterWebRTCPlugin.sharedSingleton
            if (plugin == null) {
                Log.i("MainActivity", "checkAndAttachVideoSink: sharedSingleton is null (waiting for plugin registration)")
                return
            }
            
            val handlerField = plugin.javaClass.getDeclaredField("methodCallHandler").apply {
                isAccessible = true
            }
            val methodCallHandler = handlerField.get(plugin)
            if (methodCallHandler == null) {
                Log.i("MainActivity", "checkAndAttachVideoSink: methodCallHandler is null (waiting for registration)")
                return
            }

            val localTracksField = methodCallHandler.javaClass.getDeclaredField("localTracks").apply {
                isAccessible = true
            }
            val localTracks = localTracksField.get(methodCallHandler) as? Map<String, Any>
            if (localTracks == null) {
                Log.i("MainActivity", "checkAndAttachVideoSink: localTracks map is null")
                return
            }

            if (localTracks.isNotEmpty()) {
                for ((key, localTrack) in localTracks) {
                    // Recursive lookup for a field holding the VideoTrack or MediaStreamTrack wrapper
                    var rawTrack: Any? = null
                    val fieldNamesToTry = listOf("track", "videoTrack", "webRtcTrack", "nativeTrack", "mTrack")
                    for (fieldName in fieldNamesToTry) {
                        var lookupClass: Class<*>? = localTrack.javaClass
                        while (lookupClass != null) {
                            try {
                                val field = lookupClass.getDeclaredField(fieldName).apply { isAccessible = true }
                                rawTrack = field.get(localTrack)
                                if (rawTrack != null) break
                            } catch (e: NoSuchFieldException) {
                                // Try next superclass
                            }
                            lookupClass = lookupClass.superclass
                        }
                        if (rawTrack != null) break
                    }
                    
                    if (rawTrack is VideoTrack) {
                        if (activeTrack?.id() != rawTrack.id()) {
                            detachActiveSink()
                            
                            Log.i("MainActivity", "Found active local VideoTrack: ${rawTrack.id()}. Attaching HandLandmarkVideoSink.")
                            val sink = HandLandmarkVideoSink(landmarkerHelper)
                            rawTrack.addSink(sink)
                            Log.i("HandLandmarkerService", "VideoSink attached successfully to track: ${rawTrack.id()}")
                            activeTrack = rawTrack
                            activeSink = sink
                        }
                        break
                    }
                }
            } else {
                if (activeTrack != null) {
                    Log.i("MainActivity", "Local video tracks map is empty. Detaching sink.")
                    detachActiveSink()
                }
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error in checkAndAttachVideoSink: $e", e)
        }
    }

    private fun detachActiveSink() {
        val track = activeTrack
        val sink = activeSink
        if (track != null && sink != null) {
            try {
                track.removeSink(sink)
                Log.i("MainActivity", "Successfully detached HandLandmarkVideoSink from track: ${track.id()}")
            } catch (e: Exception) {
                Log.e("MainActivity", "Error detaching sink: $e")
            }
        }
        activeTrack = null
        activeSink = null
    }

    override fun onDestroy() {
        isTracking = false
        detachActiveSink()
        super.onDestroy()
    }
}

