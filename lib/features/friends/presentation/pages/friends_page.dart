import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/services/share/invite_friend.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/domain/entities/friendship.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/friends/presentation/widgets/friend_avatar.dart';
import 'package:crasy/features/friends/presentation/widgets/verified_tick.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// **Follower: chi ti segue.**
///
/// **Un elenco solo.** Accanto a chi non segui ancora c'e' "Segui": toccandolo
/// diventate amici. Accanto agli amici — vi seguite gia' — niente, perche'
/// non c'e' niente da fare. Prima vengono quelli da seguire, poi gli amici,
/// ma senza titoli in mezzo: e' la stessa lista di persone che ti seguono.
///
/// **Si legge a pagine.** Con mille follower caricarli tutti ogni volta che si
/// apre questa schermata vorrebbe dire mille letture per guardarne dieci: qui
/// ne arrivano trenta alla volta, mentre si scorre. Prima tutti quelli da
/// ricambiare, poi gli amici.
///
/// Chi seguo io sta in un'altra schermata — [FollowingPage] — ed e' un'altra
/// domanda: questa e' "chi mi guarda", quella "chi guardo".
class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({super.key});

  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

/// Una riga dell'elenco: una persona, e se e' gia' un amico.
typedef _Follower = ({String userId, String username, bool amico});

class _FriendsPageState extends ConsumerState<FriendsPage> {
  static const int _pagina = 30;

  final _scorrimento = ScrollController();
  final _righe = <_Follower>[];

  DocumentSnapshot<Object?>? _dopoRichieste;
  DocumentSnapshot<Object?>? _dopoAmici;
  bool _richiesteFinite = false;
  bool _amiciFiniti = false;
  bool _caricando = false;
  Object? _errore;

