plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val cloudKeystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
val cloudKeystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
val cloudKeyAlias = System.getenv("ANDROID_KEY_ALIAS")
val cloudKeyPassword = System.getenv("ANDROID_KEY_PASSWORD")
val hasCloudSigning = listOf(
    cloudKeystorePath,
    cloudKeystorePassword,
    cloudKeyAlias,
    cloudKeyPassword,
).all { !it.isNullOrBlank() }

android {
    namespace = "com.example.mudanzas"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.mudanzas"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasCloudSigning) {
            create("cloudRelease") {
                storeFile = file(cloudKeystorePath!!)
                storePassword = cloudKeystorePassword
                keyAlias = cloudKeyAlias
                keyPassword = cloudKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // GitHub Actions usa una llave estable guardada como secreto. En
            // desarrollo local conservamos la firma de prueba existente.
            signingConfig = signingConfigs.getByName(
                if (hasCloudSigning) "cloudRelease" else "debug",
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
