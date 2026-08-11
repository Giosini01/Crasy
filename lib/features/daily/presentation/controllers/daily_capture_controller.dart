import 'dart:typed_data';

import 'package:app_incontri/features/auth/presentation/providers/auth_providers.dart';
import 'package:app_incontri/features/daily/domain/repositories/daily_repository.dart';
import 'package:app_incontri/features/daily/presentation/providers/daily_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dailyCaptureControllerProvider =
    AsyncNotifierProvider<DailyCaptureController, void>(
      DailyCaptureController.new,
    );

class DailyCaptureController extends AsyncNotifier<void> {
  late final DailyRepository _dailyRepository;

  @override
  void build() {
    _dailyRepository = ref.watch(dailyRepositoryProvider);
  }

  /// Pubblica lo scatto. Torna `true` solo se la Daily e' arrivata a
  /// destinazione, cosi' la schermata sa se puo' chiudersi.
  Future<bool> publish(Uint8List bytes, {String? vibe}) async {
    final authState = ref.read(authStateProvider);

    if (authState is! AuthenticatedAuthState) {
      state = AsyncError<void>(
        StateError('Sessione non valida.'),
        StackTrace.current,
      );

      return false;
    }

    // La finestra si ricontrolla qui e non solo nella UI: fra lo scatto e il
    // tocco su "Pubblica" possono passare i minuti che la chiudono.
    final access = ref.read(dailyAccessProvider);

    if (!access.canCapture) {
      state = AsyncError<void>(
        const DailyWindowClosedException(),
        StackTrace.current,
      );

      return false;
    }

    state = const AsyncLoading<void>();
    final result = await AsyncValue.guard(
      () => _dailyRepository.publishDaily(
        userId: authState.user.id,
        bytes: bytes,
        now: DateTime.now(),
        vibe: vibe,
      ),
    );

    state = result.hasError
        ? AsyncError<void>(result.error!, result.stackTrace!)
        : const AsyncData<void>(null);

    return !result.hasError;
  }
}

/// Sollevata quando la finestra si chiude, o il limite si esaurisce, fra lo
/// scatto e la pubblicazione.
class DailyWindowClosedException implements Exception {
  const DailyWindowClosedException();

  @override
  String toString() => 'DailyWindowClosedException';
}
