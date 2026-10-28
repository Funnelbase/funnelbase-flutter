pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// The native SDK comes from Maven Central as a published artifact, built with AGP 9.1 — which has
// Kotlin built in, hence no `org.jetbrains.kotlin.android` here or in app/build.gradle.kts. The
// Google services plugin is here for the optional Firebase push. Raise these with the native SDK.
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("com.android.library") version "9.1.0" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
