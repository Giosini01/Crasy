import 'package:app_incontri/core/constants/app_routes.dart';
import 'package:app_incontri/core/theme/app_palette.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_shadows.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/features/camera/presentation/pages/camera_page.dart';
import 'package:app_incontri/features/discover/presentation/pages/discover_page.dart';
import 'package:app_incontri/features/matches/presentation/pages/matches_page.dart';
import 'package:app_incontri/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.location, super.key});

  final String location;

  static const tabs = <_HomeTab>[
    _HomeTab(
      route: AppRoutes.discover,
      label: 'Feed',
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome,
      page: DiscoverPage(),
    ),
    _HomeTab(
      route: AppRoutes.camera,
      label: 'Istantanea',
      icon: Icons.photo_camera_outlined,
      activeIcon: Icons.photo_camera_rounded,
      page: CameraPage(),
    ),
    _HomeTab(
      route: AppRoutes.matches,
      label: 'Match',
      icon: Icons.favorite_border_rounded,
      activeIcon: Icons.favorite_rounded,
      page: MatchesPage(),
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
    final currentIndex = tabs.indexWhere((tab) => tab.route == location);
    final selectedIndex = currentIndex >= 0 ? currentIndex : 0;

    return Scaffold(
      body: tabs[selectedIndex].page,
      bottomNavigationBar: _HomeNavBar(
        selectedIndex: selectedIndex,
        onSelected: (index) => context.go(tabs[index].route),
      ),
    );
  }
}

/// Barra di navigazione dell'app.
///
/// E' scritta a mano invece di usare `NavigationBar` per restare a tinta
/// unita: nessuna pillola colorata dietro l'icona, solo il viola sulla voce
/// attiva e il grigio su tutte le altre.
class _HomeNavBar extends StatelessWidget {
  const _HomeNavBar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // Bianca sopra il fondo biancastro, con un'ombra invece di una riga: la
    // barra sta **sopra** le schermate, e una linea la farebbe sembrare
    // incollata al bordo del contenuto.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        boxShadow: AppShadows.soft,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              for (var index = 0; index < HomePage.tabs.length; index++)
                Expanded(
                  child: _NavItem(
                    tab: HomePage.tabs[index],
                    selected: index == selectedIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _HomeTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected ? palette.brand : palette.textSecondary;

    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? tab.activeIcon : tab.icon,
                size: 24,
                color: color,
              ),
              const SizedBox(height: AppSpacing.xxs + 2),
              Text(
                tab.label,
                style: context.texts.labelSmall?.copyWith(
                  color: color,
                  letterSpacing: 0.2,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
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
