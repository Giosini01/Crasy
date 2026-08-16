import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:crasy/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, void>(OnboardingController.new);

/// L'ingresso in CRASY: una schermata, un campo obbligatorio.
///
/// L'onboarding e' corto perche' non c'e' niente da sapere prima di far vedere
/// le challenge. Ogni domanda in piu' qui e' una persona in meno che arriva
/// alla prima partecipazione.
class OnboardingController extends AsyncNotifier<void> {
  late final UserProfileRepository _userProfileRepository;

  @override
  void build() {
    _userProfileRepository = ref.watch(userProfileRepositoryProvider);
  }

  Future<void> completeOnboarding({
    required String userId,
    required String username,
    required DateTime birthDate,
    String bio = '',
    String city = '',
  }) async {
    state = const AsyncLoading<void>();

    final profile = UserProfile(
      id: userId,
      username: username.trim().toLowerCase(),
      birthDate: birthDate,
      bio: bio.trim(),
      city: city.trim(),
      createdAt: null,
      updatedAt: null,
      onboardingCompleted: true,
    );

    state = await AsyncValue.guard(
      () => _userProfileRepository.createUserProfile(profile),
    );
  }
}
