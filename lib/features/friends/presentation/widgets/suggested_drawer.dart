import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/features/friends/data/repositories/contacts_repository.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/friends/presentation/widgets/suggested_friend_row.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **Il cassetto di chi conosci, sotto i numeri del profilo.**
///
/// Una riga con una freccia in giu': si tocca e scende un pannello con le
/// facce, i nomi e il tasto rosso per chiedere l'amicizia. Si richiude con la
/// stessa freccia.
///
/// Sta chiuso finche' non lo si apre, e questo non e' solo ordine: aperto di
/// suo leggerebbe la rubrica di chiunque apra il proprio profilo, e la rubrica
/// si guarda quando qualcuno lo chiede.
class SuggestedDrawer extends ConsumerStatefulWidget {
  const SuggestedDrawer({super.key});

  @override
  ConsumerState<SuggestedDrawer> createState() => _SuggestedDrawerState();
}

class _SuggestedDrawerState extends ConsumerState<SuggestedDrawer> {
  bool _aperto = false;

  void _tocca() {
    setState(() => _aperto = !_aperto);

    // Si cerca alla prima apertura e non piu': riaprire il cassetto non deve
    // rifare il giro della rubrica, e chi ha gia' mandato le richieste non
    // deve rivedersele comparire.
    if (_aperto && ref.read(suggestedFriendsProvider).valueOrNull == null) {
      ref.read(suggestedFriendsProvider.notifier).cerca();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _tocca,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'TROVA I TUOI AMICI',
                  style: context.texts.labelSmall?.copyWith(
                    color: palette.accent,
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                // La freccia gira invece di cambiare: chi guarda capisce che
                // e' la stessa cosa, e che si richiude da dove si e' aperta.
                AnimatedRotation(
                  turns: _aperto ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: palette.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _aperto
              ? const _Pannello()
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _Pannello extends ConsumerWidget {
  const _Pannello();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final stato = ref.watch(suggestedFriendsProvider);

    Widget dentro;

    if (stato.isLoading) {
      dentro = Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: palette.accent),
        ),
      );
    } else if (stato.hasError && stato.error is ContattiNegati) {
      dentro = Text(
        'Per vedere chi conosci serve il permesso sui contatti: si accende '
        'dalle impostazioni del telefono, alla voce CRASY.',
        style: context.texts.bodySmall?.copyWith(color: palette.textFaint),
      );
    } else if (stato.hasError) {
      dentro = Text(
        'Qualcosa non ha funzionato. Riprova fra poco.',
        style: context.texts.bodySmall?.copyWith(color: palette.textFaint),
      );
    } else {
      final trovati = stato.valueOrNull ?? const [];

      dentro = trovati.isEmpty
          ? Text(
              'Nessuno dei tuoi contatti è ancora qui.',
              style: context.texts.bodySmall?.copyWith(
                color: palette.textFaint,
              ),
            )
          : Column(
              children: [
                for (final chi in trovati) SuggestedFriendRow(suggested: chi),
              ],
            );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: dentro,
    );
  }
}
