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
        // Profile wie Release durch R8 schicken: integration_test läuft nicht im
        // Release-Modus (`flutter drive --release` geht dafür nicht), wohl aber
        // mit `--profile`. So prüft der CI-Job android-ocr-emulator die
        // Belegerkennung mit denselben Keep-Regeln, an denen sie auf dem Pixel 10
        // brach. Profile wird nie ausgeliefert; Debug-Signatur genügt.
        // Den vom Flutter-Plugin angelegten profile-Typ nur ergänzen, nicht selbst
        // anlegen: ein eigener Typ bekommt die Plugin-Abhängigkeiten nicht (R8:
        // „Missing class …LocalAuthPlugin“, CI-Lauf 78).
        configureEach {
            if (name != "profile") return@configureEach
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
}
