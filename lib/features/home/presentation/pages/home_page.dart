import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/features/challenges/presentation/pages/challenges_page.dart';
import 'package:crasy/features/challenges/presentation/pages/winners_page.dart';
import 'package:crasy/features/friends/presentation/pages/friends_page.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/profile/presentation/pages/profile_page.dart';
import 'package:crasy/features/search/presentation/pages/search_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// L'impalcatura con le schede.
///
/// Cinque, e ognuna risponde a una domanda diversa: **cosa c'e' in palio**,
/// **chi conosco**, **dov'e' quella cosa che cerco**, **chi ha vinto**, **come
/// stanno andando le mie**. Creare una challenge sta nell'intestazione della
/// home, perche' e' una cosa che si fa una volta ogni tanto.
///
/// Non c'e' un feed di tutti, e non e' una mancanza: le foto degli altri stanno
/// dentro la loro challenge, che e' il posto in cui hanno un senso — li' si
/// confrontano fra loro e li' si vota. Le proprie stanno nel profilo, e da li'
/// si torna alla gara con un tocco.
///
/// ## Si cambia scheda anche col dito
///
/// Le schede stanno **una accanto all'altra**, e si passa da una all'altra
/// scorrendo, non solo toccando l'icona in fondo. E' il gesto che tutti fanno
/// gia' su tutte le app che usano, e vale piu' di quanto sembri qui dentro:
/// con il telefono in una mano sola il pollice arriva al bordo dello schermo
/// molto meglio che a un'icona in fondo a sinistra.
///
/// L'indirizzo resta la verita': scorrendo si cambia la rotta, e toccando
/// l'icona la pagina scivola fino a li'. Chi arriva da un link atterra sulla
/// scheda giusta senza animazione, che e' quello che ci si aspetta da un
/// indirizzo aperto da fuori.
class HomePage extends StatefulWidget {
  const HomePage({required this.location, super.key});

  final String location;

  static const tabs = <HomeTab>[
    HomeTab(
      route: AppRoutes.challenges,
      label: 'Challenge',
      icon: Icons.local_fire_department_outlined,
      activeIcon: Icons.local_fire_department,
      page: ChallengesPage(),
    ),
    HomeTab(
      route: AppRoutes.friends,
      label: 'Amici',
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      page: FriendsPage(),
    ),
    // La lente sta in mezzo, dove sta su tutte le app che la gente usa gia': e'
    // il posto in cui il pollice la cerca senza guardare.
    HomeTab(
      route: AppRoutes.search,
      label: 'Cerca',
      icon: Icons.search_rounded,
      activeIcon: Icons.search_rounded,
      page: SearchPage(),
    ),
    HomeTab(
      route: AppRoutes.winners,
      label: 'Vincitori',
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events,
      page: WinnersPage(),
    ),
    HomeTab(
      route: AppRoutes.profile,
      label: 'Profilo',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      page: ProfilePage(),
    ),
  ];

  static int indexOf(String location) {
    final index = tabs.indexWhere((tab) => tab.route == location);

    return index >= 0 ? index : 0;
  }

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Quanto ci mette la pagina a scivolare quando si tocca un'icona.
  ///
  /// Poco: e' un cambio di vista, non l'apertura di una pagina nuova, e
  /// un'animazione lunga qui si fa notare venti volte al giorno.
  static const _slide = Duration(milliseconds: 220);

  late int _index = HomePage.indexOf(widget.location);
  late final PageController _controller = PageController(initialPage: _index);

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final next = HomePage.indexOf(widget.location);

    if (next == _index) {
      return;
    }

    setState(() => _index = next);

    // `hasClients` non e' una precauzione inutile: l'indirizzo puo' cambiare
    // prima che la pagina sia stata disegnata la prima volta — succede con i
    // link aperti da fuori — e in quel momento il controller non ha ancora
    // niente da muovere.
    if (_controller.hasClients) {
      _controller.animateToPage(next, duration: _slide, curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSwiped(int index) {
    if (index == _index) {
      return;
    }

    setState(() => _index = index);

    // L'indirizzo segue il dito: senza, il tasto indietro del browser e i link
    // condivisi racconterebbero una storia diversa da quella che si vede.
    context.go(HomePage.tabs[index].route);
  }

  void _onTapped(int index) {
    if (index == _index) {
      return;
    }

    // Si cambia solo l'indirizzo: a muovere la pagina ci pensa
    // `didUpdateWidget`, cosi' il tocco e lo scorrimento passano per la stessa
    // strada e non possono finire disallineati.
    context.go(HomePage.tabs[index].route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScrollConfiguration(
        // Il dito e il trackpad ci arrivano da soli; il mouse no, e senza
        // questo sul computer le schede non si scorrono affatto. CRASY oggi si
        // guarda soprattutto dal browser, anche da quello di un portatile.
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: PageView(
          controller: _controller,
          onPageChanged: _onSwiped,
          // Le schede si scorrono una alla volta, come le pagine di un libro:
          // un colpo di dito lungo che ne salta tre lascia in mano il dubbio di
          // dove si e' finiti.
          physics: const PageScrollPhysics(),
          children: [for (final tab in HomePage.tabs) tab.page],
        ),
      ),
      bottomNavigationBar: _NavBar(selected: _index, onTap: _onTapped),
    );
  }
}

/// La barra in fondo: un filetto sopra, icone piccole, la scheda attiva in
/// rosso.
///
/// Niente fondo colorato e niente pillola attorno all'icona scelta: e' una
/// barra di navigazione, non un elemento da guardare.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.selected, required this.onTap});

  final int selected;
  final void Function(int index) onTap;

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
              for (var index = 0; index < HomePage.tabs.length; index++)
                Expanded(
                  child: _NavItem(
                    tab: HomePage.tabs[index],
                    active: index == selected,
                    onTap: () => onTap(index),
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

  final HomeTab tab;
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

/// Una scheda: dove porta, come si chiama, che faccia ha.
class HomeTab {
  const HomeTab({
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
