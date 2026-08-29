import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/entry_comment.dart';
import 'package:crasy/features/challenges/presentation/controllers/comment_controller.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Le persone il cui nome comincia cosi'.
///
/// Sta qui e non fra i provider della ricerca perche' e' un'altra cosa: quella
/// cerca **per andare** su un profilo, questa cerca **per nominare** dentro una
/// riga che si sta scrivendo. Il taglio a due caratteri non e' un dettaglio: e'
/// una lettura su Firestore a ogni tasto, e con una lettera sola i risultati
/// sarebbero comunque troppi per essere utili.
final _tagSuggestionsProvider = FutureProvider.autoDispose
    .family<List<UserProfile>, String>((ref, prefisso) async {
      if (prefisso.length < 2) {
        return const [];
      }

      final repository = ref.watch(friendsRepositoryProvider);

      if (repository == null) {
        return const [];
      }

      return repository.searchProfiles(prefisso, limit: 6);
    });

/// Apre i commenti sotto una foto.
///
/// **Si aprono solo mentre la gara e' aperta.** Chi chiama lo sa gia' e non
/// mostra nemmeno il comando: qui non si ricontrolla, perche' una gara che si
/// chiude con il foglio gia' aperto non deve farlo sparire in faccia a chi sta
/// scrivendo. A rifiutare il commento fuori tempo ci pensano le regole.
Future<void> showEntryComments(
  BuildContext context, {
  required ChallengeEntry entry,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _CommentsSheet(entry: entry),
  );
}

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.entry});

  final ChallengeEntry entry;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _testo = TextEditingController();
  final _fuoco = FocusNode();

  /// Chi e' stato scelto dai suggerimenti, per nome.
  ///
  /// Serve al momento dell'invio: per portare al profilo di qualcuno serve il
  /// suo identificativo, e ricavarlo dal nome vorrebbe dire una ricerca in piu'
  /// per ogni `@` scritto. Qui c'e' gia', perche' l'ha portato il suggerimento
  /// nel momento in cui e' stato toccato.
  final _nominati = <String, String>{};

  bool _mandando = false;
  String? _errore;

  @override
  void dispose() {
    _testo.dispose();
    _fuoco.dispose();
    super.dispose();
  }

  /// Dov'e' il cursore, se c'e' ed e' un punto e non una selezione.
  ///
  /// Nullo anche quando cadrebbe **fuori dal testo**. Non dovrebbe succedere e
  /// ogni tanto succede — il testo e la selezione si aggiornano in due momenti
  /// diversi — e in quell'istante un `substring` fa saltare l'app in mano a chi
  /// sta scrivendo, che e' il momento peggiore possibile.
  int? get _cursore {
    final selezione = _testo.selection;

    if (!selezione.isValid || !selezione.isCollapsed) {
      return null;
    }

    final offset = selezione.baseOffset;

    if (offset < 0 || offset > _testo.text.length) {
      return null;
    }

    return offset;
  }

  /// La parola che si sta scrivendo, se comincia per `@`.
  ///
  /// Si guarda **davanti al cursore**, non in fondo alla riga: si puo' tornare
  /// indietro a correggere un nome scritto male, e in quel caso i suggerimenti
  /// devono riguardare quello, non l'ultima parola del commento.
  String? get _tagInCorso {
    final cursore = _cursore;

    if (cursore == null) {
      return null;
    }

    final prima = _testo.text.substring(0, cursore);
    final chiocciola = prima.lastIndexOf('@');

    if (chiocciola < 0) {
      return null;
    }

    final parola = prima.substring(chiocciola + 1);

    // Uno spazio chiude il nome: da li' in poi si sta scrivendo altro.
    if (parola.contains(' ') || parola.contains('\n')) {
      return null;
    }

    return parola.toLowerCase();
  }

  void _scegli(UserProfile profilo) {
    final posizione = _cursore;

    if (posizione == null) {
      return;
    }

    final prima = _testo.text.substring(0, posizione);
    final chiocciola = prima.lastIndexOf('@');

    if (chiocciola < 0) {
      return;
    }

    final dopo = _testo.text.substring(posizione);
    final nuovo = '${prima.substring(0, chiocciola)}@${profilo.username} $dopo';
    final cursore = chiocciola + profilo.username.length + 2;

    _nominati[profilo.username] = profilo.id;

    setState(() {
      _testo.value = TextEditingValue(
        text: nuovo,
        selection: TextSelection.collapsed(offset: cursore),
      );
    });
  }

  Future<void> _manda() async {
    if (_mandando) {
      return;
    }

    setState(() {
      _mandando = true;
      _errore = null;
    });

    final esito = await ref
        .read(commentSenderProvider)
        .send(
          challengeId: widget.entry.challengeId,
          entryId: widget.entry.id,
          text: _testo.text,
          challengeTitle: widget.entry.challengeTitle,
          mentions: [
            for (final voce in _nominati.entries)
              EntryMention(userId: voce.value, username: voce.key),
          ],
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _mandando = false;
      _errore = esito;
    });

    if (esito == null) {
      _testo.clear();
      _nominati.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final commenti =
        ref
            .watch(
              entryCommentsProvider((
                challengeId: widget.entry.challengeId,
                entryId: widget.entry.id,
              )),
            )
            .valueOrNull ??
        const <EntryComment>[];

    final tag = _tagInCorso;

    return Padding(
      // La tastiera spinge il foglio invece di coprirlo: senza, si scrive alla
      // cieca sotto i tasti.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Row(
                children: [
                  Text(
                    'COMMENTI',
                    style: texts.labelSmall?.copyWith(color: palette.textFaint),
                  ),
                  const Spacer(),
                  Text(
                    '${commenti.length}',
                    style: texts.labelSmall?.copyWith(color: palette.textFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: commenti.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'Ancora nessuno. Comincia tu: con la chiocciola nomini '
                        'chi vuoi, e gli arriva la notizia.',
                        textAlign: TextAlign.center,
                        style: texts.bodyMedium?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.page,
                      ),
                      itemCount: commenti.length,
                      itemBuilder: (context, index) =>
                          _CommentRow(comment: commenti[index]),
                    ),
            ),
            if (tag != null) _Suggerimenti(prefisso: tag, onPick: _scegli),
            if (_errore != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  0,
                  AppSpacing.page,
                  AppSpacing.xs,
                ),
                child: Text(
                  _errore!,
                  style: texts.bodySmall?.copyWith(color: palette.accent),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.xs,
                AppSpacing.page,
                AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _testo,
                      focusNode: _fuoco,
                      maxLength: EntryComment.maxLength,
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.done,
                      // Ogni tasto ridisegna: e' quello che fa comparire e
                      // sparire i suggerimenti mentre si scrive un nome.
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Scrivi un commento, @ per nominare',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    onPressed: _mandando ? null : _manda,
                    icon: Icon(Icons.send_rounded, color: palette.accent),
                    tooltip: 'Manda',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// I nomi proposti mentre si scrive dopo la chiocciola.
class _Suggerimenti extends ConsumerWidget {
  const _Suggerimenti({required this.prefisso, required this.onPick});

  final String prefisso;
  final void Function(UserProfile profilo) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final profili =
        ref.watch(_tagSuggestionsProvider(prefisso)).valueOrNull ??
        const <UserProfile>[];

    if (profili.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        itemCount: profili.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final profilo = profili[index];

          return GestureDetector(
            onTap: () => onPick(profilo),
            behavior: HitTestBehavior.opaque,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '@${profilo.username}',
                style: context.texts.bodySmall,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Va al profilo di qualcuno chiudendo prima il foglio dei commenti.
///
/// Il router si prende **prima** della chiusura: dopo il `pop` questo pezzo di
/// albero e' gia' smontato, e cercarci dentro il router e' il modo classico di
/// far esplodere una schermata che sembrava funzionare.
///
/// E il foglio si chiude invece di restare sotto: un profilo aperto sopra i
/// commenti lascerebbe due cose da chiudere per tornare alla foto, e la seconda
/// nessuno se l'aspetta.
void _apriProfilo(BuildContext context, String userId) {
  final router = GoRouter.of(context);

  Navigator.of(context).pop();
  router.push(AppRoutes.userProfileOf(userId));
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});

  final EntryComment comment;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final quando = comment.createdAt;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _apriProfilo(context, comment.userId),
                behavior: HitTestBehavior.opaque,
                child: Text('@${comment.authorName}', style: texts.titleMedium),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (quando != null)
                Text(
                  AppDateUtils.shortTimeAgo(quando),
                  style: texts.labelSmall?.copyWith(color: palette.textFaint),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          _CommentText(comment: comment),
        ],
      ),
    );
  }
}

/// Il testo di un commento, con i nomi in rosso e cliccabili.
///
/// E' un widget con uno stato perche' i pezzi cliccabili di un testo hanno
/// bisogno di un riconoscitore di tocchi a testa, e quei riconoscitori vanno
/// **buttati via a mano**: lasciati in giro restano attaccati al motore dei
/// gesti per sempre, e una schermata di commenti ne crea uno per ogni nome che
/// scorre sotto il dito.
class _CommentText extends StatefulWidget {
  const _CommentText({required this.comment});

  final EntryComment comment;

  @override
  State<_CommentText> createState() => _CommentTextState();
}

class _CommentTextState extends State<_CommentText> {
  final _riconoscitori = <TapGestureRecognizer>[];
  List<TextSpan> _pezzi = const [];

  /// **I pezzi si costruiscono qui e non dentro `build`.**
  ///
  /// Costruirli a ogni disegno vorrebbe dire buttare via i riconoscitori del
  /// giro precedente mentre uno di loro potrebbe avere un dito appoggiato
  /// sopra: la schermata si ridisegna a ogni commento che arriva, e un
  /// riconoscitore buttato via mentre e' in mezzo a un tocco fa saltare
  /// l'applicazione.
  ///
  /// Qui invece si rifanno solo quando cambia davvero qualcosa. `build` diventa
  /// una riga, e i riconoscitori vivono quanto il testo che rappresentano.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ricostruisci();
  }

  @override
  void didUpdateWidget(_CommentText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.comment.id != widget.comment.id ||
        oldWidget.comment.text != widget.comment.text) {
      _ricostruisci();
    }
  }

  @override
  void dispose() {
    _liberaRiconoscitori();
    super.dispose();
  }

  void _liberaRiconoscitori() {
    for (final riconoscitore in _riconoscitori) {
      riconoscitore.dispose();
    }

    _riconoscitori.clear();
  }

  void _ricostruisci() {
    final palette = context.palette;

    _liberaRiconoscitori();

    final pezzi = <TextSpan>[];
    final testo = widget.comment.text;
    final nomi = RegExp(r'@([A-Za-z0-9_.]+)');
    var da = 0;

    for (final trovato in nomi.allMatches(testo)) {
      if (trovato.start > da) {
        pezzi.add(TextSpan(text: testo.substring(da, trovato.start)));
      }

      final nome = trovato.group(1)!;
      final userId = widget.comment.userIdOf(nome);

      if (userId == null) {
        // Una chiocciola scritta a mano, senza scegliere nessuno dai
        // suggerimenti: non porta da nessuna parte, quindi resta testo. Meglio
        // di un collegamento che non apre niente.
        pezzi.add(TextSpan(text: trovato.group(0)));
      } else {
        final riconoscitore = TapGestureRecognizer()
          ..onTap = () => _apriProfilo(context, userId);

        _riconoscitori.add(riconoscitore);

        pezzi.add(
          TextSpan(
            text: trovato.group(0),
            style: TextStyle(color: palette.accent),
            recognizer: riconoscitore,
          ),
        );
      }

      da = trovato.end;
    }

    if (da < testo.length) {
      pezzi.add(TextSpan(text: testo.substring(da)));
    }

    _pezzi = pezzi;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: _pezzi),
      style: context.texts.bodyMedium,
    );
  }
}
