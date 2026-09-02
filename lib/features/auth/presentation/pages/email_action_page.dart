import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/errors/error_message_mapper.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final rifaLaPassword = widget.mode == 'resetPassword';

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
              switch (_fase) {
                _Fase.lavora => const _Attesa(),
                _Fase.fatto => _Fatto(rifaLaPassword: rifaLaPassword),
                _Fase.chiediLaPassword => const DisplayTitle('UNA\nNUOVA'),
                _Fase.errore => const DisplayTitle('QUESTO\nLINK NO'),
              },
              if (_fase == _Fase.chiediLaPassword) ...[
                const SizedBox(height: AppSpacing.sm),
                HighlightedText(
                  'Scrivi la password nuova per '
                  '${_indirizzo ?? 'il tuo account'}.',
                  highlight: _indirizzo ?? '',
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(
                    labelText: 'Password nuova',
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                CrasyButton(
                  label: 'Salva',
                  loading: _inCorso,
                  onPressed: _salvaLaPassword,
                ),
              ],
              if (_errore case final messaggio?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  messaggio,
                  style: texts.bodyMedium?.copyWith(color: palette.accent),
                ),
              ],
              if (_fase == _Fase.fatto || _fase == _Fase.errore) ...[
                const SizedBox(height: AppSpacing.xl),
                // **Non e' un ornamento: e' la via d'uscita.** Senza, questa
                // resta una pagina del browser senza nessun posto dove andare,
                // che e' esattamente la sensazione che si voleva togliere.
                CrasyButton(
                  label: 'Entra in CRASY',
                  onPressed: () => context.go(AppRoutes.splash),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Attesa extends StatelessWidget {
  const _Attesa();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: AppSpacing.xxl),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _Fatto extends StatelessWidget {
  const _Fatto({required this.rifaLaPassword});

  final bool rifaLaPassword;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DisplayTitle(rifaLaPassword ? 'PASSWORD\nCAMBIATA' : 'TUTTO\nA POSTO'),
        const SizedBox(height: AppSpacing.sm),
        HighlightedText(
          rifaLaPassword
              ? 'Adesso entra con quella nuova.'
              : "Il tuo indirizzo e' confermato. Se hai l'app aperta, "
                    "torna li': ti fa passare da sola.",
          highlight: rifaLaPassword ? 'quella nuova' : 'confermato',
        ),
      ],
    );
  }
}
