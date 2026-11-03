import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/features/challenges/presentation/widgets/esito_missione.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// **Dove si torna dalla pagina di Stripe, sul sito, con una missione in revisione.**
///
/// Sul telefono il pagamento si chiude dentro l'app, e il foglio con questa stessa frase
/// compare subito. Dal sito si esce, si paga e si rientra: senza questa pagina chi ha appena
/// pagato si ritroverebbe davanti le gare, senza la sua e senza una parola.
class MissioneInRevisionePage extends StatelessWidget {
  const MissioneInRevisionePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AvvisoInRevisione(),
                const SizedBox(height: AppSpacing.lg),
                CrasyButton(
                  label: 'Ho capito',
                  onPressed: () => context.go(AppRoutes.challenges),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
