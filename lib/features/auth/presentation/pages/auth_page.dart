import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/core/widgets/placeholder_page_scaffold.dart';
import 'package:app_incontri/features/auth/presentation/controllers/mock_session_controller.dart';
import 'package:app_incontri/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthPage extends ConsumerWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlaceholderPageScaffold(
      eyebrow: 'Authentication',
      title: 'Accesso essenziale, poi si entra nel presente.',
      description:
          'Qui predisponiamo il punto d\'ingresso dell\'app. La login Firebase '
          'arrivera nei task successivi.',
      actions: [
        ElevatedButton(
          onPressed: () {
            ref.read(mockSessionControllerProvider.notifier).setAuthenticated();
            ref.read(goRouterProvider).go('/onboarding');
          },
          child: const Text('Mock login'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () {
            ref.read(mockSessionControllerProvider.notifier).reset();
          },
          child: const Text('Reset stato'),
        ),
      ],
    );
  }
}
