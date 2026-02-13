import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/media_item.dart';
import '../../../library/presentation/providers/library_provider.dart';

class MediaCard extends ConsumerStatefulWidget {
  final MediaItem item;
  final VoidCallback? onLongPress;

  const MediaCard({
    super.key, 
    required this.item,
    this.onLongPress,
  });

  @override
  ConsumerState<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends ConsumerState<MediaCard> {
  bool _isFocused = false;
  bool _isHovered = false;

  void _showContextMenu(BuildContext context, Offset globalPosition) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final localOffset = overlay.globalToLocal(globalPosition);
    final favorites = ref.read(favoritesProvider);
    final isFavorite = favorites.any((i) => i.id == widget.item.id);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        localOffset.dx,
        localOffset.dy,
        localOffset.dx,
        localOffset.dy,
      ),
      items: [
        PopupMenuItem(
          onTap: () => context.push('/details', extra: widget.item),
          child: const ListTile(
            leading: Icon(Icons.info_outline, size: 20),
            title: Text('Szczegóły', style: TextStyle(fontSize: 14)),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuItem(
          onTap: () => ref.read(favoritesProvider.notifier).toggleFavorite(widget.item),
          child: ListTile(
            leading: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border, 
              color: isFavorite ? Colors.red : null,
              size: 20,
            ),
            title: Text(
              isFavorite ? 'Usuń z ulubionych' : 'Dodaj do ulubionych', 
              style: const TextStyle(fontSize: 14)
            ),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWindows = Platform.isWindows;
    final active = _isFocused || _isHovered;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: GestureDetector(
          onSecondaryTapDown: (details) {
            if (isWindows) {
              _showContextMenu(context, details.globalPosition);
            }
          },
          child: InkWell(
            onTap: () => context.push('/details', extra: widget.item),
            onLongPress: widget.onLongPress,
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onHover: (value) {
              if (isWindows) {
                setState(() {
                  _isHovered = value;
                });
              }
            },
            onFocusChange: (value) {
              setState(() {
                _isFocused = value;
              });
            },
            borderRadius: BorderRadius.circular(isWindows ? 16 : 28),
            child: AnimatedScale(
              scale: active ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(isWindows ? 16 : 28),
                        border: Border.all(
                          color: active 
                              ? colorScheme.primary 
                              : colorScheme.outlineVariant.withOpacity(0.5),
                          width: active ? 2 : 1,
                        ),
                        color: colorScheme.surfaceContainerHighest,
                        boxShadow: active ? [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.2),
                            blurRadius: 12,
                            spreadRadius: 1,
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
                                  cacheWidth: 300,
                                  errorBuilder: (context, error, stackTrace) => _buildPlaceholder(colorScheme),
                                )
                              : _buildPlaceholder(colorScheme),

                          if (widget.item.rating != null && widget.item.rating! > 0)
                            Positioned(
                              top: isWindows ? 8 : 12,
                              right: isWindows ? 8 : 12,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isWindows ? 6 : 10, 
                                  vertical: isWindows ? 4 : 6
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer.withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(isWindows ? 8 : 16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded, color: colorScheme.primary, size: isWindows ? 14 : 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.item.rating!.toStringAsFixed(1),
                                      style: TextStyle(
                                        color: colorScheme.onSecondaryContainer,
                                        fontSize: isWindows ? 11 : 13,
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
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (isWindows 
                              ? Theme.of(context).textTheme.bodyMedium 
                              : Theme.of(context).textTheme.titleSmall)?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.1,
                                color: active ? colorScheme.primary : null,
                              ),
                        ),
                        const SizedBox(height: 1),
                        if (widget.item.releaseDate != null && widget.item.releaseDate!.length >= 4)
                          Text(
                            widget.item.releaseDate!.substring(0, 4),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: isWindows ? 11 : null,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
