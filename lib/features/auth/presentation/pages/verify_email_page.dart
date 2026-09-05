import 'dart:async';

import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
import 'package:crasy/features/auth/presentation/controllers/auth_action_controller.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Conferma il tuo indirizzo.
///
/// E' un muro, non un consiglio: finche' l'email non e' confermata non si entra.
/// Con dei premi in denaro **serve un indirizzo che esista davvero** — per far
/// avere i soldi a chi vince, e per riconoscere chi torna dopo essere stato
/// allontanato. Un indirizzo inventato rende impossibili tutte e due le cose.
///
/// La conferma avviene fuori dall'app, in una pagina del browser, e nessuno
/// viene ad avvisarci: per questo c'e' un comando che va a chiedere al server
/// se nel frattempo e' successo.
class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  String? _notice;
  bool _checking = false;

  /// **Quanto dura un account non confermato.**
  ///
  /// Un'ora, e poi si butta. Non e' una punizione: e' l'unico modo di
  /// **liberare l'indirizzo**. Chi non riceve il messaggio — spam, indirizzo
  /// scritto storto, un fornitore che blocca la posta di Firebase — resta con
  /// un account che esiste e non entra, e con un indirizzo che risulta gia'
  /// usato: non puo' rifare la registrazione e non puo' fare nient'altro. E'
  /// un vicolo cieco costruito da noi, e questo lo apre.
  static const Duration _window = Duration(hours: 1);

  Timer? _orologio;

  @override
  void initState() {
    super.initState();

    // Al minuto, non al secondo: l'unica cosa che deve succedere e' che allo
    // scadere dell'ora la schermata se ne accorga da sola, senza che nessuno
    // tocchi niente.
    _orologio = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _buttaSeScaduto(),
    );

    // E subito, perche' si puo' arrivare qui riaprendo l'app il giorno dopo.
    WidgetsBinding.instance.addPostFrameCallback((_) => _buttaSeScaduto());
  }

  @override
  void dispose() {
    _orologio?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final authState = ref.watch(authStateProvider);
    final email = authState is AuthenticatedAuthState
        ? (authState.user.email ?? '')
        : '';

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
              const DisplayTitle('CONFERMA\nLA TUA EMAIL'),
              const SizedBox(height: AppSpacing.sm),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Ti abbiamo scritto a '),
                    TextSpan(text: email, style: texts.titleMedium),
                    const TextSpan(
                      text:
                          '. Apri il messaggio e tocca il link, poi torna qui.',
                    ),
                  ],
                ),
                style: texts.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              const HighlightedText(
                'Serve un indirizzo vero: è l\'unico modo per farti avere i '
                'premi che vinci.',
                highlight: 'premi che vinci',
              ),
              if (_notice != null) ...[
                const SizedBox(height: AppSpacing.md),
                InlineBanner(message: _notice!),
              ],
              const SizedBox(height: AppSpacing.xl),
              CrasyButton(
                label: 'Ho confermato',
                loading: _checking,
                onPressed: _check,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: _resend,
                child: const Text('Rimanda il messaggio'),
              ),
              // **Ricomincia, non esci.** Uscendo, l'indirizzo resta occupato
              // da un account che non entrera' mai: e' proprio la trappola da
              // cui questa schermata deve avere una via d'uscita.
              TextButton(
                onPressed: () => ref
                    .read(authActionControllerProvider.notifier)
                    .discardUnverified(),
                child: Text(
                  'Ricomincia con un altro indirizzo',
                  style: texts.titleMedium?.copyWith(color: palette.textFaint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _notice = null;
    });

    final verified = await ref
        .read(authActionControllerProvider.notifier)
        .refreshVerification();

    if (!mounted) {
      return;
    }

    setState(() {
      _checking = false;
      // Se e' confermata non si dice niente: ci pensa il router a portare
      // avanti, e un messaggio di successo su una schermata che sta gia'
      // sparendo non lo legge nessuno.
      _notice = verified
          ? null
          : 'Non risulta ancora confermata. Controlla la posta, anche fra lo '
                'spam, e riprova.';
    });
  }

  /// Se l'ora e' passata, butta l'account e riporta all'ingresso.
  Future<void> _buttaSeScaduto() async {
    final authState = ref.read(authStateProvider);

    if (authState is! AuthenticatedAuthState || authState.user.emailVerified) {
      return;
    }

    final eta = authState.user.ageAt(DateTime.now());

    // Senza sapere quando e' nato non si butta niente: nel dubbio si lascia
    // dov'e'. Buttare un account per un dato mancante e' molto peggio che
    // tenerne uno in piu'.
    if (eta == null || eta < _window) {
      return;
    }

    await ref.read(authActionControllerProvider.notifier).discardUnverified();
  }

  Future<void> _resend() async {
    await ref
        .read(authActionControllerProvider.notifier)
        .resendVerificationEmail();

    if (mounted) {
      setState(() => _notice = 'Messaggio rimandato. Controlla la posta.');
    }
  }
}
