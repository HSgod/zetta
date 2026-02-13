import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/media_item.dart';
import 'providers/search_provider.dart';
import 'widgets/media_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime? _lastPressed;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final now = DateTime.now();
        final maxDuration = const Duration(seconds: 2);
        
        if (_lastPressed == null || now.difference(_lastPressed!) > maxDuration) {
          _lastPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Naciśnij ponownie, aby wyjść'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              width: 250,
            ),
          );
          return;
        }
        
        // Jeśli kliknięto drugi raz w ciągu 2s - zamknij aplikację
        Navigator.of(context).pop();
      },
      child: Scaffold(
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            if (!isWide)
              SliverAppBar(
                floating: true,
                pinned: false,
                centerTitle: true,
                title: Image.asset(
                  'assets/images/logo.png',
                  height: 36,
                  errorBuilder: (context, error, stackTrace) => const Text('Zetta'),
                ),
              ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MediaSection(
                    title: 'Popularne filmy',
                    provider: popularMoviesProvider,
                  ),
                  _MediaSection(
                    title: 'Popularne seriale',
                    provider: popularTVProvider,
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaSection extends ConsumerWidget {
  final String title;
  final FutureProvider<List<MediaItem>> provider;

  const _MediaSection({
    required this.title,
    required this.provider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMedia = ref.watch(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        SizedBox(
          height: 280,
          child: asyncMedia.when(
            data: (items) => ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 160,
                  child: MediaCard(item: items[index]),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Błąd: $err'),
            ),
          ),
        ),
      ],
    );
  }
}
