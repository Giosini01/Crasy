import 'package:app_incontri/core/theme/app_palette.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/core/utils/app_date_utils.dart';
import 'package:app_incontri/core/widgets/app_background.dart';
import 'package:app_incontri/features/chat/presentation/providers/chat_providers.dart';
import 'package:app_incontri/features/matches/domain/entities/match_person.dart';
import 'package:app_incontri/features/matches/presentation/widgets/match_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Il match aperto: l'Istantanea in grande, chi e', e la conversazione.
///
/// L'ordine non e' casuale. Prima la foto di oggi, perche' e' quello per cui
/// il match e' nato; poi la persona; e in fondo le parole. Chi apre questa
/// pagina deve ricordarsi **chi** ha davanti prima di mettersi a scrivere.
class MatchChatPage extends ConsumerStatefulWidget {
  const MatchChatPage({required this.person, super.key});

  final MatchPerson person;

  @override
  ConsumerState<MatchChatPage> createState() => _MatchChatPageState();
}

class _MatchChatPageState extends ConsumerState<MatchChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _sending) {
      return;
    }

    setState(() => _sending = true);
    _controller.clear();

    await ref.read(sendMessageProvider)(widget.person.userId, text);

    if (mounted) {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final person = widget.person;
    final me = ref.watch(currentUserIdProvider);
    final messages =
        ref.watch(chatMessagesProvider(person.userId)).valueOrNull ?? const [];

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Torna ai match',
                  ),
                  Expanded(
                    child: Text(person.name, style: context.texts.titleLarge),
                  ),
                ],
              ),
              Divider(color: palette.border, height: 0.5, thickness: 0.5),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    _PersonHeader(person: person),
                    const SizedBox(height: AppSpacing.lg),
                    // Le due righe scritte insieme al cuore aprono la
                    // conversazione: non sono messaggi salvati, sono quello
                    // che vi eravate gia' detti senza saperlo.
                    if (person.hasMessage)
                      _Bubble(
                        author: person.name,
                        text: person.message,
                        mine: false,
                      ),
                    if (person.hasMyMessage) ...[
                      if (person.hasMessage)
                        const SizedBox(height: AppSpacing.sm),
                      _Bubble(author: 'Tu', text: person.myMessage, mine: true),
                    ],
                    for (final message in messages) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _Bubble(
                        author: message.sentBy(me) ? 'Tu' : person.name,
                        text: message.text,
                        mine: message.sentBy(me),
                      ),
                    ],
                    if (!person.hasMessage &&
                        !person.hasMyMessage &&
                        messages.isEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Nessun messaggio ancora. Comincia tu.',
                        textAlign: TextAlign.center,
                        style: context.texts.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              _Composer(
                controller: _controller,
                sending: _sending,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La foto di oggi in grande, con chi e' e quanto le resta da vivere.
class _PersonHeader extends StatelessWidget {
  const _PersonHeader({required this.person});

  final MatchPerson person;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    final expiry = person.photoExpiresAt;
    final expired = person.expiredAt(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: MatchPhoto(
                person: person,
                radius: AppRadius.xl,
                // Qui il fatto si dice sotto la foto, per esteso: la fascetta
                // sull'immagine servirebbe solo a coprirla.
                showExpiredNotice: false,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text(
            expired || expiry == null
                ? 'Istantanea scaduta'
                : 'Scade tra ${AppDateUtils.shortTimeLeft(expiry, now: now)}',
            style: context.texts.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '${person.name}, ${person.age}',
          style: context.texts.headlineMedium,
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(
              Icons.place_outlined,
              size: 15,
              color: palette.textSecondary,
            ),
            const SizedBox(width: 2),
            Text(person.distanceLabel, style: context.texts.bodyMedium),
            if (person.vibeChip.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(person.vibeChip, style: context.texts.bodyMedium),
            ],
          ],
        ),
        if (person.hasIcebreaker) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(person.icebreaker, style: context.texts.bodyLarge),
        ],
      ],
    );
  }
}

/// Un messaggio della conversazione.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.author,
    required this.text,
    required this.mine,
  });

  final String author;
  final String text;

  /// La propria riga sta a destra e in viola, come in ogni conversazione.
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text('$author:', style: context.texts.labelSmall),
        const SizedBox(height: 2),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.72,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: mine ? palette.brand : palette.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Text(
              text,
              style: context.texts.bodyLarge?.copyWith(
                color: mine ? palette.onBrand : palette.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Il campo per scrivere, in fondo.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.xs,
        bottom: AppSpacing.xs + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Scrivi un messaggio...',
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Material(
            color: palette.brand,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: sending ? null : onSend,
              customBorder: const CircleBorder(),
              child: SizedBox(
                height: 48,
                width: 48,
                child: sending
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: palette.onBrand,
                        ),
                      )
                    : Icon(Icons.send_rounded, color: palette.onBrand, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
