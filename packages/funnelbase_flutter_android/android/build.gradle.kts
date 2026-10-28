// The Android half of funnelbase_flutter: a thin layer over the native Android SDK,
// com.funnel-base:funnelbase-android, which it takes from Maven Central.
//
// Built as a subproject of the Flutter app's own Gradle build, so it takes the app's AGP — which
// has to be AGP 9, the one the native SDK is built with, with `android.newDsl=false` for Flutter's
// Gradle plugin (docs/sdk-flutter.md, "Building"). No `org.jetbrains.kotlin.android` and no
// `kotlinOptions`: AGP 9 brings Kotlin itself and rejects the standalone plugin.
plugins {
    id("com.android.library")
}

group = "com.funnelbase.sdk.flutter"
version = "0.1.0"

// The native SDK this version is written against. Raise it with the CHANGELOG.
val funnelbaseAndroidVersion = "0.4.0"

// A plugin's repositories apply to its own subproject only, so they are listed here as well as in
// the app's build. mavenLocal() after Maven Central: a version not released yet resolves from
// `./gradlew publishToMavenLocal` in funnelbase-android, and a released one never reaches it.
repositories {
    google()
    mavenCentral()
    mavenLocal()
}

android {
    namespace = "com.funnelbase.sdk.flutter"
    compileSdk = 36

    defaultConfig {
        // The SDK's own floor: java.time without desugaring.
        minSdk = 26
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation("com.funnel-base:funnelbase-android:$funnelbaseAndroidVersion")
}
