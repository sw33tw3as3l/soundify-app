const kOrigin = 'https://soundify.easyfound.ir';

String absUrl(String? u, {String fallback = ''}) {
  if (u == null || u.isEmpty) return fallback;
  if (u.startsWith('http')) return u;
  return kOrigin + (u.startsWith('/') ? u : '/$u');
}

class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final String streamUrl;
  final int duration; // seconds
  final bool isFavorite;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.coverUrl,
    required this.streamUrl,
    required this.duration,
    required this.isFavorite,
  });

  factory Track.fromJson(Map<String, dynamic> raw) {
    final j = raw['track'] is Map ? Map<String, dynamic>.from(raw['track'] as Map) : raw;
    final id = '${j['id']}';
    var d = (j['duration'] as num?)?.toInt() ?? 0;
    if (d > 20000) d ~/= 1000; // tolerate milliseconds
    return Track(
      id: id,
      title: '${j['title'] ?? ''}',
      artist: '${j['artist'] ?? ''}',
      album: '${j['album'] ?? ''}',
      coverUrl: absUrl(j['cover_url'] as String?),
      streamUrl: absUrl(j['stream_url'] as String?, fallback: '$kOrigin/api/v1/tracks/$id/stream'),
      duration: d,
      isFavorite: j['is_favorite'] == true,
    );
  }
}

class Playlist {
  final int id;
  final String name;
  final String description;
  final bool isPublic;
  final int trackCount;

  const Playlist({
    required this.id,
    required this.name,
    required this.description,
    required this.isPublic,
    required this.trackCount,
  });

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: (j['id'] as num).toInt(),
        name: '${j['name'] ?? ''}',
        description: '${j['description'] ?? ''}',
        isPublic: j['is_public'] == true,
        trackCount: (j['track_count'] as num?)?.toInt() ?? 0,
      );
}

class UserInfo {
  final String username;
  final String email;
  final String displayName;
  final String avatarUrl;

  const UserInfo({
    required this.username,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
  });

  factory UserInfo.fromJson(Map<String, dynamic> raw) {
    final j = raw['user'] is Map ? Map<String, dynamic>.from(raw['user'] as Map) : raw;
    return UserInfo(
      username: '${j['username'] ?? ''}',
      email: '${j['email'] ?? ''}',
      displayName: '${j['display_name'] ?? ''}',
      avatarUrl: absUrl(j['avatar_url'] as String?),
    );
  }

  String get shownName => displayName.isNotEmpty ? displayName : (username.isNotEmpty ? username : email);
}
