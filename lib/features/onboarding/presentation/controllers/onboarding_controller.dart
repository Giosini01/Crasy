import 'package:app_incontri/features/profile/domain/entities/coordinates.dart';
import 'package:app_incontri/features/profile/domain/entities/user_profile.dart';
import 'package:app_incontri/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:app_incontri/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, void>(OnboardingController.new);

class OnboardingController extends AsyncNotifier<void> {
  late final UserProfileRepository _userProfileRepository;

  @override
  void build() {
    _userProfileRepository = ref.watch(userProfileRepositoryProvider);
  }

  Future<void> completeOnboarding({
    required String userId,
    required String name,
    required DateTime birthDate,
    required GenderIdentity gender,
    required InterestPreference interestedIn,
    required Coordinates coordinates,
    required List<String> interests,
    required String icebreaker,
  }) async {
    state = const AsyncLoading<void>();

    final profile = UserProfile(
      id: userId,
      name: name,
      birthDate: birthDate,
      gender: gender,
      interestedIn: interestedIn,
      coordinates: coordinates,
      interests: interests,
      icebreaker: icebreaker,
      createdAt: null,
      updatedAt: null,
      onboardingCompleted: true,
    );

    state = await AsyncValue.guard(
      () => _userProfileRepository.createUserProfile(profile),
    );
  }
}
