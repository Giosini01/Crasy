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
              const CrasyWordmark(size: 28),
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
              Text(
                'Serve un indirizzo vero: e\' l\'unico modo per farti avere i '
                'premi che vinci.',
                style: texts.bodySmall,
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
              TextButton(
                onPressed: () =>
                    ref.read(authActionControllerProvider.notifier).signOut(),
                child: Text(
                  'Esci',
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

  Future<void> _resend() async {
    await ref
        .read(authActionControllerProvider.notifier)
        .resendVerificationEmail();

    if (mounted) {
      setState(() => _notice = 'Messaggio rimandato. Controlla la posta.');
    }
  }
}
