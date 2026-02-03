class Episode {
  final int id;
  final String name;
  final String? overview;
  final String? stillPath; // Zdjęcie z odcinka
  final int episodeNumber;
  final int seasonNumber;
  final double? voteAverage;
  final String? airDate;

  const Episode({
    required this.id,
    required this.name,
    this.overview,
    this.stillPath,
    required this.episodeNumber,
    required this.seasonNumber,
    this.voteAverage,
    this.airDate,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'],
      name: json['name'] ?? 'Odcinek ${json['episode_number']}',
      overview: json['overview'],
      stillPath: json['still_path'],
      episodeNumber: json['episode_number'],
      seasonNumber: json['season_number'],
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      airDate: json['air_date'],
    );
  }
}
