import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signierschlüssel aus android/key.properties. Die Datei ist bewusst nicht im
// Repository (siehe .gitignore) – ein veröffentlichter Upload-Key lässt sich bei
// Google Play nicht einfach zurückrufen. In CI wird sie aus Secrets erzeugt,
// siehe docs/RELEASE_PLAYBOOK.md.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "at.jesenko.buchhaltung"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications (Erinnerung „Belege senden“, FA-17.9)
        // setzt Desugaring der Java-Bibliotheken voraus.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "at.jesenko.buchhaltung"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Ohne key.properties fällt der Release-Build auf die Debug-Schlüssel
            // zurück, damit `flutter run --release` lokal funktioniert. Ein so
            // signiertes Bundle nimmt Google Play nicht an – das ist Absicht,
            // damit niemand versehentlich debug-signiert veröffentlicht.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
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

dependencies {
    // Theme.AppCompat für den Startbildschirm (Voraussetzung von local_auth)
    implementation("androidx.appcompat:appcompat:1.7.0")
    // Belegerkennung (L-2.20): ML Kit Texterkennung mit GEBÜNDELTEM Modell –
    // offline, kein Download über Google Play Services. Version auch in
    // ReceiptTextChannel.ENGINE_VERSION.
    implementation("com.google.mlkit:text-recognition:16.0.1")
    // QR-/Barcodes auf demselben Foto (L-27.1), ebenfalls GEBÜNDELT
    // (nicht play-services-mlkit-barcode-scanning): offline, kein Download.
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
    // Dokumentenscanner (FA-2.51): Modell und Oberfläche liefert Google
    // Play-Dienste (Download durch Play, ca. 300 KB in der App). Ohne
    // Play-Dienste nimmt die App automatisch die Kamera.
    implementation("com.google.android.gms:play-services-mlkit-document-scanner:16.0.0")
    // Desugaring für flutter_local_notifications (FA-17.9).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
