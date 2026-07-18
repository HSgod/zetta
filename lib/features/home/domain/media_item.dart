enum MediaType { movie, series }

class MediaItem {
  final String id;
  final String title;
  final String? posterUrl;
  final String? backdropUrl;
  final String? description;
  final double? rating;
  final MediaType type;
  final String? releaseDate;

  const MediaItem({
    required this.id,
    required this.title,
    this.posterUrl,
    this.backdropUrl,
    this.description,
    this.rating,
    required this.type,
    this.releaseDate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'posterUrl': posterUrl,
    'backdropUrl': backdropUrl,
    'description': description,
    'rating': rating,
    'type': type.index,
    'releaseDate': releaseDate,
  };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
    id: json['id'],
    title: json['title'],
    posterUrl: json['posterUrl'],
    backdropUrl: json['backdropUrl'],
    description: json['description'],
    rating: json['rating']?.toDouble(),
    type: MediaType.values[json['type'] ?? 0],
    releaseDate: json['releaseDate'],
  );
}
