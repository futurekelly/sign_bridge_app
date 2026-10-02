package com.example.sign_bridge

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.ImageProcessingOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker.HandLandmarkerOptions
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import org.webrtc.VideoFrame
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

class HandLandmarkerHelper private constructor(private val context: Context) {
    private var handLandmarker: HandLandmarker? = null
    var onLandmarksDetected: ((FloatArray) -> Unit)? = null

    private val frameCounter = AtomicLong(0)
    private val aiExecutor = Executors.newSingleThreadExecutor()
    
    @Volatile
    private var isProcessing = false 

    // The bitmap's aspect ratio MUST follow the source buffer. Squeezing every capture into a
    // fixed 320x240 (4:3) target reorients the hand when the source is a different shape, and
    // the model then reads an upright sign as a different word entirely -- a rotated hand
    // produced a constant "no@100%" on device. The long side is capped for speed only; the
    // ratio is preserved exactly.
    private val MAX_DIM = 480

    init {
        aiExecutor.execute {
            try {
                java.lang.Thread.sleep(1000)
                Log.i("HandLandmarkerService", "Initializing Smooth AI Pipeline (Finalist Plus)...")
                
                val baseOptions = BaseOptions.builder()
                    .setModelAssetPath("hand_landmarker.task")
                    .setDelegate(Delegate.CPU)
                    .build()

                val options = HandLandmarkerOptions.builder()
                    .setBaseOptions(baseOptions)
                    .setMinHandDetectionConfidence(0.5f)
                    .setMinTrackingConfidence(0.5f)
                    .setMinHandPresenceConfidence(0.5f)
                    // ONE hand, not two. The deployed model takes a single 42-float hand, so
                    // tracking a second hand buys nothing and costs a great deal: Dart scores
                    // every hand and keeps the most *confident* one, which means a resting or
                    // background hand that happens to look like a word can outrank the hand
                    // actually signing. A capture where the resting hand won at no@100% is in
                    // the 12:56 log. With one hand there is no contest to lose.
                    .setNumHands(1)
                    .setRunningMode(RunningMode.LIVE_STREAM)
                    .setResultListener { result: HandLandmarkerResult, _: MPImage ->
                        val landmarksList = result.landmarks()
                        val handednessList = result.handedness()

                        // Layout (88 floats):
                        //   [ 0..83] hand0 (0..41) + hand1 (42..83), 21 landmarks * (x, y)
                        //   [84]     hand0 chirality: +1 = MediaPipe says "Right", -1 = "Left", 0 = unknown
                        //   [85]     hand1 chirality, same encoding
                        //   [86]     hand0 handedness score
                        //   [87]     hand1 handedness score
                        //
                        // The chirality is emitted RAW. Deciding what it means for the model
                        // depends on whether this buffer was mirrored, which is an inference
                        // -contract question owned by Dart (see InferenceManager).
                        val payload = FloatArray(88)

                        if (landmarksList != null && landmarksList.size > 0) {
                            val handsCount = if (landmarksList.size > 2) 2 else landmarksList.size
                            for (h in 0 until handsCount) {
                                val hand = landmarksList[h]
                                if (hand != null) {
                                    val base = h * 42
                                    for (index in 0 until minOf(hand.size, 21)) {
                                        val lm = hand[index]
                                        payload[base + index * 2]     = lm.x()
                                        payload[base + index * 2 + 1] = lm.y()
                                    }
                                }

                                // One Category per hand in practice; take the top-scoring one.
                                val top = handednessList?.getOrNull(h)?.maxByOrNull { it.score() }
                                if (top != null) {
                                    payload[84 + h] = when (top.categoryName()) {
                                        "Right" -> 1f
                                        "Left"  -> -1f
                                        else    -> 0f
                                    }
                                    payload[86 + h] = top.score()
                                }
                            }
                        }
                        onLandmarksDetected?.invoke(payload)
                    }
                    .setErrorListener { error ->
                        Log.e("HandLandmarkerService", "MediaPipe Error: " + error.message)
                    }
                    .build()

                handLandmarker = HandLandmarker.createFromOptions(context, options)
                Log.i("HandLandmarkerService", "Smooth AI Pipeline READY.")
            } catch (e: Exception) {
                Log.e("HandLandmarkerService", "MediaPipe Init Failed: " + e.message)
            }
        }
    }

