class Song {
  final int id;
  final int albumId;
  final String title;
  final String artist;
  final String album;
  final String uri;
  final int? duration;
  final String? albumArt;

  Song({
    required this.id,
    required this.albumId,
    required this.title,
    required this.artist,
    required this.album,
    required this.uri,
    this.duration,
    this.albumArt,
  });

  // FIXED: Added albumId to JSON serialization
  factory Song.fromJson(Map<String, dynamic> json) => Song(
    id: json['id'],
    albumId: json['albumId'], // ADDED: This was missing
    title: json['title'],
    artist: json['artist'],
    album: json['album'],
    uri: json['uri'],
    duration: json['duration'],
    albumArt: json['albumArt'],
  );

  // FIXED: Added albumId to JSON serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'albumId': albumId, // ADDED: This was missing
    'title': title,
    'artist': artist,
    'album': album,
    'uri': uri,
    'duration': duration,
    'albumArt': albumArt,
  };
}