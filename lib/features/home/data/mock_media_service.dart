import '../domain/media_item.dart';

class MockMediaService {
  static const List<MediaItem> popularMovies = [
    MediaItem(
      id: '1',
      title: 'Incepcja',
      posterUrl: 'https://image.tmdb.org/t/p/w500/edv5bs1pS9S0S6TYyy9un0R9Uu1.jpg',
      description: 'Złodziej, który kradnie tajemnice korporacyjne poprzez technologię dzielenia się snami...',
      rating: 8.8,
      type: MediaType.movie,
    ),
    MediaItem(
      id: '2',
      title: 'The Last of Us',
      posterUrl: 'https://image.tmdb.org/t/p/w500/uKvH56B29V7t68o1r76oas81g1Y.jpg',
      description: 'Po tym, jak globalna pandemia niszczy cywilizację, ocalały mężczyzna przejmuje opiekę nad 14-letnią dziewczynką...',
      rating: 8.9,
      type: MediaType.series,
    ),
    MediaItem(
      id: '3',
      title: 'Interstellar',
      posterUrl: 'https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCU6MxlSabaC.jpg',
      description: 'Grupa astronautów podróżuje przez tunel czasoprzestrzenny w poszukiwaniu nowego domu dla ludzkości.',
      rating: 8.6,
      type: MediaType.movie,
    ),
    MediaItem(
      id: '4',
      title: 'Wiedźmin',
      posterUrl: 'https://image.tmdb.org/t/p/w500/7vSna7vUORbdp967id636S1Y8Z0.jpg',
      description: 'Geralt z Rivii, zmutowany łowca potworów, szuka swojego miejsca w świecie...',
      rating: 8.2,
      type: MediaType.series,
    ),
  ];
}
