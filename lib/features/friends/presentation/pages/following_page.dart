import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/filter_field.dart';
import 'package:crasy/features/friends/domain/entities/friendship.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/friends/presentation/widgets/friend_avatar.dart';
import 'package:crasy/features/friends/presentation/widgets/unfollow_dialog.dart';
import 'package:crasy/features/friends/presentation/widgets/verified_tick.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// **Seguiti: chi segui tu.**
///
/// L'altra meta' di Follower, e una domanda diversa: non "chi mi guarda" ma
/// "chi guardo". Ogni riga dice se quella persona ti segue anche lei — allora
/// siete amici — oppure no, e in quel caso da qui si smette di seguirla.
///
/// **Regge anche con duemila persone.** L'elenco dei nomi e' un elenco di
/// identificativi che l'app ha gia' in mano; le facce, i nomi e lo stato di
/// ogni riga si leggono solo per le righe che compaiono sullo schermo, mentre
/// si scorre. Duemila seguiti costano le letture delle dieci righe che si
/// vedono, non duemila.
class FollowingPage extends ConsumerStatefulWidget {
  const FollowingPage({super.key});

  @override
  ConsumerState<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends ConsumerState<FollowingPage> {
  String _cerca = '';

  @override
  Widget build(BuildContext context) {
    // I piu' recenti in cima: l'elenco nel profilo cresce in coda.
    final tutti = ref.watch(followedIdsProvider).reversed.toList();

    // **I nomi arrivano da un'altra parte.** Questa pagina ha in mano solo gli
    // identificativi — il nome lo legge ogni riga per conto suo, dal profilo di
    // quella persona — e con i soli identificativi non si puo' cercare per nome.
    //
    // La cartella `following` il nome ce l'ha, copiato dentro al momento in cui
    // si e' iniziato a seguire: si prende da li', senza nessuna lettura in piu'
    // perche' quell'ascolto e' gia' aperto per il contatore.
    final nomi = {
      for (final chi in ref.watch(myFollowingProvider).valueOrNull ?? const [])
        chi.userId: chi.username,
    };

    final cerca = _cerca.trim();
    final seguiti = cerca.isEmpty
        ? tutti
        : [
            for (final id in tutti)
              // **Senza nome non si tiene.** Le righe che `following` non
              // conosce sono le persone seguite prima che quella cartella
              // esistesse: il loro nome qui non c'e', quindi non si puo' dire se
              // combacia. Mentre si cerca restano fuori — tenerle dentro
              // vorrebbe dire mostrare righe che non c'entrano con quello che si
              // e' scritto, e cercare "marco" per trovarsi mezza lista e' come
              // non avere cercato.
              if (combacia(nomi[id] ?? '', cerca) &&
                  (nomi[id] ?? '').isNotEmpty)
                id,
          ];

    final cercabile = FilterField.quandoServe(tutti.length) || cerca.isNotEmpty;
    final vuotoPerLaRicerca = seguiti.isEmpty && cerca.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        // "Chi segui": nel profilo il riquadro dice SEGUI, e un titolo di pagina
        // ha bisogno del complemento che un riquadro largo un quarto di schermo
        // non si puo' permettere.
        //
        // **Il numero si conta, non si legge dal contatore.** Diceva tre mentre
        // sotto ce n'erano trenta: il contatore sul profilo e' un numero tenuto
        // dal server, e serve la' dove l'elenco non c'e' — leggere mille
        // documenti per scrivere una cifra sarebbe mille letture a ogni apertura
        // del profilo. Ma **qui l'elenco e' gia' in mano**, caricato per
        // mostrarlo: contarlo non costa niente e non puo' essere sbagliato.
        //
        // Un titolo che litiga con la lista che gli sta sotto fa sembrare rotta
        // tutta la schermata, ed e' peggio di un titolo senza numero.
        title: Text(
          seguiti.isNotEmpty ? 'Chi segui · ${seguiti.length}' : 'Chi segui',
        ),
      ),
      body: AppBackground(
        child: tutti.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: EmptyState(
                  title: 'Non segui ancora nessuno',
                  message:
                      'Segui chi conosci: vedi in quali gare sta, adesso. Se ti '
                      'segue anche lui siete amici, e potete sfidarvi.',
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  AppSpacing.xxl,
                ),
                // **Il "non ho trovato niente" e' una riga della lista.** Senza,
                // cercando un nome che non c'e' resterebbe a schermo il solo
                // campo sopra una pagina muta: e nessuno legge quel vuoto come
                // "non ho trovato", lo legge come "si e' rotto".
                itemCount:
                    (cercabile ? 1 : 0) +
                    (vuotoPerLaRicerca ? 1 : seguiti.length),
                itemBuilder: (context, index) {
                  if (cercabile) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: FilterField(
                          hint: 'Cerca fra chi segui',
                          onChanged: (valore) =>
                              setState(() => _cerca = valore),
                        ),
                      );
                    }

                    index -= 1;
                  }

                  if (vuotoPerLaRicerca) {
                    return Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Text(
                        'Nessuno con questo nome fra chi segui.',
                        style: context.texts.bodyMedium?.copyWith(
                          color: context.palette.textFaint,
                        ),
                      ),
                    );
                  }

                  return _FollowingRow(userId: seguiti[index]);
                },
              ),
      ),
    );
  }
}

/// Una persona che segui: faccia, nome, e com'e' il rapporto.
///
/// Legge il profilo e lo stato solo quando la riga e' a schermo: i provider si
/// buttano via da soli appena la riga esce, e con loro l'ascolto sul database.
class _FollowingRow extends ConsumerWidget {
  const _FollowingRow({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final nome =
        ref.watch(publicProfileProvider(userId)).valueOrNull?.username ?? '';
    final stato =
        ref.watch(friendshipStatusProvider(userId)).valueOrNull ??
        FriendshipStatus.requestSent;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          FriendAvatar(userId: userId, username: nome),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.userProfileOf(userId)),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TickedName(
                    userId: userId,
                    text: nome.isEmpty ? '' : '@$nome',
                    style: texts.titleMedium,
                  ),
                  Text(
                    stato == FriendshipStatus.friends
                        ? 'VI SEGUITE · AMICI'
                        : 'NON TI SEGUE',
                    style: texts.labelSmall?.copyWith(
                      color: stato == FriendshipStatus.friends
                          ? palette.accent
                          : palette.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Si smette anche con gli amici: li' si chiede prima conferma, perche'
          // si perde l'amicizia. Con chi non ti segue e' un tocco e basta.
          TextButton(
            onPressed: () async {
              final azioni = ref.read(friendActionsProvider);

              if (stato != FriendshipStatus.friends) {
                await azioni.cancel(userId);

                return;
              }

              if (await confermaSmettiDiSeguire(context, username: nome)) {
                await azioni.unfollowFriend(userId);
              }
            },
            child: Text(
              'Smetti',
              style: texts.titleMedium?.copyWith(color: palette.textFaint),
            ),
          ),
        ],
      ),
    );
  }
}
