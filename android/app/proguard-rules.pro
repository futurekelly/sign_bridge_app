# MediaPipe rules
-keep class com.google.mediapipe.** { *; }
-keep interface com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# AutoValue rules
-dontwarn com.google.auto.value.extension.memoized.Memoized

# TFLite rules
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# WebRTC rules
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# SpeechToText rules
-keep class com.csdcorp.speech_to_text.** { *; }

# Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.engine.plugins.** { *; }
-keep class io.flutter.plugins.** { *; }
