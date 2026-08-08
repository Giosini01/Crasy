import 'package:app_incontri/core/widgets/placeholder_page_scaffold.dart';
import 'package:app_incontri/features/auth/presentation/controllers/mock_session_controller.dart';
import 'package:app_incontri/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlaceholderPageScaffold(
      eyebrow: 'Onboarding',
      title: 'Poche scelte, una regola chiara: una sola Daily al giorno.',
      description:
          'Questa schermata prepara il flusso iniziale senza introdurre ancora '
          'logiche definitive di profilo o permessi.',
      actions: [
        ElevatedButton(
          onPressed: () {
            ref
                .read(mockSessionControllerProvider.notifier)
                .completeOnboarding();
            ref.read(goRouterProvider).go('/discover');
          },
          child: const Text('Completa onboarding'),
        ),
      ],
    );
  }
}