  @override
  void initState() {
    super.initState();
    _scorrimento.addListener(_forseAltre);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      // **Aperto l'elenco, i follower nuovi sono visti**: il pallino rosso
      // su FOLLOWER e sulla scheda del profilo si spegne.
      ref.read(friendActionsProvider).markFollowersSeen();
      _carica();
    });
  }

  @override
  void dispose() {
    _scorrimento.dispose();
    super.dispose();
  }

  /// A meno di mezzo schermo dal fondo si chiede la pagina dopo.
  void _forseAltre() {
    final posizione = _scorrimento.position;

    if (posizione.pixels > posizione.maxScrollExtent - 600) {
      _carica();
    }
  }

  Future<void> _carica() async {
    final repository = ref.read(friendsRepositoryProvider);
    final io = ref.read(currentUserIdProvider);

    if (_caricando || _amiciFiniti || repository == null || io == null) {
      return;
    }

    setState(() {
      _caricando = true;
      _errore = null;
    });

    try {
      if (!_richiesteFinite) {
        final pagina = await repository.pageIncoming(
          io,
          dopo: _dopoRichieste,
          quanti: _pagina,
        );

        _righe.addAll([
          for (final richiesta in pagina.righe)
            (
              userId: richiesta.fromUserId,
              username: richiesta.fromUsername,
              amico: false,
            ),
        ]);
        _dopoRichieste = pagina.ultimo ?? _dopoRichieste;
        _richiesteFinite = pagina.righe.length < _pagina;
      } else {
        final pagina = await repository.pageFriends(
          io,
          dopo: _dopoAmici,
          quanti: _pagina,
        );

        _righe.addAll([
          for (final amico in pagina.righe)
            if (!_righe.any((riga) => riga.userId == amico.userId))
              (userId: amico.userId, username: amico.username, amico: true),
        ]);
        _dopoAmici = pagina.ultimo ?? _dopoAmici;
        _amiciFiniti = pagina.righe.length < _pagina;
      }
    } on Object catch (errore) {
      _errore = errore;
    }

    if (!mounted) {
      return;
    }

    setState(() => _caricando = false);

    // Una pagina corta non riempie lo schermo, e senza scorrere non arriva
    // la prossima: si chiede da soli finche' c'e' qualcosa.
    if (_errore == null && !_amiciFiniti) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _scorrimento.hasClients &&
            _scorrimento.position.maxScrollExtent < 600) {
          _carica();
        }
      });
    }
  }

  Future<void> _ricarica() async {
    setState(() {
      _righe.clear();
      _dopoRichieste = null;
      _dopoAmici = null;
      _richiesteFinite = false;
      _amiciFiniti = false;
    });

    await _carica();
  }

  Future<void> _ricambia(_Follower riga) async {
    final indice = _righe.indexOf(riga);

    setState(() {
      _righe[indice] = (
        userId: riga.userId,
        username: riga.username,
        amico: true,
      );
    });

    await ref
        .read(friendActionsProvider)
        .accept(
          FriendRequest(fromUserId: riga.userId, fromUsername: riga.username),
        );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // **Il numero solo quando ci sono tutti.**
    //
    // Prima lo leggeva dal contatore del profilo, e il contatore diceva tre
    // mentre qui sotto l'elenco ne mostrava trenta: un titolo che litiga con la
    // lista che gli sta sotto fa sembrare rotta tutta la schermata.
    //
    // Contare le righe caricate non si puo': questa pagina le prende a pagine di
    // venti, e il numero crescerebbe sotto gli occhi mentre si scorre — che e' un
    // altro modo di sembrare rotti. Quindi si conta quando non c'e' piu' niente
    // da caricare, e fino a quel momento il titolo resta senza numero.
    //
    // Un titolo senza numero non dice niente; un titolo con il numero sbagliato
    // dice una cosa falsa.
    final completo = _richiesteFinite && _amiciFiniti;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        // "Ti seguono", come il riquadro del profilo da cui si arriva qui.
        // "Follower" era la parola di un'altra app: quella del pubblico.
        title: Text(
          completo && _righe.isNotEmpty
              ? 'Ti seguono · ${_righe.length}'
              : 'Ti seguono',
        ),
        actions: [
          // **Il modo di portarne di nuovi, dove si guardano quelli che ci
          // sono.** E' la schermata in cui uno si accorge di essere solo: il
          // tasto per rimediare deve stare li', non in un menu da cercare.
          IconButton(
            onPressed: () => InviteFriend.send(
              context,
              username:
                  ref.read(currentUserProfileProvider).valueOrNull?.username ??
                  '',
            ),
            tooltip: 'Invita un amico',
            icon: Icon(Icons.person_add_alt_1_rounded, color: palette.accent),
          ),
        ],
      ),
      body: AppBackground(
        child: RefreshIndicator(
          color: palette.accent,
          onRefresh: _ricarica,
          child: ListView.builder(
            controller: _scorrimento,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.xxl,
            ),
            // Una riga in piu' in fondo: la rotellina, il vuoto o l'errore.
            itemCount: _righe.length + 1,
            itemBuilder: (context, index) {
              if (index == _righe.length) {
                if (_errore != null) {
                  return _Fondo(
                    testo:
                        'Non riusciamo a caricare. Tira giu\' per riprovare.',
                    colore: palette.accent,
                  );
                }

                if (_caricando || !_amiciFiniti) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                if (_righe.isEmpty) {
                  return const EmptyState(
                    title: 'Nessun follower, per ora',
                    message:
                        'Quando qualcuno inizia a seguirti lo trovi qui. Se lo '
                        'segui anche tu, diventate amici e potete sfidarvi.',
                  );
                }

                return const SizedBox.shrink();
              }

              final riga = _righe[index];

              return _FollowerRow(riga: riga, onSegui: () => _ricambia(riga));
            },
          ),
        ),
      ),
    );
  }
}

class _Fondo extends StatelessWidget {
  const _Fondo({required this.testo, required this.colore});

  final String testo;
  final Color colore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(
        testo,
        textAlign: TextAlign.center,
        style: context.texts.bodySmall?.copyWith(color: colore),
      ),
    );
  }
}

/// Una persona che ti segue: faccia, nome, e "Segui" se non la segui ancora.
class _FollowerRow extends StatelessWidget {
  const _FollowerRow({required this.riga, required this.onSegui});

  final _Follower riga;
  final VoidCallback onSegui;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          FriendAvatar(userId: riga.userId, username: riga.username),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.userProfileOf(riga.userId)),
              behavior: HitTestBehavior.opaque,
              child: TickedName(
                userId: riga.userId,
                text: '@${riga.username}',
                style: context.texts.titleMedium,
              ),
            ),
          ),
          // Gia' amici: niente da fare, e niente tasto.
          if (!riga.amico)
            FilledButton(
              onPressed: onSegui,
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Segui'),
            ),
        ],
      ),
    );
  }
}
