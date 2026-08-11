import 'package:app_incontri/features/auth/presentation/providers/auth_providers.dart';
import 'package:app_incontri/features/feed/presentation/providers/feed_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final feedDecisionControllerProvider =
    AsyncNotifierProvider<FeedDecisionController, void>(
      FeedDecisionController.new,
    );

class FeedDecisionController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<void> decide({
    required String targetId,
    required bool liked,
    String? message,
  }) async {
    final authState = ref.read(authStateProvider);

    if (authState is! AuthenticatedAuthState) {
      return;
    }

    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref
          .read(feedRepositoryProvider)
          .recordDecision(
            userId: authState.user.id,
            targetId: targetId,
            liked: liked,
            message: message,
          ),
    );
  }
}
