import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/errors/error_message_mapper.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dove si atterra cliccando il link di un messaggio di CRASY.
///
/// **Prima si atterrava su una pagina di Firebase**: bianca, mezza in inglese,
/// su un indirizzo che nessuno aveva mai sentito nominare — per giunta il
/// vecchio nome del progetto. L'ultima cosa che vedeva chi si era appena
/// registrato era una schermata che non sembrava avere niente a che fare con
/// l'app appena scaricata: il momento in cui uno ha fatto tutto giusto e si
/// chiede se ha sbagliato qualcosa.
///
/// Adesso il link porta qui, che e' casa nostra. Il lavoro sotto e' lo stesso —
/// il codice si consegna a Firebase e Firebase decide — ma quello che si legge
/// e' scritto da noi.
///
/// ## Perche' una pagina sola per due cose diverse
///
/// L'indirizzo del gestore e' **uno per tutto il progetto**: la conferma
/// dell'indirizzo e la password dimenticata arrivano dallo stesso posto, e non
/// si possono separare. Facendone una che gestisce solo la conferma, il giorno
/// che qualcuno chiede di rifarsi la password troverebbe una schermata che non
/// sa cosa fare del suo codice — e resterebbe fuori dal proprio account. Il
/// tipo di operazione arriva scritto nel link, e qui si guarda quello.
///
/// ## Non e' una schermata dell'app: e' una pagina web
///
/// E questo cambia come va composta. Chi arriva qui e' quasi sempre **dentro un
/// browser**, spesso su un computer, e una schermata pensata per un telefono
/// aperta a tutta larghezza diventa una riga di testo lunga trenta centimetri.
/// Per questo il contenuto sta dentro una colonna stretta e centrata: e' la
/// stessa cosa che fa qualunque pagina fatta per essere letta.
class EmailActionPage extends ConsumerStatefulWidget {
  const EmailActionPage({required this.mode, required this.code, super.key});

  /// Che operazione ha chiesto Firebase: `verifyEmail`, `resetPassword`, ...
  final String mode;

  /// Il codice usa e getta che sta dentro il link.
  final String code;

  @override
  ConsumerState<EmailActionPage> createState() => _EmailActionPageState();
}

enum _Fase { lavora, fatto, chiediLaPassword, errore }

class _EmailActionPageState extends ConsumerState<EmailActionPage> {
  final _password = TextEditingController();

  var _fase = _Fase.lavora;
  var _inCorso = false;
  String? _errore;

