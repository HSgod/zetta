import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/presentation/providers/search_provider.dart';
import '../../home/presentation/widgets/media_card.dart';
import '../../home/presentation/widgets/explore_media_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[950],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1.0,
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    onChanged: (value) => ref.read(searchQueryProvider.notifier).update(value),
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    cursorColor: Colors.red,
                    decoration: InputDecoration(
                      hintText: 'Wpisz tytuł...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 22),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white70, size: 20),
                              onPressed: () {
                                _controller.clear();
                                ref.read(searchQueryProvider.notifier).update('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: query.isEmpty
                    ? _buildEmptyState()
                    : searchResults.when(
                        data: (items) {
                          if (items.isEmpty) {
                            return const Center(
                              child: Text(
                                'Brak wyników',
                                style: TextStyle(color: Colors.white60),
                              ),
                            );
                          }
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: GridView.builder(
                              key: ValueKey(items.length),
                              padding: const EdgeInsets.all(16),
                              physics: const BouncingScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 160,
                                mainAxisSpacing: 24,
                                crossAxisSpacing: 16,
                                childAspectRatio: 0.62,
                              ),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                return ExploreMediaCard(item: items[index]);
                              },
                            ),
                          );
                        },
                        loading: () => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(color: Colors.red),
                              const SizedBox(height: 24),
                              const Text(
                                'Weryfikacja dostępności źródeł...',
                                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'To może chwilę potrwać',
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        error: (err, stack) => Center(
                          child: Text(
                            'Błąd: $err',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    const suggestions = ['Breaking Bad', 'Oppenheimer', 'Dune', 'Inception', 'The Bear'];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Wyszukaj film lub serial',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Wpisz tytuł w pole wyszukiwania powyżej',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 28),
          const Text(
            'POPULARNE',
            style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: suggestions.map((title) {
              return GestureDetector(
                onTap: () {
                  _controller.text = title;
                  ref.read(searchQueryProvider.notifier).update(title);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_rounded, color: Colors.white38, size: 16),
                      const SizedBox(width: 8),
                      Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
