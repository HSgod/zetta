import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/media_item.dart';

class MediaCard extends StatelessWidget {
  final MediaItem item;

  const MediaCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/details', extra: item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plakat z cieniem i zaokrągleniami
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Obrazek
                    item.posterUrl != null
                        ? Image.network(
                            item.posterUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Icon(Icons.movie_outlined, 
                                color: Theme.of(context).colorScheme.onSurfaceVariant
                              ),
                            ),
                          )
                        : Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Icon(Icons.movie_outlined, 
                              color: Theme.of(context).colorScheme.onSurfaceVariant
                            ),
                          ),

                    // Badge z oceną (na górze po prawej)
                    if (item.rating != null && item.rating! > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                item.rating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Tytuł pod spodem
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          // Rok produkcji (jeśli jest)
          if (item.releaseDate != null && item.releaseDate!.length >= 4)
            Text(
              item.releaseDate!.substring(0, 4),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
        ],
      ),
    );
  }
}
