import java.util.Properties

// **Le credenziali di firma stanno fuori dal repository.**
//
// `android/key.properties` non e' versionato e la chiave vera nemmeno: dentro
// c'e' la password con cui si firma l'app che va su Google Play, e una
// credenziale in un repository e' una credenziale pubblica — anche in un
// repository privato, perche' basta un collaboratore o un giorno in cui
// diventa pubblico per sbaglio.
//
// Se il file non c'e' — su una macchina appena clonata, o in una prova — la
// versione di rilascio si firma con la chiave di sviluppo e lo dice. Non
// fallisce: `flutter run --release` deve continuare a funzionare per chiunque.
val chiavi = Properties()
val fileDelleChiavi = rootProject.file("key.properties")

if (fileDelleChiavi.exists()) {
    fileDelleChiavi.inputStream().use { chiavi.load(it) }
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.crasy.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // **Il nome con cui Android conosce CRASY, per sempre.**
        //
        // Uguale a quello di iPhone, e non e' vezzo: un solo nome da cercare
        // nei registri, nelle console e nei documenti. Era rimasto
        // `com.example.app_incontri` — il modello di Flutter piu' il nome
        // dell'app di appuntamenti da cui e' nato il progetto — e Play rifiuta
        // qualunque cosa cominci per `com.example`.
        //
        // **Dopo il primo caricamento non si cambia mai piu'**: e' l'unica
        // decisione di questo file che non si puo' correggere dopo.
        applicationId = "app.crasy.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("rilascio") {
            val percorso = chiavi.getProperty("storeFile")

            if (percorso != null) {
                storeFile = file(percorso)
                storePassword = chiavi.getProperty("storePassword")
                keyAlias = chiavi.getProperty("keyAlias")
                keyPassword = chiavi.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // **Con la chiave vera, se c'e'.**
            //
            // Prima era la chiave di sviluppo, quella che Android crea da solo
            // sulla macchina di chi programma: Google Play rifiuta un pacchetto
            // firmato cosi', e il modello di Flutter lo lascia li' con un
            // commento che dice di cambiarlo.
            signingConfig = if (chiavi.getProperty("storeFile") != null) {
                signingConfigs.getByName("rilascio")
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
