import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/features/friends/domain/entities/friendship.dart';
import 'package:crasy/features/friends/domain/entities/suggested_friend.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/friends/presentation/widgets/friend_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Una persona trovata in rubrica: faccia, nome, e quello che ci si puo' fare.
///
/// **Chi e' gia' amico compare lo stesso.** Prima veniva tolto, ed era
/// sbagliato in un modo che non si vedeva: con due contatti su CRASY di cui
/// uno gia' amico, la schermata diceva "nessuno" e sembrava che la ricerca non
/// avesse funzionato. Vedere scritto "TUO AMICO" accanto a una faccia nota
/// dice due cose in un colpo — che la ricerca ha funzionato, e che con quella
/// persona sei gia' a posto.
///
/// Il tasto cambia a seconda del rapporto, e questo e' il punto: proporre
/// "invia richiesta" a chi ce l'hai gia' e' un errore che si scopre premendo.
class SuggestedFriendRow extends ConsumerStatefulWidget {
  const SuggestedFriendRow({required this.suggested, super.key});

  final SuggestedFriend suggested;

  @override
  ConsumerState<SuggestedFriendRow> createState() => _SuggestedFriendRowState();
}

class _SuggestedFriendRowState extends ConsumerState<SuggestedFriendRow> {
  /// Quello che e' successo da quando la riga e' a schermo.
  ///
  /// Parte da com'era al momento della ricerca e cambia sotto le dita: il
  /// server non viene richiamato per una cosa che si sa gia'.
  SuggestedStato? _adesso;

  SuggestedStato get _stato => _adesso ?? widget.suggested.stato;

  Future<void> _chiedi() =>
      _prova(SuggestedStato.inviata, () {
        return ref.read(friendActionsProvider).send(widget.suggested.userId);
      });

  Future<void> _accetta() =>
      _prova(SuggestedStato.amico, () {
        return ref
            .read(friendActionsProvider)
            .accept(
              FriendRequest(
                fromUserId: widget.suggested.userId,
                fromUsername: widget.suggested.username,
              ),
            );
      });

  /// Il tasto cambia subito, e **torna com'era se non e' andata**. Prima
  /// restava su INVIATA anche quando la richiesta non era partita: uno
  /// aspettava una risposta che l'altro non avrebbe mai visto.
  Future<void> _prova(
    SuggestedStato dopo,
    Future<void> Function() azione,
  ) async {
    final prima = _adesso;

    setState(() => _adesso = dopo);

    try {
      await azione();
    } on Object {
      if (!mounted) {
        return;
      }

      setState(() => _adesso = prima);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non è partita. Riprova.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final chi = widget.suggested;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          FriendAvatar(userId: chi.userId, username: chi.username),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.userProfileOf(chi.userId)),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    chi.nome,
                    style: context.texts.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (chi.displayName.isNotEmpty)
                    Text(
                      '@${chi.username}',
                      style: context.texts.bodySmall?.copyWith(
                        color: palette.textFaint,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _Azione(
            stato: _stato,
            onChiedi: _chiedi,
            onAccetta: _accetta,
          ),
        ],
      ),
    );
  }
}

/// Il tasto, o la scritta al suo posto.
class _Azione extends StatelessWidget {
  const _Azione({
    required this.stato,
    required this.onChiedi,
    required this.onAccetta,
  });

  final SuggestedStato stato;
  final VoidCallback onChiedi;
  final VoidCallback onAccetta;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // **Amico e inviata non sono tasti.** Con chi sei gia' a posto non c'e'
    // niente da fare da qui, e disdire una richiesta si fa dal profilo di
    // quella persona, dove si vede tutto il rapporto: in una riga di elenco
    // un tasto che annulla e' solo un modo di sbagliarsi in fretta.
    if (stato == SuggestedStato.amico) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 14, color: palette.textFaint),
            const SizedBox(width: 3),
            Text(
              'TUO AMICO',
              style: context.texts.labelSmall?.copyWith(
                color: palette.textFaint,
              ),
            ),
          ],
        ),
      );
    }

    if (stato == SuggestedStato.inviata) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Text(
          'INVIATA',
          style: context.texts.labelSmall?.copyWith(color: palette.textFaint),
        ),
      );
    }

    final tiHaChiesto = stato == SuggestedStato.tiHaChiesto;

    return FilledButton(
      onPressed: tiHaChiesto ? onAccetta : onChiedi,
      style: FilledButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      // Chi ti ha gia' chiesto l'amicizia non va richiesto: va accettato, ed e'
      // un gesto piu' breve. Offrirgli "invia richiesta" vorrebbe dire far
      // partire una seconda richiesta al contrario e lasciare la sua senza
      // risposta.
      child: Text(tiHaChiesto ? 'Accetta' : 'Invia richiesta'),
    );
  }
}
