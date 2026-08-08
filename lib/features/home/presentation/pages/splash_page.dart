import 'package:app_incontri/core/theme/app_colors.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/core/widgets/placeholder_page_scaffold.dart';
import 'package:app_incontri/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetRoute = ref.read(sessionLandingRouteProvider);
      ref.read(goRouterProvider).go(targetRoute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPageScaffold(
      eyebrow: 'Splash',
      title: 'Daily',
      description:
          'Una presenza nuova ogni giorno. Verifichiamo lo stato iniziale e '
          'instradiamo l\'utente nel flusso corretto.',
      actions: [
        Padding(
          padding: EdgeInsets.only(top: AppSpacing.sm),
          child: LinearProgressIndicator(
            minHeight: 3,
            color: AppColors.accent,
            backgroundColor: AppColors.surfaceMuted,
          ),
        ),
      ],
    );
  }
}
