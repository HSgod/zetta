enum MediaType { movie, series }

class MediaItem {
  final String id;
  final String title;
  final String? posterUrl;
  final String? description;
  final double? rating;
  final MediaType type;
  final String? releaseDate;

  const MediaItem({
    required this.id,
    required this.title,
    this.posterUrl,
    this.description,
    this.rating,
    required this.type,
    this.releaseDate,
  });

  // W przyszłości dodamy tu metodę zMap/toJson do integracji z API
}
