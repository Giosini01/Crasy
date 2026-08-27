import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/modal_sheet.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Le quattro regole del gioco, una volta sola.
///
/// ## Perche' quattro schermate e non un cartello sopra la home
///
/// I cartelli che indicano i bottoni — la freccia che dice "questo e' il
/// pulsante" — insegnano **dove sono le cose**, e non e' quello il problema di
/// chi apre CRASY per la prima volta. Il bottone si trova. Quello che non si
/// indovina sono le **regole**: che le fiamme sono tre, che le partecipazioni
/// sono cinque al giorno, che a decidere chi vince non e' il conteggio ma una
/// persona. Sono numeri, e un numero non si indica col dito.
///
/// ## E perche' una sola volta
///
/// Perche' e' un contratto, non un aiuto. Riproporlo sarebbe rubare tempo a chi
/// lo ha gia' letto; nasconderlo per sempre sarebbe una beffa per chi lo ha
/// saltato — e infatti resta raggiungibile dal profilo.
///
/// Si puo' saltare. Un tutorial che non si puo' saltare e' una porta chiusa in
/// faccia a chi ha gia' capito, e chi lo salta lo salta comunque: non leggendo.
class TutorialPage extends ConsumerStatefulWidget {
  const TutorialPage({super.key});

  @override
  ConsumerState<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends ConsumerState<TutorialPage> {
  final _pages = PageController();
  int _current = 0;
  bool _closing = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final steps = _TutorialStep.all;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.md,
                  AppSpacing.page,
                  0,
                ),
                child: Row(
                  children: [
                    const CrasyWordmark(),
                    const Spacer(),
                    // "Salta" resta grigio e piccolo: c'e' per chi lo cerca, non
                    // per invitare chi non lo stava cercando.
                    GestureDetector(
                      onTap: _finish,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Text(
                          'SALTA',
                          style: texts.labelSmall?.copyWith(
                            color: palette.textFaint,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  onPageChanged: (index) => setState(() => _current = index),
                  itemCount: steps.length,
                  itemBuilder: (context, index) =>
                      _StepView(step: steps[index]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  0,
                  AppSpacing.page,
                  AppSpacing.lg,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < steps.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _current ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _current
                                  ? palette.accent
                                  : palette.line,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CrasyButton(
                      label: _current == steps.length - 1
                          ? 'Ho capito, si comincia'
                          : 'Avanti',
                      loading: _closing,
                      onPressed: _next,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _next() {
    if (_current < _TutorialStep.all.length - 1) {
      _pages.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );

      return;
    }

    _finish();
  }

  Future<void> _finish() async {
    final authState = ref.read(authStateProvider);

    if (authState is! AuthenticatedAuthState || _closing) {
      return;
    }

    setState(() => _closing = true);

    try {
      await ref
          .read(userProfileRepositoryProvider)
          .markTutorialSeen(authState.user.id);
    } on Object {
      // **Se la scrittura non riesce, si entra lo stesso.** Il peggio che puo'
      // succedere e' rivedere quattro schermate; tenere qualcuno fuori dall'app
      // perche' non siamo riusciti a segnare che ha letto le istruzioni sarebbe
      // molto peggio.
      if (mounted) {
        setState(() => _closing = false);
      }
    }
  }
}

/// Una delle quattro cose da sapere.
class _TutorialStep {
  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.body,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Il numero grande accanto all'icona, quando la regola **e'** un numero.
  final String? badge;

  static List<_TutorialStep> get all => [
    const _TutorialStep(
      icon: Icons.local_fire_department_rounded,
      title: 'Qualcuno mette dei soldi\ne chiede una cosa',
      body:
          'Una missione e\' una richiesta con un premio in palio: "fai questo, '
          'chi lo fa meglio si prende i soldi". A metterli e\' una persona '
          'come te, non CRASY.',
    ),
    const _TutorialStep(
      icon: Icons.photo_camera_rounded,
      badge: '${Challenge.livesPerDay}',
      title: 'Partecipi con una foto\no un video',
      body:
          'Ne hai ${Challenge.livesPerDay} al giorno, e a mezzanotte tornano. '
          'Sono poche apposta: servono a farti scegliere a quali missioni tieni '
          'davvero, invece di mandare roba a caso ovunque.',
    ),
    const _TutorialStep(
      icon: Icons.whatshot_rounded,
      badge: '${Challenge.firesPerChallenge}',
      title: 'Le fiamme dicono\nquale ti piace',
      body:
          'Doppio tocco su una foto e le dai una fiamma. Ne hai '
          '${Challenge.firesPerChallenge} per ogni missione, una sola per '
          'foto — in un\'altra missione ne hai di nuovo tre.',
    ),
    const _TutorialStep(
      icon: Icons.emoji_events_rounded,
      title: 'A scegliere chi vince\ne\' chi ha messo i soldi',
      body:
          'Quando la missione finisce decide lui, entro 24 ore. Se non decide, '
          'il premio va da solo a chi ha piu\' fiamme. La foto che vince ti '
          'resta nel profilo come trofeo, con quanto ti ha fatto incassare.',
    ),
  ];
}

class _StepView extends StatelessWidget {
  const _StepView({required this.step, this.compact = false});

  final _TutorialStep step;

  /// Dentro un foglio lo spazio e' meno: si toglie il margine laterale, che li'
  /// ce l'ha gia' il foglio, e si stringe l'aria fra le righe.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : AppSpacing.page),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(step.icon, size: 44, color: palette.accent),
              if (step.badge case final numero?) ...[
                const SizedBox(width: AppSpacing.sm),
                // Il numero scritto grande accanto al simbolo. **La regola e'
                // il numero**: "hai delle fiamme" non dice niente, "ne hai tre"
                // cambia il modo in cui uno guarda le foto.
                Text(
                  numero,
                  style: texts.displaySmall?.copyWith(color: palette.accent),
                ),
              ],
            ],
          ),
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
          Text(step.title, style: texts.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Text(
            step.body,
            style: texts.bodyLarge?.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Le stesse quattro regole, rilette quando si vuole.
///
/// Il giro d'ingresso si fa una volta e si puo' saltare: senza un modo di
/// tornarci, chi lo ha saltato — o chi dopo un mese non si ricorda piu' quante
/// fiamme ha — resta senza risposta dentro l'app, e la va a cercare fuori o non
/// la cerca affatto.
Future<void> showHowItWorks(BuildContext context) {
  return ModalSheet.show<void>(
    context: context,
    builder: (sheetContext) => ModalSheet(
      title: 'COME FUNZIONA',
      confirmLabel: 'Chiudi',
      onConfirm: () => Navigator.of(sheetContext).pop(),
      child: SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.46,
        child: const _StepsCarousel(),
      ),
    ),
  );
}

class _StepsCarousel extends StatefulWidget {
  const _StepsCarousel();

  @override
  State<_StepsCarousel> createState() => _StepsCarouselState();
}

class _StepsCarouselState extends State<_StepsCarousel> {
  final _pages = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final steps = _TutorialStep.all;

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pages,
            onPageChanged: (index) => setState(() => _current = index),
            itemCount: steps.length,
            itemBuilder: (context, index) =>
                _StepView(step: steps[index], compact: true),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < steps.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _current ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _current ? palette.accent : palette.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
