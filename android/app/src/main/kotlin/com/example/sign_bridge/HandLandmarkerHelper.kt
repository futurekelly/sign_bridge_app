package com.example.sign_bridge

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.ImageProcessingOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker.HandLandmarkerOptions
import org.webrtc.VideoFrame
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.ConcurrentHashMap

class HandLandmarkerHelper private constructor(private val context: Context) {
    private var handLandmarker: HandLandmarker? = null
    var onLandmarksDetected: ((List<Map<String, Any>>) -> Unit)? = null

    private val frameCounter = AtomicLong(0)
    private val timestampMap = ConcurrentHashMap<Long, Long>()

    init {
        Thread {
            try {
                Log.i("HandLandmarkerService", "Initializing MediaPipe HandLandmarker in background thread...")
                val baseOptions = BaseOptions.builder()
                    .setModelAssetPath("hand_landmarker.task")
                    .build()

                val options = HandLandmarkerOptions.builder()
                    .setBaseOptions(baseOptions)
                    .setMinHandDetectionConfidence(0.5f)
                    .setMinTrackingConfidence(0.5f)
                    .setMinHandPresenceConfidence(0.5f)
                    .setNumHands(1)
                    .setRunningMode(RunningMode.LIVE_STREAM)
                    .setResultListener { result, inputImage ->
                        val timestampMs = result.timestampMs()
                        val startTime = timestampMap.remove(timestampMs)
                        val latencyStr = if (startTime != null) "${System.currentTimeMillis() - startTime} ms" else "unknown"
                        val landmarksList = result.landmarks()
                        val handsCount = landmarksList?.size ?: 0
                        val landmarksCount = if (handsCount > 0) landmarksList[0].size else 0

                        if (handsCount > 0) {
                            // Log.i("HandLandmarkerService", "Result callback invoked for timestamp $timestampMs. Hands detected: $handsCount, Landmarks: $landmarksCount, Latency: $latencyStr")
                            val handLandmarks = landmarksList[0]
                            // val wrist = handLandmarks[0]
                            // val indexTip = handLandmarks[8]
                            // Log.i("HandLandmarkerService", "Wrist: x=${String.format("%.4f", wrist.x())}, y=${String.format("%.4f", wrist.y())}, z=${String.format("%.4f", wrist.z())}")
                            // Log.i("HandLandmarkerService", "Index Tip: x=${String.format("%.4f", indexTip.x())}, y=${String.format("%.4f", indexTip.y())}, z=${String.format("%.4f", indexTip.z())}")

                            val landmarksData = handLandmarks.mapIndexed { index, landmark ->
                                mapOf(
                                    "id" to index,
                                    "x" to landmark.x().toDouble(),
                                    "y" to landmark.y().toDouble(),
                                    "z" to landmark.z().toDouble()
                                )
                            }
                            onLandmarksDetected?.invoke(landmarksData)
                        } else {
                            onLandmarksDetected?.invoke(emptyList())
                        }
                    }
                    .setErrorListener { error ->
                        Log.e("HandLandmarkerService", "MediaPipe Error: ${error.message}", error)
                    }
                    .build()

                handLandmarker = HandLandmarker.createFromOptions(context, options)
                Log.i("HandLandmarkerService", "MediaPipe HandLandmarker successfully initialized in background thread")
            } catch (e: Throwable) {
                Log.e("HandLandmarkerService", "Failed to initialize MediaPipe (safe fallback active): $e", e)
            }
        }.start()
    }

    fun detectFrame(frame: VideoFrame) {
        val landmarker = handLandmarker ?: return
        val frameNum = frameCounter.incrementAndGet()

        // Process every 2nd frame: ~15fps throughput at 30fps input.
        // This halves YUV decode cost and prevents the detection queue from backing up,
        // while still being faster than human reaction time (~100ms per gesture).
        if (frameNum % 2 != 0L) return

        try {
            val i420 = frame.buffer.toI420() ?: return
            val width = i420.width
            val height = i420.height
            
            val nv21Bytes = i420ToNv21(i420)
            i420.release() // Release WebRTC buffer ASAP

            val yuvImage = YuvImage(nv21Bytes, ImageFormat.NV21, width, height, null)
            val out = ByteArrayOutputStream()
            yuvImage.compressToJpeg(Rect(0, 0, width, height), 90, out)
            val jpegBytes = out.toByteArray()
            val bitmap = BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)

            if (bitmap != null) {
                val mpImage = BitmapImageBuilder(bitmap).build()
                val imageProcessingOptions = ImageProcessingOptions.builder()
                    .setRotationDegrees(frame.rotation)
                    .build()
                
                val timestampMs = frame.timestampNs / 1_000_000
                timestampMap[timestampMs] = System.currentTimeMillis()
                
                landmarker.detectAsync(mpImage, imageProcessingOptions, timestampMs)
            } else {
                Log.e("HandLandmarkerService", "Frame #$frameNum failed to decode NV21 to Bitmap")
            }
        } catch (e: Exception) {
            Log.e("HandLandmarkerService", "Exception in detectFrame for Frame #$frameNum: $e", e)
        }
    }

    private fun i420ToNv21(i420: VideoFrame.I420Buffer): ByteArray {
        val width = i420.width
        val height = i420.height
        val ySize = width * height
        val uvSize = (width / 2) * (height / 2)
        val nv21 = ByteArray(ySize + uvSize * 2)

        val yBuffer = i420.dataY
        val uBuffer = i420.dataU
        val vBuffer = i420.dataV

        val strideY = i420.strideY
        val strideU = i420.strideU
        val strideV = i420.strideV

        var nvIndex = 0
        for (row in 0 until height) {
            yBuffer.position(row * strideY)
            yBuffer.get(nv21, nvIndex, width)
            nvIndex += width
        }

        val uvWidth = width / 2
        val uvHeight = height / 2
        for (row in 0 until uvHeight) {
            val uPos = row * strideU
            val vPos = row * strideV
            for (col in 0 until uvWidth) {
                nv21[nvIndex++] = vBuffer.get(vPos + col)
                nv21[nvIndex++] = uBuffer.get(uPos + col)
            }
        }

        return nv21
    }

    companion object {
        @Volatile
        private var instance: HandLandmarkerHelper? = null

        fun getInstance(context: Context): HandLandmarkerHelper {
            return instance ?: synchronized(this) {
                instance ?: HandLandmarkerHelper(context.applicationContext).also { instance = it }
            }
        }
    }
}
