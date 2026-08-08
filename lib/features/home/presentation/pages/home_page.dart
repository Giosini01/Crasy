import 'package:app_incontri/core/constants/app_routes.dart';
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
      label: 'Per Te',
      icon: Icons.auto_awesome_mosaic_outlined,
      page: DiscoverPage(),
    ),
    _HomeTab(
      route: AppRoutes.camera,
      label: 'Camera',
      icon: Icons.photo_camera_outlined,
      page: CameraPage(),
    ),
    _HomeTab(
      route: AppRoutes.matches,
      label: 'Match',
      icon: Icons.favorite_border,
      page: MatchesPage(),
    ),
    _HomeTab(
      route: AppRoutes.profile,
      label: 'Profilo',
      icon: Icons.person_outline,
      page: ProfilePage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = tabs.indexWhere((tab) => tab.route == location);
    final selectedIndex = currentIndex >= 0 ? currentIndex : 0;
    final selectedTab = tabs[selectedIndex];

    return Scaffold(
      body: selectedTab.page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          context.go(tabs[index].route);
        },
        destinations: tabs
            .map(
              (tab) =>
                  NavigationDestination(icon: Icon(tab.icon), label: tab.label),
            )
            .toList(),
      ),
    );
  }
}

class _HomeTab {
  const _HomeTab({
    required this.route,
    required this.label,
    required this.icon,
    required this.page,
  });

  final String route;
  final String label;
  final IconData icon;
  final Widget page;
}
