import 'package:crasy/core/errors/error_message_mapper.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Il numero di telefono, una volta sola.
///
/// **Non serve a chiamare nessuno: serve a rendere caro un account falso.**
/// Il vincitore di una gara lo decidono i voti, e sulle gare c'e' del denaro:
/// finche' iscriversi costa un indirizzo email — dieci secondi, gratis, quanti
/// se ne vogliono — chiunque puo' costruirsi cinque profili e cinque voti, e la
/// classifica che assegna il premio smette di significare qualcosa.
///
/// Un numero di telefono non risolve tutto: si comprano SIM, e chi vuole
/// davvero imbrogliare trova il modo. **Alza il prezzo**, e per una gara da
/// cinque euro il prezzo diventa piu' alto del premio. E' tutto quello che
/// serve.
///
/// Sta fra la conferma dell'email e i consensi, cioe' prima che si possa
/// toccare qualunque cosa. Chiederlo dopo — al primo voto, al primo scatto —
/// vorrebbe dire fermare qualcuno nel mezzo di una cosa che stava facendo.
class VerifyPhonePage extends ConsumerStatefulWidget {
  const VerifyPhonePage({super.key});

  @override
  ConsumerState<VerifyPhonePage> createState() => _VerifyPhonePageState();
}

class _VerifyPhonePageState extends ConsumerState<VerifyPhonePage> {
  final _numero = TextEditingController();
  final _codice = TextEditingController();

  /// L'identificativo della verifica in corso, quando il codice e' partito.
  String? _verifica;

  var _inCorso = false;
  String? _errore;

  @override
  void initState() {
    super.initState();
    // **Prima di chiedere, si guarda se c'e' gia'.**
    //
    // Agganciare il numero e scriverlo nel profilo sono due passaggi distinti,
    // e fra i due ci sta di tutto: la rete che cade, l'app chiusa, un difetto
    // nostro. Chi si e' fermato li' in mezzo ha il numero legato all'account e
    // il profilo che non lo sa — e senza questa riga la schermata glielo
    // richiede all'infinito, mentre Firebase si rifiuta di agganciarlo una
    // seconda volta. Un vicolo cieco creato da noi.
    WidgetsBinding.instance.addPostFrameCallback((_) => _recupera());
  }

  /// Se il numero e' gia' agganciato, finisce il lavoro senza chiedere niente.
  Future<void> _recupera() async {
    final gia = ref.read(authRepositoryProvider).currentPhoneNumber;
    final sessione = ref.read(authStateProvider);

    if (gia == null ||
        gia.isEmpty ||
        sessione is! AuthenticatedAuthState ||
        !mounted) {
      return;
    }

    setState(() => _inCorso = true);

    try {
      await ref
          .read(userProfileRepositoryProvider)
          .savePhone(userId: sessione.user.id, phone: gia);
    } on Object catch (_) {
      // Non riuscito: resta la schermata normale, che e' un ripiego onesto.
    }

    if (mounted) {
      setState(() => _inCorso = false);
    }
  }

  @override
  void dispose() {
    _numero.dispose();
    _codice.dispose();
    super.dispose();
  }

  /// Il numero come lo vuole Firebase: con il prefisso internazionale.
  ///
  /// Chi scrive `3331234567` intende l'Italia, e pretendere che si ricordi il
  /// `+39` vuol dire far fallire meta' delle registrazioni con un messaggio che
  /// parla di formati. Si aggiunge qui.
  String get _numeroPerFirebase {
    final scritto = _numero.text.trim().replaceAll(RegExp(r'[\s.\-]'), '');

    if (scritto.startsWith('+')) {
      return scritto;
    }

    if (scritto.startsWith('00')) {
      return '+${scritto.substring(2)}';
    }

    return '+39$scritto';
  }

