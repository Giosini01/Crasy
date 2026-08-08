import 'package:flutter_riverpod/flutter_riverpod.dart';

final mockSessionControllerProvider =
    NotifierProvider<MockSessionController, MockSessionState>(
      MockSessionController.new,
    );

class MockSessionController extends Notifier<MockSessionState> {
  @override
  MockSessionState build() {
    return const MockSessionState.unauthenticated();
  }

  void setAuthenticated() {
    state = state.copyWith(isAuthenticated: true);
  }

  void completeOnboarding() {
    state = state.copyWith(isAuthenticated: true, isOnboardingComplete: true);
  }

  void reset() {
    state = const MockSessionState.unauthenticated();
  }
}

class MockSessionState {
  const MockSessionState({
    required this.isAuthenticated,
    required this.isOnboardingComplete,
  });

  const MockSessionState.unauthenticated()
    : this(isAuthenticated: false, isOnboardingComplete: false);

  final bool isAuthenticated;
  final bool isOnboardingComplete;

  MockSessionState copyWith({
    bool? isAuthenticated,
    bool? isOnboardingComplete,
  }) {
    return MockSessionState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
    );
  }
}
