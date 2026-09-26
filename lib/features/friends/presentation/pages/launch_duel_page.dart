import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/errors/error_message_mapper.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/utils/app_money.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/empty_state.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_source.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/challenges/presentation/controllers/create_challenge_controller.dart';
import 'package:crasy/features/challenges/presentation/controllers/duel_controller.dart';
import 'package:crasy/features/friends/domain/entities/friendship.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/friends/presentation/widgets/friend_avatar.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';
import 'package:crasy/features/payments/presentation/providers/payments_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// **Sfidare un amico: scegli chi, scrivi cosa.**
///
/// Due passaggi soli, in una schermata sola. Il modulo delle missioni normali
/// ne ha sette — premio, ambito, durata, tetto, foto o video, adesso o
/// archivio, citta' — e qui non ce n'e' nessuno da chiedere: il premio e' zero
/// per costruzione, l'ambito e' una persona, la durata e' un giorno. Chiedere
/// quelle cose vorrebbe dire trasformare un gesto di due secondi — *ti sfido a
/// fare questa roba* — in un modulo, e nessuno sfida nessuno compilando un
/// modulo.
///
/// L'unica scelta che resta e' **foto o video**, perche' cambia davvero cosa
/// si sta chiedendo di fare.
class LaunchDuelPage extends ConsumerStatefulWidget {
  const LaunchDuelPage({this.friendId, super.key});

  /// Chi sfidare, quando si arriva qui da un profilo.
  ///
  /// Con questo l'elenco degli amici non si mostra affatto: chi ha toccato
  /// "sfidalo" sul profilo di Mario ha gia' scelto, e rifargli scegliere
  /// sarebbe chiedergli due volte la stessa cosa.
  final String? friendId;

  @override
  ConsumerState<LaunchDuelPage> createState() => _LaunchDuelPageState();
}

