import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'permissions.dart';
import 'song_model.dart';
import 'music_audio_service.dart';
import 'player_page.dart';
import 'mini_player.dart';
import 'player_route.dart'; // ✅ Import the route

class SongListPage extends StatefulWidget {
  const SongListPage({super.key});

  @override
  State<SongListPage> createState() => _SongListPageState();
}

class _SongListPageState extends State<SongListPage> with SingleTickerProviderStateMixin {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final MusicAudioService _audioService = MusicAudioService();

  List<Song> _allSongs = [];
  List<Song> _filteredSongs = [];
  Map<String, List<Song>> _albumsMap = {};
  Map<String, List<Song>> _artistsMap = {};

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSongs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    final granted = await requestAudioPermission();
    if (!granted) {
      setState(() => _isLoading = false);
      return;
    }

    final result = await _audioQuery.querySongs(
      ignoreCase: true,
      orderType: OrderType.ASC_OR_SMALLER,
      sortType: SongSortType.TITLE,
      uriType: UriType.EXTERNAL,
    );

    final songs = result
        .where((s) {
      if (s.uri == null) return false;
      final uriLower = s.uri!.toLowerCase();
      final dataLower = s.data.toLowerCase();
      return !uriLower.contains('ringtone') &&
          !uriLower.contains('alarm') &&
          !uriLower.contains('notification') &&
          !uriLower.contains('recording') &&
          !dataLower.contains('/ringtones/') &&
          !dataLower.contains('/alarms/') &&
          !dataLower.contains('/notifications/') &&
          !dataLower.contains('/recordings/') &&
          !dataLower.contains('/call/') &&
          s.isMusic == true;
    })
        .map((s) => s.albumId == null
        ? null
        : Song(
      id: s.id,
      albumId: s.albumId!,
      title: s.title,
      artist: s.artist ?? "Unknown Artist",
      album: s.album ?? "Unknown Album",
      uri: s.uri!,
      duration: s.duration,
    ))
        .whereType<Song>()
        .toList();

    final albumsMap = <String, List<Song>>{};
    final artistsMap = <String, List<Song>>{};

    for (var song in songs) {
      albumsMap.putIfAbsent(song.album, () => []).add(song);
      artistsMap.putIfAbsent(song.artist, () => []).add(song);
    }

