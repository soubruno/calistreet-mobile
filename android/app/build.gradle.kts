plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

// Carrega as propriedades do keystore
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else {
    throw GradleException("key.properties not found at ${keystorePropertiesFile.path}")
}

android {
    namespace = "br.com.calistreet"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "br.com.calistreet"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias") ?: error("keyAlias missing in key.properties")
            keyPassword = keystoreProperties.getProperty("keyPassword") ?: error("keyPassword missing in key.properties")
            
            val storeFilePath = keystoreProperties.getProperty("storeFile") ?: error("storeFile missing in key.properties")
            storeFile = rootProject.file(storeFilePath)
            if (!storeFile!!.exists()) {
                throw GradleException("Keystore file not found at: ${storeFile!!.absolutePath}")
            }

            storePassword = keystoreProperties.getProperty("storePassword") ?: error("storePassword missing in key.properties")
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}