import 'package:crasy/features/auth/domain/entities/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<AppUser> signUp({required String email, required String password});

  Future<AppUser> signIn({required String email, required String password});

  Future<void> signOut();

  /// Manda (o rimanda) il messaggio con il link di conferma.
  Future<void> sendEmailVerification();

  /// Manda il messaggio per rifarsi la password.
  ///
  /// **Non dice mai se quell'indirizzo esiste**, e non e' pigrizia: rispondere
  /// "questa email non e' registrata" regala a chiunque un modo di scoprire chi
  /// sta su CRASY, provando indirizzi finche' uno non risponde. Chi ha
  /// sbagliato a scrivere se ne accorge dal messaggio che non arriva.
  Future<void> sendPasswordReset({required String email});

  /// Consegna a Firebase il codice usa e getta che sta dentro il link.
  ///
  /// Vale per la conferma dell'indirizzo e per il cambio di indirizzo: sono
  /// operazioni che il server sa gia' fare da sole, e da qui non serve altro
  /// che passargli il codice.
  Future<void> applyActionCode(String code);

  /// Controlla che il codice per rifarsi la password sia ancora buono, e dice
  /// a chi appartiene.
  ///
  /// **Si chiede prima di mostrare il campo della password.** Un codice
  /// scaduto — dura un'ora — va detto subito: farlo scoprire dopo che uno ha
  /// scelto e riscritto una password nuova e' il modo piu' veloce di fargli
  /// pensare che sia colpa sua.
  Future<String> checkPasswordResetCode(String code);

  /// Scrive la password nuova.
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  });

  /// Richiede al server lo stato aggiornato dell'utente.
  ///
  /// Serve perche' la conferma dell'email avviene **fuori dall'app** — in una
  /// pagina del browser — e nessuno viene ad avvisarci. Senza questa richiesta
  /// l'app resterebbe convinta che l'indirizzo non sia confermato anche dopo
  /// che lo e'.
  Future<AppUser?> reload();

  /// Butta l'account in attesa di conferma.
  ///
  /// **Serve a liberare l'indirizzo.** Chi si registra e non riceve il
  /// messaggio — finisce nello spam, l'ha scritto storto, il suo fornitore lo
  /// blocca — resta con un account che esiste ma non entra, e con un indirizzo
  /// che da quel momento risulta gia' usato: non puo' rifare la registrazione
  /// e non puo' rifare niente. E' un vicolo cieco creato da noi.
  ///
  /// Non chiede la password: qui non si sta cancellando la vita di nessuno, si
  /// sta buttando un account vuoto — nessuna foto, nessun premio, nemmeno un
  /// profilo — e chi lo fa e' l'unico che potrebbe averlo creato, perche' e'
  /// dentro la sessione appena aperta.
  Future<void> discardUnverifiedAccount();

  /// Il numero gia' agganciato a questa sessione, se c'e'.
  ///
  /// **Serve a recuperare chi e' rimasto a meta'.** Agganciare il numero e
  /// scriverlo nel profilo sono due passaggi distinti, e fra i due ci sta di
  /// tutto: la rete che cade, l'app chiusa, un difetto nostro. Chi si ferma li'
  /// in mezzo si ritrova con il numero legato all'account ma il profilo che non
  /// lo sa — e la schermata glielo richiede all'infinito, mentre Firebase
  /// rifiuta di agganciarlo una seconda volta.
  ///
  /// Con questo, la schermata se ne accorge da sola e finisce il lavoro senza
  /// chiedere niente a nessuno.
  String? get currentPhoneNumber;

  /// Manda il codice via SMS e torna l'identificativo della verifica.
  ///
  /// **Il numero non serve a chiamare nessuno: serve a rendere caro un account
  /// falso.** Con dei soldi in palio e un vincitore deciso dai voti, cinque
  /// profili costruiti in cinque minuti valgono cinque voti, e la classifica
  /// che assegna il premio smette di significare qualcosa. Un indirizzo email
  /// si inventa in dieci secondi e gratis; un numero no.
  ///
  /// L'identificativo che torna e' il filo che tiene insieme le due meta'
  /// dell'operazione: si manda il codice adesso, si controlla fra un minuto,
  /// e nel frattempo l'app puo' anche essere stata ridisegnata dieci volte.
  Future<String> sendPhoneCode({required String phoneNumber});

  /// Controlla il codice e **attacca il numero all'account che gia' esiste**.
  ///
  /// Attacca, non sostituisce: si continua a entrare con email e password, e
  /// il numero diventa una seconda prova di identita' sullo stesso account.
  /// Facendone invece un secondo modo di accedere, chi cambia numero — o chi
  /// se lo fa intestare da qualcun altro — si porterebbe via l'account.
  ///
  /// Torna il numero in forma internazionale, quello che va salvato nel
  /// profilo.
  Future<String> confirmPhoneCode({
    required String verificationId,
    required String code,
  });

  /// Cancella l'account, per sempre.
  ///
  /// **La password si richiede davvero**, e non e' una formalita': Firebase
  /// rifiuta una cancellazione se l'accesso e' vecchio, e senza ripassare da
  /// qui l'operazione fallirebbe con un errore che parla di sessione scaduta
  /// mentre la persona sta cercando di andarsene. E' anche l'ultima difesa
  /// contro un telefono lasciato aperto sul tavolo.
  Future<void> deleteAccount({required String password});
}