    fun detectFrame(frame: VideoFrame) {
        val landmarker = handLandmarker ?: return
        val frameNum = frameCounter.incrementAndGet()

        if (frameNum % 4 != 0L) return
        if (isProcessing) return

        isProcessing = true
        
        val buffer = frame.buffer
        val i420 = buffer.toI420()
        if (i420 == null) {
            isProcessing = false
            return
        }

        val srcW = i420.width
        val srcH = i420.height
        val bitmap = i420ToArgbBitmap(i420)
        i420.release()

        if (bitmap == null) {
            isProcessing = false
            return
        }

        val rotation = frame.rotation
        val timestampMs = frame.timestampNs / 1_000_000

        // Turn the buffer upright HERE, rather than asking MediaPipe to do it.
        //
        // Measured on the Huawei: src=640x360 (landscape) with rotation=270. Handing that
        // sideways bitmap to MediaPipe together with setRotationDegrees() still produced
        // sideways landmarks -- in the 12:56 capture the four knuckles came back stacked
        // along y (x pinned at -0.43 while y ran -0.48 to +0.18) with the fingers extending
        // along -x, whereas every keypoint.csv row has the knuckles spread along x and the
        // fingers running up -y. A quarter turn, exactly what an unrotated buffer gives.
        //
        // That matters more than it looks, because none of the five words is orientation
        // free: the model faithfully reports a sideways hand as a different word, and at
        // saturated confidence, so `thank_you` came back `no` and `yes` at 1.000. It also
        // corrupted handedness -- MediaPipe judges chirality from the image, and a hand on
        // its side was reported "Left", so Dart mirrored a hand that should not have been
        // mirrored. One fault, both symptoms.
        //
        // Rotating the pixels first means MediaPipe is always handed the frame the user can
        // see, on any device and either camera, with nothing left to infer about what it did
        // with the rotation option.
        val upright = if (rotation == 0) bitmap else rotateUpright(bitmap, rotation)

        // TEMP DIAGNOSTIC (remove before release): the capture geometry, so an orientation
        // fault can be traced to the buffer shape rather than guessed at.
        if (frameNum % 60 == 4L) {
            Log.i("HandLandmarkerService",
                "geometry src=${srcW}x$srcH rotation=$rotation " +
                    "bitmap=${bitmap.width}x${bitmap.height} " +
                    "upright=${upright.width}x${upright.height}")
        }

        aiExecutor.execute {
            try {
                val mpImage = BitmapImageBuilder(upright).build()
                val imageProcessingOptions = ImageProcessingOptions.builder()
                    .setRotationDegrees(0)
                    .build()
                landmarker.detectAsync(mpImage, imageProcessingOptions, timestampMs)
            } catch (e: Exception) {
                Log.e("HandLandmarkerService", "AI Execute Error: " + e.message)
            } finally {
                isProcessing = false
            }
        }
    }

    /**
     * Rotates [src] clockwise by [degrees], the angle WebRTC reports as the amount the
     * captured frame must be turned to be displayed upright.
     *
     * `Matrix.postRotate` turns clockwise in the screen's y-down space, which is the same
     * sense as `VideoFrame.getRotation()`, so the two are used directly without a sign flip.
     * The result is a new bitmap rather than an in-place remap: `detectAsync` is asynchronous
     * and may still be reading the source after this returns.
     */
    private fun rotateUpright(src: Bitmap, degrees: Int): Bitmap {
        val m = Matrix()
        m.postRotate(degrees.toFloat())
        return Bitmap.createBitmap(src, 0, 0, src.width, src.height, m, true)
    }

    /**
     * Converts an I420 buffer to ARGB, preserving the source aspect ratio.
     *
     * The bitmap is allocated fresh per frame rather than shared: `detectAsync` is
     * asynchronous, so MediaPipe may still be reading a buffer after this call returns, and a
     * reused bitmap would be overwritten underneath it by the next frame.
     */
    private fun i420ToArgbBitmap(i420: VideoFrame.I420Buffer): Bitmap? {
        val srcWidth = i420.width
        val srcHeight = i420.height
        if (srcWidth <= 0 || srcHeight <= 0) return null

        val scale = MAX_DIM.toFloat() / maxOf(srcWidth, srcHeight)
        val w = if (scale < 1f) (srcWidth * scale).toInt().coerceAtLeast(1) else srcWidth
        val h = if (scale < 1f) (srcHeight * scale).toInt().coerceAtLeast(1) else srcHeight

        val yBuf = i420.dataY
        val uBuf = i420.dataU
        val vBuf = i420.dataV
        val yStride = i420.strideY
        val uStride = i420.strideU
        val vStride = i420.strideV

        val rgb = ByteBuffer.allocateDirect(w * h * 4)
        for (row in 0 until h) {
            val srcRow = row * srcHeight / h
            val yRowOff = srcRow * yStride
            for (col in 0 until w) {
                val srcCol = col * srcWidth / w
                val uvCol = srcCol / 2
                val uvRow = srcRow / 2

                val y = (yBuf.get(yRowOff + srcCol).toInt() and 0xFF)
                val u = (uBuf.get(uvRow * uStride + uvCol).toInt() and 0xFF) - 128
                val v = (vBuf.get(uvRow * vStride + uvCol).toInt() and 0xFF) - 128

                val r = (y + 1.402f * v).toInt().coerceIn(0, 255)
                val g = (y - 0.344136f * u - 0.714136f * v).toInt().coerceIn(0, 255)
                val b = (y + 1.772f * u).toInt().coerceIn(0, 255)

                rgb.put(b.toByte())
                rgb.put(g.toByte())
                rgb.put(r.toByte())
                rgb.put(0xFF.toByte())
            }
        }
        rgb.rewind()
        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        out.copyPixelsFromBuffer(rgb)
        return out
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
