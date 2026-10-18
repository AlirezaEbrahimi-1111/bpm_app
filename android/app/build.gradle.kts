import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // 🔧 رفعِ باگ: این پلاگین لازم است تا بلوکِ «kotlin { compilerOptions {...} } »
    // در پایینِ همین فایل قابلِ‌شناسایی باشد — بدونش آن بلوک با خطایِ
    // «Unresolved reference» شکست می‌خورد
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// 🔧 موقت: به‌خاطرِ قطعیِ ناپایدارِ شبکه در رسیدن به repo های گوگل/میون،
// جارهایِ از قبل کش‌شده را از یک پوشه‌ی محلی هم جست‌وجو می‌کند، و
// چندتایی از AARهایِ androidx که دانلودشان موفق نمی‌شد را به‌صورتِ یک
// مخزنِ محلیِ واقعیِ Maven (با pom درست) اضافه می‌کند
repositories {
    maven { url = uri("../local-maven-repo") }
    flatDir { dirs("../local-libs") }
}

// 🔧 اطلاعات امضای نسخه‌ی release — از android/key.properties خوانده می‌شود
// (این فایل در .gitignore است و هرگز نباید commit شود)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.malek.bpm"
    compileSdk = 36
    buildToolsVersion = "36.1.0"
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.malek.bpm"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters.add("arm64-v8a")
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 🔧 اصلاح: امضا با کلید واقعی release (نه debug) — کلید
            // debug یکی از دلایل اصلی هشدار «برنامه ناشناس/خطرناک» در
            // Play Protect است. اگر key.properties موجود نباشد
            // (مثلاً روی ماشین توسعه‌دهنده‌ی دیگر)، برای اینکه
            // `flutter run --release` باز هم کار کند، به کلید debug
            // برمی‌گردد.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
