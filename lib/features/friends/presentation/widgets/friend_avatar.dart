import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// La faccia di una persona in un elenco.
///
/// Legge il profilo da sola a partire dall'identificativo, e quindi **una riga
/// di elenco costa una lettura in piu'**. E' un costo che si paga volentieri:
/// un elenco di nomi e cerchi grigi non aiuta a riconoscere nessuno, e
/// riconoscere qualcuno e' l'unica cosa che quell'elenco deve fare.
///
/// Finche' la foto non arriva — o se non c'e' — restano le iniziali. Non c'e'
/// nessuna rotellina: un cerchio che gira dentro un cerchio, moltiplicato per
/// venti righe, sarebbe l'unica cosa che si vede della schermata.
class FriendAvatar extends ConsumerWidget {
  const FriendAvatar({
    required this.userId,
    required this.username,
    this.size = 40,
    super.key,
  });

  final String userId;

  /// Serve subito, per le iniziali: viaggia gia' dentro l'amicizia e dentro la
  /// richiesta, quindi c'e' prima ancora che il profilo sia stato letto.
  final String username;

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoUrl = ref
        .watch(publicProfileProvider(userId))
        .valueOrNull
        ?.photoUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        width: size,
        height: size,
        child: photoUrl == null || photoUrl.isEmpty
            ? _Initials(username: username, size: size)
            : Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _Initials(username: username, size: size),
              ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.username, required this.size});

  final String username;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final initials = username.isEmpty
        ? '?'
        : (username.length <= 2 ? username : username.substring(0, 2))
              .toUpperCase();

    return ColoredBox(
      color: palette.surfaceMuted,
      child: Center(
        child: Text(
          initials,
          style: context.texts.labelMedium?.copyWith(
            color: palette.textSecondary,
            fontSize: size / 3,
          ),
        ),
      ),
    );
  }
}
