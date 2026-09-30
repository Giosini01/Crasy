import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **La spunta dei verificati.** Rossa come la fiamma, perche' e' CRASY a
/// dirlo: un cerchio pieno con il segno bianco dentro.
///
/// La mette solo il server — l'amministrazione, o una mancia da dieci euro in
/// su — quindi vederla vuol dire qualcosa: e' per questo che sta ovunque ci
/// sia un nome.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({this.size = 16, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.palette.accent,
        border: Border.all(color: Colors.white, width: size / 10),
      ),
      child: Icon(Icons.check_rounded, size: size * 0.7, color: Colors.white),
    );
  }
}

/// Il segno giusto accanto al nome di una persona: la fiamma per l'account
/// ufficiale, la spunta per i verificati, niente per gli altri.
class VerifiedTick extends ConsumerWidget {
  const VerifiedTick({required this.userId, this.size = 16, super.key});

  final String userId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId.isEmpty) {
      return const SizedBox.shrink();
    }

    final profilo = ref.watch(publicProfileProvider(userId)).valueOrNull;

    if (profilo == null) {
      return const SizedBox.shrink();
    }

    // L'account ufficiale ha la stessa V rossa dei verificati: e' CRASY, ed e'
    // il primo dei verificati. La fiamma resta il voto e basta.
    if (profilo.isOfficial || profilo.verificato) {
      return VerifiedBadge(size: size);
    }

    return const SizedBox.shrink();
  }
}
