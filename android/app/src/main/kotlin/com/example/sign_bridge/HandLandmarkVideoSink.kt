package com.example.sign_bridge

import org.webrtc.VideoFrame
import org.webrtc.VideoSink

class HandLandmarkVideoSink(private val helper: HandLandmarkerHelper) : VideoSink {
    override fun onFrame(frame: VideoFrame) {
        helper.detectFrame(frame)
    }
}
