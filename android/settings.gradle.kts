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
    // 🔧 بیلدِ لوکال: میرورِ aliyun «نشانگرِ پلاگین»
    // (com.google.gms.google-services.gradle.plugin) را ندارد ولی خودِ ماژول
    // (com.google.gms:google-services) را دارد — پس شناسه‌ی پلاگین مستقیم به
    // همان ماژول نگاشت می‌شود. رویِ گیت‌هاب هم بی‌اثر و سالم است.
    resolutionStrategy {
        eachPlugin {
            if (requested.id.id == "com.google.gms.google-services") {
                useModule("com.google.gms:google-services:${requested.version}")
            }
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    // Push (متریکس) رویِ FCM سوار است و google-services.json را می‌خواند
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")