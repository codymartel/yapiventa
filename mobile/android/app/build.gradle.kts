import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clave de subida de Google Play: key.properties (ignorado por git) apunta a un
// keystore guardado fuera del repositorio. Sin ese archivo se firma con la clave
// de debug, solo para pruebas locales (`flutter run --release`).
val propiedadesClave = Properties()
val archivoClave = rootProject.file("key.properties")
if (archivoClave.exists()) {
    FileInputStream(archivoClave).use { propiedadesClave.load(it) }
}

android {
    namespace = "com.yapiventa.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.yapiventa.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (archivoClave.exists()) {
            create("release") {
                keyAlias = propiedadesClave.getProperty("keyAlias")
                keyPassword = propiedadesClave.getProperty("keyPassword")
                storeFile = file(propiedadesClave.getProperty("storeFile"))
                storePassword = propiedadesClave.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (archivoClave.exists()) "release" else "debug",
            )
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
