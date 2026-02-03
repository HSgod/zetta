import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/domain/media_item.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/details/presentation/details_screen.dart';
import '../../features/player/presentation/video_player_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  initialLocation: '/',
  navigatorKey: _rootNavigatorKey,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/details',
      builder: (context, state) {
        final item = state.extra as MediaItem;
        return DetailsScreen(item: item);
      },
    ),
    GoRoute(
      path: '/player',
      builder: (context, state) {
        final item = state.extra as MediaItem;
        return VideoPlayerScreen(item: item);
      },
    ),
  ],
);
