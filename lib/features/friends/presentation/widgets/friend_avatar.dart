import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/friends/presentation/widgets/verified_tick.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
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
    this.fotoRiserva,
    super.key,
  });

  final String userId;

  /// Serve subito, per le iniziali: viaggia gia' dentro l'amicizia e dentro la
  /// richiesta, quindi c'e' prima ancora che il profilo sia stato letto.
  final String username;

  final double size;

  /// La foto da usare quando il profilo non ne ha una, o non c'e' un profilo.
  final String? fotoRiserva;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Senza identificativo non c'e' niente da leggere: un documento senza nome
    // su Firestore non esiste, e chiederlo fa solo un errore.
    final profilo = userId.isEmpty
        ? null
        : ref.watch(publicProfileProvider(userId)).valueOrNull;
    final photoUrl = (profilo?.photoUrl?.isNotEmpty ?? false)
        ? profilo!.photoUrl
        : fotoRiserva;

    // **La casa ha il suo segno, non delle iniziali.**
    //
    // L'account ufficiale non e' una persona: due lettere dentro un cerchio
    // grigio lo farebbero sembrare uno che non ha ancora messo la foto, cioe'
    // esattamente il contrario di quello che deve dire.
    //
    // **La fiamma e basta, non il marchio intero.** Il marchio e' una parola
    // lunga, e dentro un cerchio di due dita diventa una riga illeggibile che
    // ripete il nome scritto un centimetro piu' in la'. La fiamma da sola
    // funziona a qualunque misura, ed e' comunque il marchio: e' la meta' che
    // si riconosce.
    //
    // Sta qui e non in un file caricato: una foto si puo' perdere, si puo'
    // sostituire per sbaglio, e il giorno che succede la casa resta senza
    // faccia. E si guarda il nome, non un campo sul database — due persone non
    // possono chiamarsi allo stesso modo, quindi "l'account che si chiama
    // crasy" e' una definizione che nessuno puo' prendersi.
    final ufficiale =
        profilo?.isOfficial ??
        username.trim().toLowerCase() == UserProfile.officialUsername;

    // **La faccia della casa e' l'icona dell'app**, la stessa che si tocca
    // sul telefono. La V rossa sta accanto al nome, come per i verificati.
    if (ufficiale) {
      return CrasyAppIcon(size: size);
    }

    final foto = ClipRRect(
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

    // **La spunta sta sulla foto**, in basso a destra: cosi' c'e' in ogni
    // elenco, riga e scheda che mostra una faccia, senza doverla ricordare
    // accanto a ogni nome. Sotto i ventiquattro punti non ci sta: li' la
    // mette chi scrive il nome.
    if (profilo?.verificato != true || size < 24) {
      return foto;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          foto,
          Positioned(
            right: -1,
            bottom: -1,
            child: VerifiedBadge(size: (size * 0.36).clamp(12, 22)),
          ),
        ],
      ),
    );
  }
}

/// L'icona dell'app dentro un cerchio: la faccia dell'account ufficiale.
class CrasyAppIcon extends StatelessWidget {
  const CrasyAppIcon({this.size = 40, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: context.palette.line),
      ),
      child: ClipOval(
        child: Image.asset('assets/brand/crasy-icon.png', fit: BoxFit.cover),
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
    final nome = username.trim();

    return ColoredBox(
      color: palette.surfaceMuted,
      // **Senza nome, una sagoma. Prima c'era un punto interrogativo.**
      //
      // Un `?` dentro un cerchio grigio non dice "non sappiamo chi e'": dice
      // *questa immagine non si e' caricata*, che e' la cosa peggiore da far
      // credere su una schermata dove si guarda chi ha vinto. Capitava per
      // davvero — una gara chiusa dal server non si portava dietro il nome del
      // vincitore, e qui arrivava una stringa vuota. Il nome adesso si scrive
      // (vedi `closeChallenge`), e questa e' la rete sotto: una sagoma e' un
      // disegno voluto, non un errore.
      child: nome.isEmpty
          ? Center(
              child: Icon(
                Icons.person_rounded,
                size: size * 0.56,
                color: palette.textFaint,
              ),
            )
          : Center(
              child: Text(
                (nome.length <= 2 ? nome : nome.substring(0, 2)).toUpperCase(),
                style: context.texts.labelMedium?.copyWith(
                  color: palette.textSecondary,
                  fontSize: size / 3,
                ),
              ),
            ),
    );
  }
}
