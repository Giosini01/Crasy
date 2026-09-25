import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/data/repositories/contacts_repository.dart';
import 'package:crasy/features/friends/domain/entities/friendship.dart';
import 'package:crasy/features/friends/domain/entities/suggested_friend.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/friends/presentation/widgets/friend_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Gli amici.
///
/// Due blocchi e nient'altro: **chi ti ha chiesto l'amicizia** e **chi ce
/// l'hai gia'**. Le richieste stanno in cima perche' sono l'unica cosa che
/// aspetta una risposta da te; gli amici stanno sotto perche' sono un elenco da
/// consultare, non da smaltire.
///
/// Non c'e' una ricerca per nome, e non e' una dimenticanza: qui le persone si
/// incontrano guardando le foto che mandano alle challenge, non digitando un
/// nome che si dovrebbe gia' conoscere.
class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({super.key});

  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends ConsumerState<FriendsPage> {
  /// Quante richieste si vedono prima del "vedi le altre".
  ///
  /// Tre: abbastanza per accorgersi che ci sono, poche perche' gli amici
  /// restino sopra la piega dello schermo.
  static const int _initiallyShown = 3;

  int _requestsShown = _initiallyShown;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final requests =
        ref.watch(incomingRequestsProvider).valueOrNull ?? const [];
    final friends = ref.watch(myFriendsProvider).valueOrNull ?? const [];
    // Una lettura sola per tutti: chiedendo amico per amico sarebbero venti
    // richieste ogni volta che questa scheda si apre.
    final inGara = ref.watch(
      friendsInGameProvider(
        usersKey([for (final amico in friends) amico.userId]),
      ),
    );

    return Scaffold(
      // **In cima c'e' una freccia, non il marchio.**
      //
      // Il marchio sta sulle quattro schede, e vuol dire "sei a casa": qui non
      // ci si arriva scorrendo la barra in fondo, ci si entra da un numero sul
      // profilo. Una pagina in cui si e' entrati deve dire da subito **come si
      // torna indietro**, e il logo, li' sopra, quella domanda la lasciava
      // aperta.
      appBar: AppBar(leading: const BackButton(), title: const Text('Amici')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          children: [
            const HighlightedText(
              'Le persone che conosci, e cosa stanno combinando.',
              highlight: 'cosa stanno combinando',
            ),
            const SizedBox(height: AppSpacing.xl),
            if (requests.isNotEmpty) ...[
              Row(
                children: [
                  Text(
                    'TI HANNO CHIESTO',
                    style: context.texts.labelSmall?.copyWith(
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${requests.length}',
                    style: context.texts.labelSmall?.copyWith(
                      color: palette.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // **Non tutte, se sono tante.** Con cento richieste in attesa
              // l'elenco degli amici finisce due schermate piu' giu', e la
              // scheda smette di servire a quello per cui esiste. Se ne
              // vedono tre, e le altre stanno dietro un tocco.
              for (final request in requests.take(_requestsShown))
                _RequestRow(request: request),
              if (requests.length > _requestsShown) ...[
                const SizedBox(height: AppSpacing.xs),
                GestureDetector(
                  onTap: () => setState(() => _requestsShown = requests.length),
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'VEDI LE ALTRE ${requests.length - _requestsShown}',
                    style: context.texts.labelSmall?.copyWith(
                      color: palette.accent,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Divider(color: palette.line),
              const SizedBox(height: AppSpacing.lg),
            ],
            // **I suggeriti stanno sopra gli amici, non sotto.**
            //
            // Sotto un elenco di venti nomi non li vedrebbe nessuno, e sono
            // proprio la cosa che serve a chi quell'elenco ancora non ce l'ha.
            const _SuggestedFromContacts(),
            // Il titolo della sezione e' grande e rosso, non una scritta
            // grigia in punta di piedi. E' la schermata delle persone che
            // uno conosce: senza il rosso e' un elenco di nomi, con il rosso
            // e' la parte di CRASY che gli appartiene.
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // Due parole, due pesi: "I TUOI" e' la premessa, "AMICI" e'
                // la cosa. Il rosso sta sulla seconda, come il punto rosso in
                // fondo ai titoli dell'app — un accento, non una vernice.
                Text.rich(
                  TextSpan(
                    style: context.texts.headlineSmall,
                    children: [
                      const TextSpan(text: 'I TUOI '),
                      TextSpan(
                        text: 'AMICI',
                        style: TextStyle(color: palette.accent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                if (friends.isNotEmpty)
                  Text(
                    '${friends.length}',
                    style: context.texts.titleMedium?.copyWith(
                      color: palette.textFaint,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (friends.isEmpty)
              const EmptyState(
                title: 'Ancora nessun amico',
                message:
                    'Tocca il nome sotto una foto per aprire il profilo di '
                    'chi l\'ha mandata, e da li\' chiedigli l\'amicizia.',
              )
            else
              for (final friend in friends)
                _FriendRow(
                  friend: friend,
                  // **Cosa sta combinando adesso.** In cima a questa
                  // scheda c'e' scritto proprio quello, e sotto c'era
                  // un elenco di nomi: la stessa cosa che si vede nella
                  // rubrica del telefono. Questa riga e' la differenza
                  // fra una rubrica e una scheda che vale la pena
                  // aprire.
                  inGame: inGara[friend.userId],
                ),
          ],
        ),
      ),
    );
  }
}

/// Una richiesta: chi e', e le due risposte possibili.
///
/// Accetta e rifiuta stanno una accanto all'altra e hanno peso diverso — una e'
/// rossa, l'altra e' grigia. Non e' una scelta simmetrica: rifiutare non deve
/// costare un pensiero, ma nemmeno essere il gesto piu' facile per sbaglio.
class _RequestRow extends ConsumerWidget {
  const _RequestRow({required this.request});

  final FriendRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final actions = ref.read(friendActionsProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          FriendAvatar(
            userId: request.fromUserId,
            username: request.fromUsername,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  context.push(AppRoutes.userProfileOf(request.fromUserId)),
              child: Text(
                '@${request.fromUsername}',
                style: context.texts.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          TextButton(
            onPressed: () => actions.reject(request),
            child: Text(
              'No',
              style: context.texts.titleMedium?.copyWith(
                color: palette.textFaint,
              ),
            ),
          ),
          TextButton(
            onPressed: () => actions.accept(request),
            child: Text(
              'Accetta',
              style: context.texts.titleMedium?.copyWith(color: palette.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, this.inGame});

  final Friend friend;

  /// Il titolo della gara aperta a cui sta partecipando, se ce n'e' una.
  final String? inGame;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.userProfileOf(friend.userId)),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            FriendAvatar(userId: friend.userId, username: friend.username),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '@${friend.username}',
                    style: context.texts.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (inGame case final gara?) ...[
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 12,
                          color: context.palette.accent,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            'IN GARA  ·  ${gara.toUpperCase()}',
                            style: context.texts.labelSmall?.copyWith(
                              color: context.palette.accent,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.palette.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

/// **Chi hai in rubrica e sta gia' qui.**
///
/// La sezione ha tre facce e servono tutte e tre: prima di aver guardato
/// mostra un invito che dice cosa stiamo per fare, dopo aver guardato mostra
/// le persone, e se non c'e' nessuno sparisce del tutto — un riquadro che dice
/// "nessuno" a ogni apertura sarebbe un promemoria quotidiano di non avere
/// amici qui.
///
/// L'invito non e' una formalita': il permesso sui contatti la gente lo nega
/// per abitudine. Lo nega meno se sa **cosa esce dal telefono** — i numeri, non
/// i nomi — e cosa non succede a chi CRASY non ce l'ha.
class _SuggestedFromContacts extends ConsumerWidget {
  const _SuggestedFromContacts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final stato = ref.watch(suggestedFriendsProvider);
    final suggeriti = stato.valueOrNull;

    if (suggeriti != null && suggeriti.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.contact_phone_rounded, size: 14, color: palette.accent),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'DALLA TUA RUBRICA',
              style: context.texts.labelSmall?.copyWith(color: palette.accent),
            ),
            if (suggeriti != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${suggeriti.length}',
                style: context.texts.labelSmall?.copyWith(
                  color: palette.accent,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (suggeriti != null)
          for (final chi in suggeriti) _SuggestedRow(suggested: chi)
        else
          _InvitoAiContatti(stato: stato),
        const SizedBox(height: AppSpacing.lg),
        Divider(color: palette.line),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// Il riquadro che si vede prima di aver guardato la rubrica, e quando la
/// ricerca non e' andata a buon fine.
class _InvitoAiContatti extends ConsumerWidget {
  const _InvitoAiContatti({required this.stato});

  final AsyncValue<List<SuggestedFriend>?> stato;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    if (stato.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Sto guardando chi c’è…',
              style: context.texts.bodyMedium?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // **Il no non si ripete e non si rimprovera.** Chi ha negato il permesso lo
    // ha fatto apposta, e l'unico posto in cui puo' cambiare idea sono le
    // impostazioni del telefono: glielo si dice una volta, senza insistere.
    final negato = stato.hasError && stato.error is ContattiNegati;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            negato
                ? 'Non possiamo guardare la rubrica.'
                : 'Qualcuno che conosci è già qui.',
            style: context.texts.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            negato
                ? 'Il permesso è spento. Si riaccende dalle impostazioni del '
                      'telefono, alla voce CRASY.'
                : 'Confrontiamo i numeri della tua rubrica con chi si è '
                      'iscritto. Dal telefono escono solo i numeri, mai i nomi, '
                      'e di chi non ha CRASY non resta niente da nessuna parte.',
            style: context.texts.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          if (stato.hasError && !negato) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Qualcosa non ha funzionato. Riprova fra poco.',
              style: context.texts.bodySmall?.copyWith(color: palette.accent),
            ),
          ],
          if (!negato) ...[
            const SizedBox(height: AppSpacing.md),
            GestureDetector(
              onTap: () => ref.read(suggestedFriendsProvider.notifier).cerca(),
              behavior: HitTestBehavior.opaque,
              child: Text(
                'GUARDA CHI C’È',
                style: context.texts.labelSmall?.copyWith(
                  color: palette.accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Una persona trovata in rubrica: la si apre, oppure le si chiede l'amicizia
/// da qui senza aprire niente.
class _SuggestedRow extends ConsumerStatefulWidget {
  const _SuggestedRow({required this.suggested});

  final SuggestedFriend suggested;

  @override
  ConsumerState<_SuggestedRow> createState() => _SuggestedRowState();
}

class _SuggestedRowState extends ConsumerState<_SuggestedRow> {
  bool _inviata = false;

  Future<void> _chiedi() async {
    setState(() => _inviata = true);

    await ref.read(friendActionsProvider).send(widget.suggested.userId);

    if (mounted) {
      ref
          .read(suggestedFriendsProvider.notifier)
          .togli(widget.suggested.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final chi = widget.suggested;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                    '@${chi.username}',
                    style: context.texts.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (chi.displayName.isNotEmpty)
                    Text(
                      chi.displayName,
                      style: context.texts.bodySmall?.copyWith(
                        color: palette.textFaint,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: _inviata ? null : _chiedi,
            child: Text(
              _inviata ? 'Inviata' : 'Aggiungi',
              style: context.texts.titleMedium?.copyWith(
                color: _inviata ? palette.textFaint : palette.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
