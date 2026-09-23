import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/payments/domain/entities/payout_details.dart';
import 'package:crasy/features/payments/presentation/providers/payments_providers.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **I dati per farsi mandare i soldi, chiesti una volta sola.**
///
/// Si arriva qui solo premendo "preleva", e non prima. Alla registrazione non
/// si chiede niente: uno si iscrive per fare una foto assurda, e un modulo con
/// codice fiscale e IBAN davanti alla porta e' il modo piu' rapido di farlo
/// tornare indietro. Finche' non ha vinto niente, quei dati non servono a
/// nessuno — nemmeno a noi.
///
/// **Quando invece ha vinto, servono davvero**, e non per burocrazia nostra:
/// mandare del denaro a qualcuno senza sapere chi e' non e' consentito, a
/// nessuno. Tanto vale dirlo con quelle parole invece di far sembrare un
/// capriccio una legge.
///
/// La foto del documento **non si chiede qui**. Quella la chiede Stripe nella
/// sua pagina, una volta, ed e' giusto cosi': verificarla e' un mestiere, e
/// custodire le carte d'identita' di centinaia di persone e' una responsabilita'
/// che non si prende chi puo' evitarla.
class PayoutDetailsPage extends ConsumerStatefulWidget {
  const PayoutDetailsPage({super.key});

  @override
  ConsumerState<PayoutDetailsPage> createState() => _PayoutDetailsPageState();
}

class _PayoutDetailsPageState extends ConsumerState<PayoutDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _cognome = TextEditingController();
  final _codice = TextEditingController();
  final _iban = TextEditingController();

  bool _working = false;
  String? _error;
  bool _riempito = false;

  @override
  void dispose() {
    _nome.dispose();
    _cognome.dispose();
    _codice.dispose();
    _iban.dispose();
    super.dispose();
  }

  /// Chi li ha gia' messi una volta li ritrova scritti: si viene qui anche per
  /// correggere un IBAN, non solo per metterlo la prima volta.
  void _riempiUnaVolta(PayoutDetails? dati) {
    if (_riempito || dati == null) {
      return;
    }

    _riempito = true;
    _nome.text = dati.firstName;
    _cognome.text = dati.lastName;
    _codice.text = dati.fiscalCode;
    _iban.text = dati.iban;
  }

  Future<void> _salva() async {
    // **La data di nascita non si richiede: c'e' gia'.** La si da' iscrivendosi
    // — serve a tenere fuori i minorenni — e ridomandarla qui vorrebbe dire
    // farsi raccontare due volte la stessa cosa e poi doverle tenere
    // d'accordo. Si prende dal profilo, e se li' manca o e' di un minorenne il
    // controllo scatta lo stesso.
    final nato = ref.read(currentUserProfileProvider).valueOrNull?.birthDate;
    final erroreData = PayoutValidators.birthDate(nato);

    if (!(_formKey.currentState?.validate() ?? false) || erroreData != null) {
      setState(() => _error = erroreData);

      return;
    }

    final repository = ref.read(walletRepositoryProvider);
    final userId = ref.read(currentUserIdProvider);

    if (repository == null || userId == null) {
      return;
    }

    setState(() {
      _working = true;
      _error = null;
    });

    try {
      await repository.savePayoutDetails(
        userId,
        PayoutDetails(
          firstName: _nome.text,
          lastName: _cognome.text,
          fiscalCode: _codice.text,
          iban: _iban.text,
          birthDate: nato,
        ),
      );
    } on Object {
      if (mounted) {
        setState(() {
          _working = false;
          _error = 'Non siamo riusciti a salvarli. Riprova fra poco.';
        });
      }

      return;
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    _riempiUnaVolta(ref.watch(payoutDetailsProvider).valueOrNull);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Dati per il prelievo'),
      ),
      body: AppBackground(
        child: SafeArea(
          top: false,
          bottom: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.lg,
                AppSpacing.page,
                AppSpacing.xxl,
              ),
              children: [
                Text(
                  'Servono per mandarti i soldi, e li chiediamo adesso perché '
                  'adesso ne hai. Mandare denaro a qualcuno senza sapere chi è '
                  'non è consentito a nessuno: si compila una volta sola.',
                  style: texts.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _nome,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: PayoutValidators.name,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _cognome,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Cognome'),
                  validator: PayoutValidators.name,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _codice,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                    LengthLimitingTextInputFormatter(16),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Codice fiscale',
                  ),
                  validator: PayoutValidators.fiscalCode,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _iban,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                    LengthLimitingTextInputFormatter(40),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'IBAN',
                    helperText: 'Il conto su cui vuoi ricevere i soldi',
                  ),
                  validator: PayoutValidators.iban,
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  InlineBanner(message: _error!),
                ],
                const SizedBox(height: AppSpacing.xl),
                CrasyButton(
                  label: 'Salva',
                  loading: _working,
                  onPressed: _salva,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Questi dati non compaiono da nessuna parte nell\'app e non '
                  'li vede nessun altro. Servono solo al bonifico.',
                  style: texts.bodySmall?.copyWith(color: palette.textFaint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Codici fiscali e IBAN si scrivono in maiuscolo, e correggerlo mentre si
/// scrive evita di rifiutare chi ha lasciato acceso il minuscolo.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
