package app.crasy.mobile

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

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
    }
}
