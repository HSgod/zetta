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
  bool _isPressed = false;

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

    return RepaintBoundary(
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            child: InkWell(
              onTap: () => context.push('/details', extra: widget.item),
              onLongPress: widget.onLongPress,
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1,
                        ),
                        color: Colors.grey[950],
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
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8, 
                                  vertical: 4
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.item.rating!.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (widget.item.releaseDate != null && widget.item.releaseDate!.length >= 4)
                          Text(
                            widget.item.releaseDate!.substring(0, 4),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
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
        color: Colors.white.withOpacity(0.2),
        size: 32,
      ),
    );
  }
}
