import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/providers/search_provider.dart';

class ScaffoldWithNavBar extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({
    required this.navigationShell,
    Key? key,
  }) : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  @override
  ConsumerState<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends ConsumerState<ScaffoldWithNavBar> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        ref.read(searchQueryProvider.notifier).update(query);
        if (query.isNotEmpty && widget.navigationShell.currentIndex != 1) {
          widget.navigationShell.goBranch(1);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.navigationShell.currentIndex != 0) {
          widget.navigationShell.goBranch(0);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 640) {
            return Scaffold(
              extendBody: true,
              body: widget.navigationShell,
              bottomNavigationBar: RepaintBoundary(
                child: SafeArea(
                  top: false,
                  child: Container(
                    height: 64,
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.red.withOpacity(0.08),
                          blurRadius: 20,
                          spreadRadius: -2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(31),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          color: Colors.black.withOpacity(0.55),
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
                ),
              ),
            );
          } else {
            return Scaffold(
              body: Row(
                children: [
                  FocusTraversalGroup(
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(color: Colors.white10)),
                        color: Colors.black,
                      ),
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: IntrinsicHeight(
                                child: NavigationRail(
                                  extended: constraints.maxWidth > 1000,
                                  selectedIndex: widget.navigationShell.currentIndex,
                                  onDestinationSelected: (int index) => _onTap(context, index),
                                  backgroundColor: Colors.transparent,
                                  labelType: constraints.maxWidth > 1000 
                                      ? NavigationRailLabelType.none 
                                      : NavigationRailLabelType.all,
                                  groupAlignment: -0.9,
                                  minExtendedWidth: 240,
                                  leading: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: Image.asset(
                                                'assets/images/logo.png',
                                                height: 28,
                                                errorBuilder: (context, error, stackTrace) => Icon(
                                                  Icons.movie_filter_rounded,
                                                  size: 28,
                                                  color: Theme.of(context).colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                            if (constraints.maxWidth > 1000) ...[
                                              const SizedBox(width: 12),
                                              const Text(
                                                'ZETTA',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.2,
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (constraints.maxWidth > 1000)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          child: SizedBox(
                                            width: 200,
                                            height: 38,
                                            child: TextField(
                                              onChanged: _onSearchChanged,
                                              style: const TextStyle(fontSize: 14),
                                              decoration: InputDecoration(
                                                hintText: 'Szukaj...',
                                                hintStyle: const TextStyle(fontSize: 13),
                                                prefixIcon: const Icon(Icons.search, size: 18),
                                                filled: true,
                                                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: BorderSide.none,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  unselectedIconTheme: const IconThemeData(
                                    color: Colors.white60,
                                    size: 22,
                                  ),
                                  selectedIconTheme: const IconThemeData(
                                    color: Colors.red,
                                    size: 24,
                                  ),
                                  unselectedLabelTextStyle: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  selectedLabelTextStyle: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
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
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: widget.navigationShell),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, IconData selectedIcon) {
    final isSelected = widget.navigationShell.currentIndex == index;
    return InkWell(
      onTap: () => _onTap(context, index),
      borderRadius: BorderRadius.circular(20),
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.red.withOpacity(0.12) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.red.withOpacity(0.25) : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Icon(
          isSelected ? selectedIcon : icon,
          size: 24,
          color: isSelected 
              ? Colors.red 
              : Colors.white.withOpacity(0.6),
        ),
      ),
    );
  }
}
