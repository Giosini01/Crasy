allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// **Il lint di rilascio, spento nei moduli dei plugin.**
//
// `flutter build appbundle` — il formato che Play vuole per pubblicare — fa
// girare `lintVitalRelease`, che `flutter build apk` non fa. E li' il modulo di
// Stripe si fermava: per analizzare il proprio codice si tira dietro
// `stripe-android-issuing-push-provisioning`, che chiede
// `play-services-tapandpay:17.1.2` — una libreria che su Google Maven e Maven
// Central non c'e'. Risultato: l'APK si compilava e il bundle no, e il bundle e'
// l'unico dei due che si possa caricare.
//
// **Non si spegne un controllo sul nostro codice.** Quello che si salta e'
// l'analisi statica *dentro i moduli dei plugin* — codice che non scriviamo noi,
// che arriva gia' pubblicato e che non possiamo correggere comunque. Il nostro
// resta sotto `dart analyze` e sotto le prove, che e' dove i nostri difetti si
// trovano davvero.
//
// Non cambia un byte di quello che finisce nell'app: lint guarda, non compila.
// **Si toglie dal classpath del lint, non dall'app.**
//
// Spegnere `checkReleaseBuilds` non bastava: la libreria serve al *classpath* del
// lint, e Gradle quel classpath lo risolve prima di decidere se il controllo va
// eseguito. Finche' resta dichiarata, la compilazione si ferma anche a controllo
// spento.
//
// Quindi si esclude li' e solo li': le configurazioni il cui nome finisce per
// `LintChecksClasspath`. Non e' una dipendenza dell'app — e' il pacchetto di
// regole che il lint carica per analizzare Stripe — e CRASY non usa niente del
// portafoglio Google. In quello che si installa sul telefono non cambia nulla,
// perche' da queste configurazioni non esce nessun byte compilato.
allprojects {
    configurations.configureEach {
        if (name.endsWith("LintChecksClasspath")) {
            exclude(
                group = "com.stripe",
                module = "stripe-android-issuing-push-provisioning",
            )
            exclude(group = "com.google.android.gms", module = "play-services-tapandpay")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
