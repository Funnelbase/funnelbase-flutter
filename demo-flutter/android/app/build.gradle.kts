// The Flutter trading demo's Android app. No `org.jetbrains.kotlin.android`: AGP 9 brings Kotlin
// itself and rejects the standalone plugin (see settings.gradle.kts).
plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase's plugin reads google-services.json into the build. That file names a real Firebase
// project, is gitignored, and most clones do not have one — so, as in demo-android, the plugin is
// applied only when it is there, and the app builds and runs either way, with push through a custom
// gateway instead. Checked through `providers` so the configuration cache notices it appear.
val googleServicesJson = providers.fileContents(layout.projectDirectory.file("google-services.json")).asText
if (googleServicesJson.isPresent) {
    apply(plugin = "com.google.gms.google-services")
    logger.lifecycle("demo-flutter: google-services.json found — Firebase push is wired in.")
} else {
    logger.lifecycle(
        "demo-flutter: no google-services.json — the app builds without Firebase. " +
            "Register a token by hand on the Notifications screen, or see docs/sdk-flutter.md in the repository.",
    )
}

android {
    // Not demo-android's id, so the two demos install side by side on one emulator.
    namespace = "com.funnelbase.demo.trading.flutter"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.analytics.demo.trading.flutter"
        // The SDK's own floor, as in demo-android: a demo on older devices than the SDK supports
        // would be demonstrating something the SDK cannot do.
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signed with the debug keys, so `flutter run --release` works; a demo is never shipped.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Push through Firebase: one messaging service that renders and reports natively, no Dart
    // involved. It resolves without a Firebase project; only the plugin above needs one. It
    // exposes the native SDK as `api`, which MainActivity's simulate channel calls directly. The
    // same version funnelbase_flutter_android depends on.
    implementation("com.funnel-base:funnelbase-android-fcm:0.4.0")
}

// integration_test (a dev dependency, in debug builds) asks for espresso 3.2, whose core and
// idling-resource artifacts share one namespace, which AGP 9's manifest merger refuses. A newer
// espresso gives each its own; nothing here uses espresso beyond that plugin.
configurations.configureEach {
    resolutionStrategy.force(
        "androidx.test.espresso:espresso-core:3.6.1",
        "androidx.test.espresso:espresso-idling-resource:3.6.1",
    )
}

flutter {
    source = "../.."
}
