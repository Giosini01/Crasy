import 'package:app_incontri/core/theme/app_colors.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/core/widgets/placeholder_page_scaffold.dart';
import 'package:app_incontri/features/auth/presentation/controllers/auth_action_controller.dart';
import 'package:app_incontri/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(currentUserProfileProvider);

    return profileState.when(
      loading: () => const PlaceholderPageScaffold(
        eyebrow: 'Profilo',
        title: 'Stiamo recuperando il tuo profilo.',
        description: 'Ancora un istante.',
      ),
      error: (_, _) => const PlaceholderPageScaffold(
        eyebrow: 'Profilo',
        title: 'Non siamo riusciti a leggere il profilo.',
        description: 'Riprova piu tardi.',
      ),
      data: (profile) {
        return PlaceholderPageScaffold(
          eyebrow: 'Profilo',
          title: profile == null ? 'Profilo non disponibile.' : profile.name,
          description: profile == null
              ? 'Completa l\'onboarding per vedere qui i tuoi dati.'
              : '${profile.city} - ${profile.gender.label} - ${profile.interestedIn.label}',
          actions: [
            ElevatedButton(
              onPressed: () {
                ref.read(authActionControllerProvider.notifier).signOut();
              },
              child: const Text('Logout'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Nessuna foto permanente, nessuna vetrina pubblica.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        );
      },
    );
  }
}
