import 'dart:async';

import 'package:crasy/core/errors/error_message_mapper.dart';
import 'package:crasy/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:crasy/features/auth/domain/entities/app_user.dart';
import 'package:crasy/features/auth/domain/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(ref.watch(firebaseAuthProvider)),
);

final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);

class AuthStateNotifier extends Notifier<AuthState> {
  StreamSubscription<AppUser?>? _subscription;

  @override
  AuthState build() {
    final repository = ref.watch(authRepositoryProvider);

    _subscription?.cancel();
    _subscription = repository.authStateChanges().listen(
      (user) {
        state = user == null
            ? const UnauthenticatedAuthState()
            : AuthenticatedAuthState(user);
      },
      onError: (Object error, StackTrace stackTrace) {
        state = ErrorAuthState(ErrorMessageMapper.map(error));
      },
    );

    ref.onDispose(() {
      _subscription?.cancel();
    });

    final currentUser = repository.currentUser;

    if (currentUser != null) {
      return AuthenticatedAuthState(currentUser);
    }

    return const UnauthenticatedAuthState();
  }
}

sealed class AuthState {
  const AuthState();
}

class LoadingAuthState extends AuthState {
  const LoadingAuthState();
}

class UnauthenticatedAuthState extends AuthState {
  const UnauthenticatedAuthState();
}

class AuthenticatedAuthState extends AuthState {
  const AuthenticatedAuthState(this.user);

  final AppUser user;
}

class ErrorAuthState extends AuthState {
  const ErrorAuthState(this.message);

  final String message;
}
