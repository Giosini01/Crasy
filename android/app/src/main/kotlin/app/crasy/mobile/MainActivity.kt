package app.crasy.mobile

import android.app.NotificationChannel
import android.content.Intent
import android.content.pm.PackageManager
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * **Dentro CRASY non si fanno screenshot.**
 *
 * `FLAG_SECURE` dice ad Android che questa finestra non si cattura: lo
 * screenshot non parte — il sistema avvisa che "l'app non consente di acquisire
 * schermate" — e la registrazione dello schermo riprende un rettangolo nero.
 * Vale anche per l'anteprima nelle app recenti, che altrimenti lascerebbe
 * l'ultima schermata visibile a chi prende il telefono in mano.
 *
 * ## Perche' qui dentro
 *
 * Le foto e i video delle challenge sono di chi li ha mandati, e sono visibili
 * solo a chi sta nella gara. Senza questa riga bastano due dita per portarne
 * una fuori e farne quello che si vuole — e la promessa che l'app fa a chi
 * partecipa, cioe' che quella foto resta li' dentro, non sarebbe una promessa.
 *
 * Non rende impossibile copiare: chi vuole punta un secondo telefono sullo
 * schermo e fotografa. **Quello non si puo' fermare, e nessuna app lo ferma.**
 * Si ferma il gesto da due secondi, che e' quello che succede davvero.
 *
 * ## Su iPhone questa cosa non esiste
 *
 * iOS non ha niente di simile, e non e' una mancanza nostra: Apple non da' a
 * nessuna app il modo di impedire uno screenshot. Si puo' solo **sapere** che e'
 * stato fatto, dopo. Quindi questa protezione c'e' su Android e non su iPhone, e
 * va saputo invece che scoperto: promettere a chi partecipa che le sue foto non
 * si possono catturare sarebbe falso per meta' delle persone.
 */
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )

        creaIlCanaleDelleNotifiche()
    }

    /**
     * **Il canale delle notifiche, con il suono di CRASY.**
     *
     * Da Android 8 il suono di una notifica non lo sceglie chi la manda: lo
     * decide il **canale** in cui arriva. Il server mandava il nome del suono e
     * basta, e senza un canale che lo portasse dentro ogni notifica finiva nel
     * canale di ripiego di Firebase, con il suono di sistema. Il suono di CRASY
     * non si e' mai sentito su un Android recente.
     *
     * Il canale si crea qui, all'avvio, e ricrearlo non fa niente: Android lo
     * tiene com'e' la prima volta. Per questo il suo nome non va cambiato — un
     * canale non si modifica, se ne fa uno nuovo — e deve restare uguale a
     * quello scritto nel manifesto e in `functions/index.js`.
     */
    private fun creaIlCanaleDelleNotifiche() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val suono = Uri.parse("android.resource://$packageName/${R.raw.crasy}")
        val canale = NotificationChannel(
            CANALE,
            "Notifiche di CRASY",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Fiamme, sfide, partecipazioni e vittorie."
            setSound(
                suono,
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            enableVibration(true)
        }

        getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(canale)
    }

    /**
     * **Una propria foto su Instagram Stories**, con il sistema ufficiale di
     * Meta: l'intento `com.instagram.share.ADD_TO_STORY` con l'immagine come
     * sfondo e l'ID dell'app Facebook in `source_application`. L'immagine passa
     * da una cartella della cache che solo Instagram puo' leggere, e solo per
     * questo intento. Vedi `lib/core/services/share/instagram_story.dart`.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "crasy/instagram")
            .setMethodCallHandler { chiamata, risposta ->
                when (chiamata.method) {
                    "disponibile" -> risposta.success(instagramInstallato())
                    "storia" -> {
                        val immagine = chiamata.argument<ByteArray>("immagine")
                        val appId = chiamata.argument<String>("appId")
                        val tipo = chiamata.argument<String>("tipo") ?: "image/png"

                        risposta.success(
                            immagine != null &&
                                !appId.isNullOrEmpty() &&
                                apriLaStoria(immagine, appId, tipo),
                        )
                    }
                    else -> risposta.notImplemented()
                }
            }
    }

    private fun instagramInstallato(): Boolean =
        try {
            packageManager.getPackageInfo(INSTAGRAM, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }

    private fun apriLaStoria(immagine: ByteArray, appId: String, tipo: String): Boolean =
        try {
            val cartella = File(cacheDir, "instagram").apply { mkdirs() }
            val file = File(cartella, if (tipo == "image/jpeg") "storia.jpg" else "storia.png")

            file.writeBytes(immagine)

            val indirizzo = FileProvider.getUriForFile(this, "$packageName.instagram", file)
            val intento = Intent("com.instagram.share.ADD_TO_STORY").apply {
                putExtra("source_application", appId)
                setDataAndType(indirizzo, tipo)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                setPackage(INSTAGRAM)
            }

            if (intento.resolveActivity(packageManager) == null) {
                false
            } else {
                grantUriPermission(INSTAGRAM, indirizzo, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                startActivity(intento)
                true
            }
        } catch (e: Exception) {
            false
        }

    private companion object {
        const val CANALE = "crasy"
        const val INSTAGRAM = "com.instagram.android"
    }
}