    setState(() {
      _allSongs = songs;
      _filteredSongs = songs;
      _albumsMap = albumsMap;
      _artistsMap = artistsMap;
      _isLoading = false;
    });
  }

  void _filterSongs(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSongs = _allSongs;
      } else {
        _filteredSongs = _allSongs.where((song) {
          return song.title.toLowerCase().contains(query.toLowerCase()) ||
              song.artist.toLowerCase().contains(query.toLowerCase()) ||
              song.album.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _playSong(Song song, List<Song> queue) {
    final index = queue.indexWhere((s) => s.id == song.id);
    _audioService.setQueue(queue, initialIndex: index);

    // ✅ Use custom slide-up route
    Navigator.of(context).push(
      slideUpPlayerRoute(const PlayerPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background_music.jpg'),
            fit: BoxFit.cover,
            onError: null,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF0f0f1e),
            ],
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    image: const DecorationImage(
                      image: AssetImage('assets/images/header_bg_music.jpg'),
                      fit: BoxFit.cover,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.purple.shade900.withOpacity(0.8),
                        Colors.blue.shade900.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const Text(
                                'My Music',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _filterSongs,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search songs, artists, albums...',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        TabBar(
                          controller: _tabController,
                          indicatorColor: Colors.white,
                          indicatorWeight: 3,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white.withOpacity(0.5),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          tabs: const [
                            Tab(text: 'Songs'),
                            Tab(text: 'Albums'),
                            Tab(text: 'Artists'),
                            Tab(text: 'Favorites'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  )
                      : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSongsList(_filteredSongs),
                      _buildAlbumsList(),
                      _buildArtistsList(),
                      _buildFavoritesList(),
                    ],
                  ),
                ),
              ],
            ),
            // FIXED: Use initialData for instant display
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: StreamBuilder<Song?>(
                stream: _audioService.currentSongStream,
                initialData: _audioService.currentSong, // ✅ INSTANT STATE
                builder: (context, snapshot) {
                  // Show if cached song exists OR stream has data
                  final hasSong = snapshot.data != null ||
                      _audioService.currentSong != null ||
                      _audioService.queue.isNotEmpty;

                  if (hasSong) {
                    return GestureDetector(
                      onTap: () {
                        // ✅ Use custom slide-up route
                        Navigator.of(context).push(
                          slideUpPlayerRoute(const PlayerPage()),
                        );
                      },
                      child: const MiniPlayer(),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongsList(List<Song> songs) {
    if (songs.isEmpty) {
      return Center(
        child: Text(
          'No songs found',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
        ),
      );
    }

    return StreamBuilder<Song?>(
      stream: _audioService.currentSongStream,
      initialData: _audioService.currentSong, // ✅ INSTANT STATE
      builder: (context, currentSongSnapshot) {
        final currentSong = currentSongSnapshot.data ?? _audioService.currentSong;

        return ListView.builder(
          padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 110),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            final isCurrentSong = currentSong?.id == song.id;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Container(
                margin: isCurrentSong
                    ? const EdgeInsets.symmetric(horizontal: 4)
                    : EdgeInsets.zero,
                decoration: BoxDecoration(
                  gradient: isCurrentSong
                      ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.purple.shade900.withOpacity(0.7),
                      Colors.purple.shade700.withOpacity(0.5),
                    ],
                  )
                      : null,
                  color: isCurrentSong ? null : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCurrentSong
                        ? Colors.purple.withOpacity(0.6)
                        : Colors.white.withOpacity(0.1),
                    width: isCurrentSong ? 2 : 1,
                  ),
                  boxShadow: isCurrentSong
                      ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: -5,
                      offset: const Offset(0, 10),
                    ),
                  ]
                      : null,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  leading: Stack(
                    children: [
                      Container(
                        decoration: isCurrentSong
                            ? BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.6),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        )
                            : null,
                        child: QueryArtworkWidget(
                          id: song.id,
                          type: ArtworkType.AUDIO,
                          artworkWidth: 52,
                          artworkHeight: 52,
                          artworkBorder: BorderRadius.circular(8),
                          nullArtworkWidget: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.purple.shade700, Colors.blue.shade700],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.music_note, color: Colors.white70),
                          ),
                        ),
                      ),
                      if (isCurrentSong)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade400,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.equalizer,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    song.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.normal,
                      fontSize: isCurrentSong ? 15 : 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    song.artist,
                    style: TextStyle(
                      color: isCurrentSong
                          ? Colors.purple.shade200
                          : Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      _audioService.isFavorite(song.id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: _audioService.isFavorite(song.id)
                          ? Colors.red.shade400
                          : Colors.white.withOpacity(0.7),
                    ),
                    onPressed: () {
                      setState(() {
                        _audioService.toggleFavorite(song.id);
                      });
                    },
                  ),
                  onTap: () => _playSong(song, songs),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAlbumsList() {
    final albums = _albumsMap.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 110),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        final firstSong = album.value.first;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: QueryArtworkWidget(
                id: firstSong.id,
                type: ArtworkType.AUDIO,
                artworkWidth: 50,
                artworkHeight: 50,
                artworkBorder: BorderRadius.circular(8),
                nullArtworkWidget: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade700, Colors.blue.shade700],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.album, color: Colors.white70),
                ),
              ),
              title: Text(
                album.key,
                style: const TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${album.value.length} songs',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
              onTap: () => _playSong(album.value.first, album.value),
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtistsList() {
    final artists = _artistsMap.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 110),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade700, Colors.blue.shade700],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.white70),
              ),
              title: Text(
                artist.key,
                style: const TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${artist.value.length} songs',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
              onTap: () => _playSong(artist.value.first, artist.value),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavoritesList() {
    final favSongs = _allSongs.where((s) => _audioService.isFavorite(s.id)).toList();

    if (favSongs.isEmpty) {
      return Center(
        child: Text(
          'No favorite songs yet',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
        ),
      );
    }

    return _buildSongsList(favSongs);
  }
}