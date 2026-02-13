import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({
    required this.navigationShell,
    Key? key,
  }) : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 640) {
            return Scaffold(
              extendBody: true,
              body: navigationShell,
              bottomNavigationBar: RepaintBoundary(
                child: Container(
                  height: 60,
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavItem(context, 0, Icons.home_outlined, Icons.home_rounded),
                          _buildNavItem(context, 1, Icons.search_outlined, Icons.search_rounded),
                          _buildNavItem(context, 2, Icons.explore_outlined, Icons.explore_rounded),
                          _buildNavItem(context, 3, Icons.video_library_outlined, Icons.video_library_rounded),
                          _buildNavItem(context, 4, Icons.settings_outlined, Icons.settings_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          } else {
            return Scaffold(
              body: Row(
                children: [
                  FocusTraversalGroup(
                    child: RepaintBoundary(
                      child: NavigationRail(
                        selectedIndex: navigationShell.currentIndex,
                        onDestinationSelected: (int index) => _onTap(context, index),
                        labelType: NavigationRailLabelType.none,
                        groupAlignment: 0.0,
                        leading: Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 40,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.movie_filter_rounded,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        trailing: const SizedBox(height: 60),
                        unselectedIconTheme: IconThemeData(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          size: 32,
                        ),
                        selectedIconTheme: IconThemeData(
                          color: Theme.of(context).colorScheme.primary,
                          size: 36,
                        ),
                        destinations: const <NavigationRailDestination>[
                          NavigationRailDestination(
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home),
                            label: Text('Start'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.search_outlined),
                            selectedIcon: Icon(Icons.search),
                            label: Text('Szukaj'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.explore_outlined),
                            selectedIcon: Icon(Icons.explore),
                            label: Text('Odkrywaj'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.video_library_outlined),
                            selectedIcon: Icon(Icons.video_library),
                            label: Text('Biblioteka'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.settings_outlined),
                            selectedIcon: Icon(Icons.settings),
                            label: Text('Ustawienia'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  Expanded(child: navigationShell),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, IconData selectedIcon) {
    final isSelected = navigationShell.currentIndex == index;
    return InkWell(
      onTap: () => _onTap(context, index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Icon(
          isSelected ? selectedIcon : icon,
          size: 28,
          color: isSelected 
              ? Theme.of(context).colorScheme.primary 
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
    );
  }
}