  Future<void> _mandaIlCodice() async {
    final scritto = _numero.text.trim();

    if (scritto.length < 8) {
      setState(() => _errore = 'Scrivi il tuo numero di cellulare.');

      return;
    }

    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      final verifica = await ref
          .read(authRepositoryProvider)
          .sendPhoneCode(phoneNumber: _numeroPerFirebase);

      if (mounted) {
        setState(() => _verifica = verifica);
      }
    } on Object catch (errore) {
      if (mounted) {
        setState(() => _errore = ErrorMessageMapper.map(errore));
      }
    } finally {
      if (mounted) {
        setState(() => _inCorso = false);
      }
    }
  }

  Future<void> _controllaIlCodice() async {
    final verifica = _verifica;

    if (verifica == null || _codice.text.trim().length < 6) {
      setState(() => _errore = 'Scrivi le sei cifre che hai ricevuto.');

      return;
    }

    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      final confermato = await ref
          .read(authRepositoryProvider)
          .confirmPhoneCode(
            verificationId: verifica,
            code: _codice.text.trim(),
          );

      // **Il numero da salvare non puo' mai essere vuoto.**
      //
      // Era il difetto che mandava la schermata in circolo. Firebase, dopo aver
      // agganciato il numero, non sempre lo restituisce subito: sul web
      // l'aggiornamento della sessione arriva un istante dopo, e quello che
      // tornava era una stringa vuota. Vuota finiva nel profilo, il profilo
      // risultava senza numero, e il muro rimandava alla stessa schermata —
      // **senza nessun errore**, perche' dal punto di vista del codice era
      // andato tutto bene.
      //
      // Quello scritto qui sopra lo sappiamo comunque: e' il numero a cui e'
      // appena arrivato il codice, e la verifica e' passata. Se Firebase ce ne
      // da' una versione sua la si preferisce — e' scritta nella forma
      // canonica — altrimenti vale la nostra.
      final numero = confermato.isNotEmpty ? confermato : _numeroPerFirebase;

      if (numero.isEmpty) {
        throw StateError('numero mancante');
      }

      // Il numero finisce nel profilo: e' li' che l'app va a guardare per
      // sapere se questa persona ha gia' fatto il passaggio, e senza quel campo
      // la schermata tornerebbe a ogni avvio.
      final sessione = ref.read(authStateProvider);

      if (sessione is AuthenticatedAuthState) {
        await ref
            .read(userProfileRepositoryProvider)
            .savePhone(userId: sessione.user.id, phone: numero);
      }
    } on Object catch (errore) {
      if (mounted) {
        setState(() {
          _errore = ErrorMessageMapper.map(errore);
          _inCorso = false;
        });
      }

      return;
    }

    if (mounted) {
      setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final aspettaIlCodice = _verifica != null;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xl,
              AppSpacing.page,
              AppSpacing.xxl,
            ),
            children: [
              const CrasyWordmark(),
              const SizedBox(height: AppSpacing.xxl),
              const DisplayTitle('IL TUO\nNUMERO'),
              const SizedBox(height: AppSpacing.sm),
              HighlightedText(
                aspettaIlCodice
                    ? 'Ti abbiamo mandato sei cifre. Scrivile qui sotto.'
                    : 'Qui girano dei soldi veri, e a decidere chi vince sono i '
                          'voti. Il numero serve a questo: un account per '
                          'persona.',
                highlight: aspettaIlCodice
                    ? 'sei cifre'
                    : 'un account per persona',
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!aspettaIlCodice) ...[
                TextField(
                  controller: _numero,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Numero di cellulare',
                    hintText: '333 1234567',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Non lo vede nessun altro utente, e non compare da nessuna '
                  'parte nell\'app.',
                  style: texts.bodySmall?.copyWith(color: palette.textFaint),
                ),
              ] else ...[
                TextField(
                  controller: _codice,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Codice',
                    hintText: '123456',
                  ),
                ),
                // Il numero scritto, per accorgersi subito di uno sbaglio senza
                // dover tornare indietro alla cieca.
                Text(
                  'Mandato a $_numeroPerFirebase',
                  style: texts.bodySmall?.copyWith(color: palette.textFaint),
                ),
              ],
              if (_errore case final messaggio?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  messaggio,
                  style: texts.bodyMedium?.copyWith(color: palette.accent),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              CrasyButton(
                label: aspettaIlCodice ? 'Conferma' : 'Mandami il codice',
                loading: _inCorso,
                onPressed: aspettaIlCodice
                    ? _controllaIlCodice
                    : _mandaIlCodice,
              ),
              if (aspettaIlCodice) ...[
                const SizedBox(height: AppSpacing.sm),
                // **Si torna indietro senza perdere niente.** Un numero
                // sbagliato di una cifra e' l'errore piu' comune di questa
                // schermata, e senza questa riga si resta bloccati ad aspettare
                // un messaggio che non arrivera' mai.
                TextButton(
                  onPressed: _inCorso
                      ? null
                      : () => setState(() {
                          _verifica = null;
                          _codice.clear();
                          _errore = null;
                        }),
                  child: const Text('Ho sbagliato numero'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
