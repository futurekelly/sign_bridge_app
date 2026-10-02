plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.sign_bridge"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.sign_bridge"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // No abiFilters here on purpose. Hardcoding them makes Gradle refuse to configure
        // the `--split-per-abi` build outright:
        //   "Conflicting configuration : 'armeabi-v7a,arm64-v8a,x86_64' in ndk abiFilters
        //    cannot be present when splits abi filters are set"
        // Flutter already picks the ABI set itself: a plain `flutter build apk` produces a
        // fat APK with arm64-v8a + armeabi-v7a + x86_64, and `--split-per-abi` produces one
        // APK per ABI. Leaving this to Flutter gives both, without the conflict.
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            
            // 🚨 DEMO SAFETY FIX: Disable minification to prevent MediaPipe/TFLite crashes
            // This ensures all classes are preserved exactly as they are in debug mode.
            isMinifyEnabled = false
            isShrinkResources = false

            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    compileOnly("io.github.webrtc-sdk:android:144.7559.01")
    implementation("com.google.mediapipe:tasks-vision:0.10.26")

    // REMOVED: org.tensorflow:tensorflow-lite-select-tf-ops:2.16.1 (Flex delegate)
    //
    // It shipped libtensorflowlite_flex_jni.so at 68,177,576 bytes for arm64-v8a -- larger
    // than every other file in the APK put together (libflutter 11MB, mediapipe 14MB,
    // webrtc 12MB). It was added for a GRU model with Select TF ops, and that model is not
    // in the build: InferenceManager.initialize() asks for
    // assets/models/gesture_model_gru.tflite, which does not exist, so the load always
    // throws and always falls back to the dense model.
    //
    // Measured, not assumed -- see diagnostics/verify_no_flex_ops.py. The deployed
    // gesture_model_dense.tflite contains exactly three ops, FULLY_CONNECTED, SOFTMAX and
    // DELEGATE, and no Flex op. Only gesture_model_gru_experimental.tflite needs Flex
    // (FlexTensorListReserve / FlexTensorListStack / WHILE), and nothing loads it.
    //
    // RESTORE THIS LINE if a model with Flex ops is ever actually deployed. Its absence
    // shows up at runtime as an interpreter that fails to build, not as a compile error.
}
