import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/media_item.dart';

class MediaCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback? onLongPress;

  const MediaCard({
    super.key, 
    required this.item,
    this.onLongPress,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => context.push('/details', extra: widget.item),
      onLongPress: widget.onLongPress,
      onFocusChange: (value) {
        setState(() {
          _isFocused = value;
        });
      },
      borderRadius: BorderRadius.circular(28),
      child: AnimatedScale(
        scale: _isFocused ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _isFocused 
                        ? colorScheme.primary 
                        : colorScheme.outlineVariant.withOpacity(0.5),
                    width: _isFocused ? 3 : 1,
                  ),
                  color: colorScheme.surfaceContainerHighest,
                  boxShadow: _isFocused ? [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    )
                  ] : [],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.item.posterUrl != null
                        ? Image.network(
                            widget.item.posterUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(colorScheme),
                          )
                        : _buildPlaceholder(colorScheme),

                    if (widget.item.rating != null && widget.item.rating! > 0)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, color: colorScheme.primary, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                widget.item.rating!.toStringAsFixed(1),
                                style: TextStyle(
                                  color: colorScheme.onSecondaryContainer,
                                  fontSize: 13,
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
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                          color: _isFocused ? colorScheme.primary : null,
                        ),
                  ),
                  const SizedBox(height: 2),
                  if (widget.item.releaseDate != null && widget.item.releaseDate!.length >= 4)
                    Text(
                      widget.item.releaseDate!.substring(0, 4),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        Icons.movie_filter_rounded, 
        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
        size: 32,
      ),
    );
  }
}