  /// A chi appartiene il codice, quando si sta rifacendo la password.
  String? _indirizzo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _lavora());
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _lavora() async {
    final auth = ref.read(authRepositoryProvider);

    if (widget.code.isEmpty) {
      setState(() {
        _fase = _Fase.errore;
        _errore = "Questo link non e' completo. Riaprilo dal messaggio.";
      });

      return;
    }

    try {
      if (widget.mode == 'resetPassword') {
        final indirizzo = await auth.checkPasswordResetCode(widget.code);

        if (mounted) {
          setState(() {
            _indirizzo = indirizzo;
            _fase = _Fase.chiediLaPassword;
          });
        }

        return;
      }

      await auth.applyActionCode(widget.code);

      // **Serve a chi ha l'app aperta in questa stessa finestra.**
      //
      // La conferma avviene sul server, e la sessione che abbiamo in mano non
      // se ne accorge da sola: senza questa riga il muro della conferma
      // resterebbe chiuso proprio a chi l'ha appena superato.
      await auth.reload();

      if (mounted) {
        setState(() => _fase = _Fase.fatto);
      }
    } on Object catch (errore) {
      if (mounted) {
        setState(() {
          _fase = _Fase.errore;
          _errore = ErrorMessageMapper.map(errore);
        });
      }
    }
  }

  Future<void> _salvaLaPassword() async {
    if (_password.text.trim().length < 6) {
      setState(() => _errore = 'Almeno sei caratteri.');

      return;
    }

    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .confirmPasswordReset(
            code: widget.code,
            newPassword: _password.text.trim(),
          );

      if (mounted) {
        setState(() => _fase = _Fase.fatto);
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

  /// Cosa c'e' scritto sul tasto di uscita.
  ///
  /// Su un telefono si esce **verso l'app**, ovunque si sia arrivati da: e' da
  /// li' che si veniva. Su un computer l'app non c'e', e l'unico posto dove
  /// andare e' il sito.
  String get _etichettaDelTasto =>
      _daTelefono ? 'Apri CRASY' : 'Entra in CRASY';

  bool get _daTelefono =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  /// Riapre l'app, e se non ci riesce resta sul sito.
  ///
  /// **Il ripiego non e' una cortesia: e' il caso normale per meta' della
  /// gente.** Chi apre il messaggio dal computer, o dal telefono di qualcun
  /// altro, l'app non ce l'ha — e un tasto che non fa niente e' peggio di un
  /// tasto che porta nel posto sbagliato.
  Future<void> _esci() async {
    if (_daTelefono) {
      try {
        final aperta = await launchUrl(
          Uri.parse('crasy://'),
          mode: LaunchMode.externalApplication,
        );

        if (aperta) {
          return;
        }
      } on Object catch (_) {
        // App non installata, o browser che non lascia provare: si resta qui.
      }
    }

    if (mounted) {
      context.go(AppRoutes.splash);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rifaLaPassword = widget.mode == 'resetPassword';

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page,
                vertical: AppSpacing.xxl,
              ),
              child: ConstrainedBox(
                // **Una colonna stretta, non tutta la finestra.** Una riga di
                // testo lunga quanto un monitor si legge male: l'occhio, alla
                // fine della riga, non ritrova l'inizio di quella dopo. E'
                // il motivo per cui i giornali hanno le colonne.
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(child: CrasyWordmark()),
                    const SizedBox(height: AppSpacing.xxl),
                    if (rifaLaPassword && _fase == _Fase.chiediLaPassword)
                      ..._formDellaPassword(context)
                    else
                      ..._risposta(context, rifaLaPassword),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Le tre schermate che non chiedono niente: sto lavorando, e' fatta, non va.
  ///
  /// Sono **centrate e con un segno grande sopra**, e non e' decorazione: un
  /// simbolo si legge in mezzo secondo e una frase in tre. Chi arriva qui vuole
  /// sapere una cosa sola — e' andata o no — e deve saperla prima di mettersi a
  /// leggere.
  List<Widget> _risposta(BuildContext context, bool rifaLaPassword) {
    final palette = context.palette;
    final texts = context.texts;

    if (_fase == _Fase.lavora) {
      return const [
        SizedBox(height: AppSpacing.xl),
        Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ];
    }

    final andata = _fase == _Fase.fatto;

    return [
      Center(
        child: _Bollo(
          icona: andata ? Icons.check_rounded : Icons.link_off_rounded,
          pieno: andata,
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Center(
        child: DisplayTitle(
          andata
              ? (rifaLaPassword ? 'PASSWORD\nCAMBIATA' : 'TUTTO\nA POSTO')
              : 'QUESTO\nLINK NO',
          style: texts.displaySmall,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Center(
        child: HighlightedText(
          andata
              ? (rifaLaPassword
                    ? 'Adesso entra con quella nuova.'
                    : "Il tuo indirizzo e' confermato. Se hai l'app aperta, "
                          "torna li': ti fa passare da sola.")
              : (_errore ??
                    "Il link e' scaduto, o e' gia' stato usato una volta."),
          highlight: andata
              ? (rifaLaPassword ? 'quella nuova' : 'confermato')
              : '',
          style: texts.bodyMedium?.copyWith(color: palette.textSecondary),
        ),
      ),
      const SizedBox(height: AppSpacing.xxl),
      // **Non e' un ornamento: e' la via d'uscita.** Senza, questa resta una
      // pagina del browser senza nessun posto dove andare, che e' esattamente
      // la sensazione che si voleva togliere.
      //
      // Sul telefono prova a **riaprire l'app**, che e' da dove si veniva: chi
      // ha appena rifatto la password non voleva visitare un sito, voleva
      // rientrare. Restare qui vorrebbe dire rifare l'accesso dentro un
      // browser per poi rifarlo un'altra volta nell'app.
      CrasyButton(label: _etichettaDelTasto, onPressed: _esci),
      const SizedBox(height: AppSpacing.md),
      Center(
        child: Text(
          'crasyapp.com',
          style: texts.labelSmall?.copyWith(color: palette.textFaint),
        ),
      ),
    ];
  }

  List<Widget> _formDellaPassword(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return [
      const DisplayTitle('UNA\nNUOVA'),
      const SizedBox(height: AppSpacing.sm),
      HighlightedText(
        'Scrivi la password nuova per ${_indirizzo ?? 'il tuo account'}.',
        highlight: _indirizzo ?? '',
        style: texts.bodyMedium?.copyWith(color: palette.textSecondary),
      ),
      const SizedBox(height: AppSpacing.xl),
      TextField(
        controller: _password,
        obscureText: true,
        autofillHints: const [AutofillHints.newPassword],
        onSubmitted: (_) => _salvaLaPassword(),
        decoration: const InputDecoration(labelText: 'Password nuova'),
      ),
      if (_errore case final messaggio?) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(
          messaggio,
          style: texts.bodyMedium?.copyWith(color: palette.accent),
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
      CrasyButton(
        label: 'Salva',
        loading: _inCorso,
        onPressed: _salvaLaPassword,
      ),
    ];
  }
}

/// Il segno tondo sopra il titolo.
///
/// Pieno di rosso quando e' andata, vuoto con il solo contorno quando non e'
/// andata: **la differenza si vede anche senza distinguere i colori**, ed e' la
/// stessa regola delle fotocamere in cima alla home.
class _Bollo extends StatelessWidget {
  const _Bollo({required this.icona, required this.pieno});

  final IconData icona;
  final bool pieno;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: pieno ? palette.accent : null,
        border: pieno ? null : Border.all(color: palette.line, width: 2),
      ),
      child: Icon(
        icona,
        size: 38,
        color: pieno ? palette.onAccent : palette.textFaint,
      ),
    );
  }
}