class _LaunchDuelPageState extends ConsumerState<LaunchDuelPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _messaggio = TextEditingController();
  final _brief = TextEditingController();

  final _prize = TextEditingController();

  String? _targetId;
  String _targetName = '';
  MediaKind _mediaKind = MediaKind.photo;

  /// **Gratis finche' non si dice il contrario.** E' la strada normale di una
  /// sfida fra amici — in palio c'e' la parola data — e una scelta che parte
  /// dalla parte dei soldi metterebbe un casello davanti alla cosa piu'
  /// naturale che si fa qui dentro.
  var _gratis = true;

  String? _error;

  @override
  void initState() {
    super.initState();
    _targetId = widget.friendId;
  }

  @override
  void dispose() {
    _title.dispose();
    _messaggio.dispose();
    _brief.dispose();
    _prize.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final friends = ref.watch(myFriendsProvider).valueOrNull ?? const <Friend>[];
    final busy = ref.watch(duelControllerProvider).isLoading;

    // Il nome tiene il passo con la scelta: serve a scriverlo dentro la sfida
    // senza leggere un profilo al momento dell'invio.
    final scelto = friends.where((amico) => amico.userId == _targetId).firstOrNull;
    _targetName = scelto?.username ?? _targetName;

    return Scaffold(
      appBar: AppBar(title: const Text('Sfida un amico')),
      body: AppBackground(
        child: friends.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: EmptyState(
                  title: 'Non hai ancora amici',
                  message:
                      'Le sfide si lanciano a una persona che conosci. Cerca '
                      'qualcuno e mandagli una richiesta: appena accetta, '
                      'potrai sfidarlo.',
                ),
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.md,
                    AppSpacing.page,
                    AppSpacing.xxl,
                  ),
                  children: [
                    if (_error != null) ...[
                      InlineBanner(message: _error!),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    Text(
                      'CHI SFIDI',
                      style: texts.labelSmall?.copyWith(
                        color: palette.textFaint,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _FriendPicker(
                      friends: friends,
                      selected: _targetId,
                      onPick: (amico) => setState(() {
                        _targetId = amico.userId;
                        _targetName = amico.username;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'LA SFIDA',
                      style: texts.labelSmall?.copyWith(
                        color: palette.textFaint,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _title,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Titolo',
                        hintText: 'BALLA IN MEZZO ALLA STRADA',
                      ),
                      maxLength: ChallengeDraftValidators.titleMaxLength,
                      validator: ChallengeDraftValidators.validateTitle,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _brief,
                      decoration: const InputDecoration(
                        labelText: 'Cosa deve fare',
                        hintText: 'Scrivi la consegna in una frase.',
                      ),
                      maxLines: 3,
                      maxLength: ChallengeDraftValidators.briefMaxLength,
                      validator: ChallengeDraftValidators.validateBrief,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // **Una riga per l'amico, e una sola.**
                    //
                    // Non e' una chat: non si risponde, non resta niente dopo
                    // la sfida, non c'e' nessuna casella da aprire. E' la
                    // battuta che si fa a voce lanciando una scommessa,
                    // attaccata alla cosa a cui si riferisce.
                    TextFormField(
                      controller: _messaggio,
                      decoration: const InputDecoration(
                        labelText: 'Scrivigli qualcosa (se vuoi)',
                        hintText: 'Vediamo se ce la fai.',
                      ),
                      maxLength: 140,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MediaKindPicker(
                      selected: _mediaKind,
                      onPick: (kind) => setState(() => _mediaKind = kind),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'IL PREMIO',
                      style: texts.labelSmall?.copyWith(
                        color: palette.textFaint,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _PrizePicker(
                      gratis: _gratis,
                      onPick: (scelta) => setState(() => _gratis = scelta),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _gratis
                          ? 'Si gioca per la parola data. È la sfida normale.'
                          : 'Da un euro in su. I soldi li dai tu a chi vince, '
                                'e la sfida vale come una promessa fra voi.',
                      style: texts.bodySmall?.copyWith(
                        color: palette.textFaint,
                      ),
                    ),
                    if (!_gratis) ...[
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _prize,
                        decoration: const InputDecoration(
                          labelText: 'Premio in euro',
                          // Il suggerimento porta i centesimi apposta: e' il
                          // solo posto in cui il campo dice di accettarli.
                          hintText: '10,50',
                        ),
                        // `decimal: true` e' quello che mette la virgola sulla
                        // tastiera dell'iPhone: senza, i centesimi si possono
                        // accettare quanto si vuole — non c'e' modo di
                        // digitarli.
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        // Il punto passa insieme alla virgola perche' una
                        // tastiera in inglese offre quello, e un campo che
                        // rifiuta il tasto suggerito dalla tastiera stessa
                        // sembra rotto.
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        validator: ChallengeDraftValidators.validatePrize,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Almeno '
                        '${AppMoney.format(ChallengeDraftValidators.prizeMinCents)}.',
                        style: texts.bodySmall?.copyWith(
                          color: palette.textFaint,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    // **Le tre cose che non si scelgono, dette prima.** Sono
                    // le stesse tre che il modulo non chiede: chi non le legge
                    // qui se le chiede dopo aver mandato, ed e' tardi.
                    _Rules(
                      palette: palette,
                      texts: texts,
                      gratis: _gratis,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    CrasyButton(
                      label: 'Lancia la sfida',
                      loading: busy,
                      onPressed: busy ? null : _launch,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Fa pagare il premio della sfida appena creata.
  ///
  /// E' lo stesso giro di una missione: il foglio di Stripe dentro l'app sul
  /// telefono, la sua pagina sul sito. Torna `false` se il pagamento non e'
  /// andato — annullato, rifiutato, o mai aperto — e in quel caso la sfida
  /// resta scritta ma spenta, esattamente come una missione non pagata.
  Future<bool> _paga(String challengeId) async {
    try {
      return await ref
          .read(paymentsServiceProvider)
          .payChallenge(challengeId, returnRoute: AppRoutes.friendsActivity);
    } on Object {
      return false;
    }
  }

  Future<void> _launch() async {
    setState(() => _error = null);

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final targetId = _targetId;

    if (targetId == null || targetId.isEmpty) {
      setState(() => _error = 'Scegli chi vuoi sfidare.');

      return;
    }

    final premio = _gratis ? 0 : AppMoney.centsFrom(_prize.text) ?? 0;

    final id = await ref
        .read(duelControllerProvider.notifier)
        .challenge(
          targetUserId: targetId,
          targetUsername: _targetName,
          title: _title.text,
          brief: _brief.text,
          message: _messaggio.text,
          // Scelto GRATIS il campo non e' nemmeno a schermo: si manda zero
          // senza guardare cosa c'era scritto dentro prima di cambiare idea.
          prizeCents: premio,
          mediaKind: _mediaKind,
          // Una sfida fra amici si fa sul momento: e' il senso di sfidare
          // qualcuno. Pescare dall'archivio sarebbe rispondere con una cosa
          // che si aveva gia' in tasca.
          source: ChallengeSource.instant,
        );

    if (!mounted) {
      return;
    }

    if (id == null) {
      final errore = ref.read(duelControllerProvider).error;

      setState(
        () => _error = errore == null
            ? 'Non siamo riusciti a lanciare la sfida. Riprova.'
            : ErrorMessageMapper.map(errore),
      );

      return;
    }

    // **Una sfida con dei soldi in palio si paga, come una missione.**
    //
    // Non si pagava: la sfida nasceva con il premio dichiarato e mai
    // incassato. Sembrava funzionare — la sfida compariva, l'amico la
    // riceveva — e non funzionava affatto: quei soldi non esistevano da
    // nessuna parte, e il giorno in cui il vincitore fosse andato a
    // prenderseli non ci sarebbe stato niente da dargli.
    //
    // Da quando il database pretende che il premio sia incassato prima di
    // lasciar partecipare, il guasto si e' fatto visibile: l'amico sfidato non
    // riusciva nemmeno a mandare la foto. Era il sintomo, non la causa.
    if (paymentsEnabled && premio > 0) {
      final pagato = await _paga(id);

      if (!mounted) {
        return;
      }

      if (!pagato) {
        setState(
          () => _error =
              'La sfida è salvata ma non è ancora partita: il premio non '
              'è stato pagato. Riprova dal tuo profilo.',
        );

        return;
      }
    }

    // Si torna indietro e si apre la sfida appena nata: chi l'ha lanciata
    // vuole vederla dov'e' finita, non ritrovarsi sul modulo vuoto.
    context.pop();
    context.push(AppRoutes.challengeDetailOf(id));
  }
}

/// L'elenco degli amici, in orizzontale, con la faccia grande.
///
/// **Facce e non nomi.** Si sceglie chi sfidare guardando, non leggendo: una
/// colonna di venti nomi e' una rubrica, una fila di facce e' un gruppo di
/// amici — ed e' la seconda cosa che questa schermata deve sembrare.
class _FriendPicker extends StatelessWidget {
  const _FriendPicker({
    required this.friends,
    required this.selected,
    required this.onPick,
  });

  final List<Friend> friends;
  final String? selected;
  final void Function(Friend friend) onPick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: friends.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final amico = friends[index];
          final scelto = amico.userId == selected;

          return GestureDetector(
            onTap: () => onPick(amico),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 64,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scelto ? palette.accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: FriendAvatar(
                      userId: amico.userId,
                      username: amico.username,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    amico.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: texts.labelSmall?.copyWith(
                      color: scelto ? palette.accent : palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Foto o video: l'unica cosa che cambia davvero cosa si sta chiedendo.
class _MediaKindPicker extends StatelessWidget {
  const _MediaKindPicker({required this.selected, required this.onPick});

  final MediaKind selected;
  final void Function(MediaKind kind) onPick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Row(
      children: [
        for (final kind in MediaKind.values)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: GestureDetector(
              onTap: () => onPick(kind),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  color: kind == selected
                      ? palette.accentTint
                      : Colors.transparent,
                  border: Border.all(
                    color: kind == selected ? palette.accent : palette.line,
                  ),
                ),
                child: Text(
                  kind.isVideo ? 'VIDEO' : 'FOTO',
                  style: texts.labelSmall?.copyWith(
                    color: kind == selected
                        ? palette.accent
                        : palette.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Le regole di una sfida, scritte.
class _Rules extends StatelessWidget {
  const _Rules({
    required this.palette,
    required this.texts,
    required this.gratis,
  });

  final AppPalette palette;
  final TextTheme texts;

  /// Cambia una riga sola, ed e' quella che dice cosa c'e' in palio.
  final bool gratis;

  List<String> get _righe => [
    'La vedete solo voi due.',
    if (gratis)
      'Non c’è premio in denaro: in palio c’è la parola data.'
    else
      'Il premio lo paghi tu a chi vince: CRASY non lo trattiene e non fa da '
          'garante.',
    // **Questa riga vale il doppio da quando c’è il giudizio.** Chi
    // riceve la sfida deve sapere prima che a dire se vale sarà chi
    // gliel’ha lanciata: scoprirlo il giorno del “non vale”
    // sembra un sopruso inventato sul momento.
    'Quando manda la foto, sei tu a dire se vale.',
    'Dura 24 ore, poi scade.',
    'Non toglie nessuna delle vostre partecipazioni del giorno.',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COME FUNZIONA',
          style: texts.labelSmall?.copyWith(color: palette.textFaint),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final riga in _righe)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('—  ', style: texts.bodySmall),
                Expanded(
                  child: Text(
                    riga,
                    style: texts.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// **Gratis, o con dei soldi.** Due tasti, nessuna terza strada.
///
/// E' lo stesso paio di tasti del modulo delle missioni fra amici, e per la
/// stessa ragione: lasciato libero, un campo del premio si riempie di dieci
/// centesimi — che non sono un premio né uno scherzo, e fanno sembrare piccola
/// tutta l'app. Due tasti tolgono la domanda invece di lasciarla aperta.
class _PrizePicker extends StatelessWidget {
  const _PrizePicker({required this.gratis, required this.onPick});

  final bool gratis;
  final void Function(bool gratis) onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PrizeChoice(
          label: 'GRATIS',
          selected: gratis,
          onTap: () => onPick(true),
        ),
        const SizedBox(width: AppSpacing.sm),
        _PrizeChoice(
          label: 'CON PREMIO',
          selected: !gratis,
          onTap: () => onPick(false),
        ),
      ],
    );
  }
}

/// Un tasto della scelta, con la stessa faccia di FOTO e VIDEO qui sopra.
class _PrizeChoice extends StatelessWidget {
  const _PrizeChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          color: selected ? palette.accentTint : Colors.transparent,
          border: Border.all(
            color: selected ? palette.accent : palette.line,
          ),
        ),
        child: Text(
          label,
          style: context.texts.labelSmall?.copyWith(
            color: selected ? palette.accent : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}
