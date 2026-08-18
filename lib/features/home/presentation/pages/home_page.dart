import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/features/challenges/presentation/pages/challenges_page.dart';
import 'package:crasy/features/challenges/presentation/pages/winners_page.dart';
import 'package:crasy/features/friends/presentation/pages/friends_page.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// L'impalcatura con le quattro schede.
///
/// Quattro, e ognuna risponde a una domanda diversa: **cosa c'e' in palio**,
/// **chi conosco**, **chi ha vinto**, **come stanno andando le mie**. Creare
/// una challenge sta nell'intestazione della home, perche' e' una cosa che si
/// fa una volta ogni tanto.
///
/// Non c'e' un feed di tutti, e non e' una mancanza: le foto degli altri stanno
/// dentro la loro challenge, che e' il posto in cui hanno un senso — li' si
/// confrontano fra loro e li' si vota. Le proprie stanno nel profilo, e da li'
/// si torna alla gara con un tocco.
class HomePage extends StatelessWidget {
  const HomePage({required this.location, super.key});

  final String location;

  static const _tabs = <_HomeTab>[
    _HomeTab(
      route: AppRoutes.challenges,
      label: 'Challenge',
      icon: Icons.local_fire_department_outlined,
      activeIcon: Icons.local_fire_department,
      page: ChallengesPage(),
    ),
    _HomeTab(
      route: AppRoutes.friends,
      label: 'Amici',
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      page: FriendsPage(),
    ),
    _HomeTab(
      route: AppRoutes.winners,
      label: 'Vincitori',
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events,
      page: WinnersPage(),
    ),
    _HomeTab(
      route: AppRoutes.profile,
      label: 'Profilo',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      page: ProfilePage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final index = _tabs.indexWhere((tab) => tab.route == location);
    final selected = index >= 0 ? index : 0;

    return Scaffold(
      body: _tabs[selected].page,
      bottomNavigationBar: _NavBar(tabs: _tabs, selected: selected),
    );
  }
}

/// La barra in fondo: un filetto sopra, icone piccole, la scheda attiva in
/// rosso.
///
/// Niente fondo colorato e niente pillola attorno all'icona scelta: e' una
/// barra di navigazione, non un elemento da guardare.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.tabs, required this.selected});

  final List<_HomeTab> tabs;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(top: BorderSide(color: palette.line, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (var index = 0; index < tabs.length; index++)
                Expanded(
                  child: _NavItem(
                    tab: tabs[index],
                    active: index == selected,
                    onTap: () => context.go(tabs[index].route),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends ConsumerWidget {
  const _NavItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final _HomeTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final color = active ? palette.accent : palette.textFaint;

    // Il numero sopra l'icona esiste per una sola scheda, ed e' quella degli
    // amici: una richiesta di amicizia e' l'unica cosa dell'app che **aspetta
    // una risposta da te**. Le challenge nuove non lo fanno — ci sono e basta —
    // e se anche loro avessero un pallino rosso non ne avrebbe piu' nessuno.
    final pending = tab.route == AppRoutes.friends
        ? (ref.watch(incomingRequestsProvider).valueOrNull?.length ?? 0)
        : 0;

    return Semantics(
      selected: active,
      button: true,
      label: pending > 0 ? '${tab.label}, $pending richieste' : tab.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconWithCount(
              icon: Icon(
                active ? tab.activeIcon : tab.icon,
                size: 22,
                color: color,
              ),
              count: pending,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              tab.label.toUpperCase(),
              style: context.texts.labelSmall?.copyWith(
                color: color,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// L'icona con il pallino rosso, quando c'e' qualcosa da guardare.
///
/// Il pallino sborda dall'icona invece di stare dentro il suo quadrato: se
/// stesse dentro, per farci stare il numero l'icona dovrebbe rimpicciolirsi, e
/// la scheda degli amici avrebbe un'icona piu' piccola delle altre tre solo
/// perche' qualcuno ti ha chiesto l'amicizia.
class _IconWithCount extends StatelessWidget {
  const _IconWithCount({required this.icon, required this.count});

  final Widget icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (count <= 0) {
      return icon;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          top: -5,
          right: -8,
          child: Container(
            constraints: const BoxConstraints(minWidth: 15),
            height: 15,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.accent,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(8),
              // Il filetto del colore del fondo stacca il pallino dall'icona
              // anche quando ci finisce sopra: senza, rosso e nero si toccano e
              // sembrano una macchia sola.
              border: Border.all(color: palette.background, width: 1.5),
            ),
            child: Text(
              // Oltre il nove il numero preciso non serve a decidere niente, e
              // un pallino largo mezza icona si', a dare fastidio.
              count > 9 ? '9+' : '$count',
              style: context.texts.labelSmall?.copyWith(
                color: palette.background,
                fontSize: 9,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeTab {
  const _HomeTab({
    required this.route,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.page,
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;
}
