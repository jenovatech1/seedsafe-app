plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

// --- Load keystore props (opsional) ---
val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.jenova.seedsafe"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    defaultConfig {
        applicationId = "com.jenova.seedsafe"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // --- Kotlin DSL untuk flavor dimension & flavors ---
    flavorDimensions += "env"

    productFlavors {
        create("free") {
            dimension = "env"
            applicationIdSuffix = ".free" // com.example.seed_safe.free
            resValue("string", "app_name", "SeedSafe (Free)")
        }
        create("pro") {
            dimension = "env"
            // Tanpa suffix → applicationId = com.example.seed_safe
            resValue("string", "app_name", "SeedSafe")
        }
    }

    // --- Signing configs (aman kalau key.properties tidak ada) ---
    signingConfigs {
        create("release") {
            if (keyPropertiesFile.exists()) {
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
                keyProperties.getProperty("storeFile")?.let { path ->
                    storeFile = file(path)
                }
                storePassword = keyProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
