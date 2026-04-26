import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../features/song_list_page.dart';
import '../features/music_audio_service.dart';
import '../features/song_model.dart';

class MusicPlayerTile extends StatefulWidget {
  final MusicAudioService audioService;

  const MusicPlayerTile({
    super.key,
    required this.audioService,
  });

  @override
  State<MusicPlayerTile> createState() => _MusicPlayerTileState();
}

class _MusicPlayerTileState extends State<MusicPlayerTile> {
  Song? _lastPlayedSong;
  bool _isLoadingLastSong = true;
  bool _hasLoadedQueue = false; // Track if queue has been loaded
  final OnAudioQuery _audioQuery = OnAudioQuery();

  @override
  void initState() {
    super.initState();
    _loadLastPlayedMetadata(); // Only load metadata, not full queue
  }

  // SIMPLIFIED: Only load the song metadata for display
  Future<void> _loadLastPlayedMetadata() async {
    try {
      debugPrint('🎵 Loading last played song metadata...');

      final lastSong = await widget.audioService.getLastPlayedSongMetadata();

      setState(() {
        _lastPlayedSong = lastSong;
        _isLoadingLastSong = false;
      });

      if (lastSong != null) {
        debugPrint('✅ Loaded last played song: ${lastSong.title}');
      } else {
        debugPrint('ℹ️ No last played song found');
      }

    } catch (e) {
      debugPrint('❌ Error loading last played metadata: $e');
      setState(() {
        _isLoadingLastSong = false;
      });
    }
  }

  // NEW: Load the full queue and restore position when user wants to play
  Future<void> _ensureQueueLoaded() async {
    // If queue is already loaded or currently playing, do nothing
    if (_hasLoadedQueue || widget.audioService.queue.isNotEmpty) {
      debugPrint('ℹ️ Queue already loaded');
      return;
    }

    debugPrint('📋 Loading full queue for playback...');

    try {
      final allSongs = await _loadAllSongs();

      if (allSongs.isEmpty) {
        debugPrint('⚠️ No songs available');
        return;
      }

      // Get last playback data
      final lastPlayback = await widget.audioService.loadLastPlayback();

      int initialIndex = 0;
      Duration seekPosition = Duration.zero;

      if (lastPlayback != null) {
        final lastSong = lastPlayback['song'] as Song;
        final position = lastPlayback['position'] as int;

        // Find the song in the loaded songs
        final songIndex = allSongs.indexWhere((s) => s.id == lastSong.id);

        if (songIndex != -1) {
          initialIndex = songIndex;
          seekPosition = Duration(milliseconds: position);
          debugPrint('✅ Found last played song at index $initialIndex with position $seekPosition');
        }
      }

      // Set the queue WITHOUT playing
      await widget.audioService.setQueue(allSongs, initialIndex: initialIndex);

      // Seek to last position
      if (seekPosition > Duration.zero) {
        await widget.audioService.seek(seekPosition);
      }

      // CRITICAL: Pause to prevent autoplay
      await widget.audioService.pause();

      _hasLoadedQueue = true;
      debugPrint('✅ Queue loaded successfully (paused)');

    } catch (e) {
      debugPrint('❌ Error loading queue: $e');
    }
  }

  Future<List<Song>> _loadAllSongs() async {
    try {
      final result = await _audioQuery.querySongs(
        ignoreCase: true,
        orderType: OrderType.ASC_OR_SMALLER,
        sortType: SongSortType.TITLE,
        uriType: UriType.EXTERNAL,
      );

      return result
          .where((s) {
        if (s.uri == null || s.albumId == null) return false;
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
          .map((s) => Song(
        id: s.id,
        albumId: s.albumId!,
        title: s.title,
        artist: s.artist ?? "Unknown Artist",
        album: s.album ?? "Unknown Album",
        uri: s.uri!,
        duration: s.duration,
      ))
          .toList();
    } catch (e) {
      debugPrint('❌ Error loading songs: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLastSong) {
      return _buildLoadingTile();
    }

    return StreamBuilder<bool>(
      stream: widget.audioService.playingStream,
      builder: (context, playingSnapshot) {
        final isPlaying = playingSnapshot.data ?? false;

        return StreamBuilder(
          stream: widget.audioService.currentSongStream,
          builder: (context, songSnapshot) {
            final currentSong = songSnapshot.data ?? widget.audioService.currentSong;
            final displaySong = currentSong ?? _lastPlayedSong;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SongListPage()),
                );
              },
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: displaySong != null
                            ? QueryArtworkWidget(
                          id: displaySong.id,
                          type: ArtworkType.AUDIO,
                          artworkFit: BoxFit.cover,
                          artworkHeight: 200,
                          artworkWidth: double.infinity,
                          artworkBorder: BorderRadius.circular(12),
                          nullArtworkWidget: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.purple.shade700,
                                  Colors.red.shade700,
                                ],
                              ),
                            ),
                          ),
                        )
                            : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.purple.shade700,
                                Colors.red.shade700,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.music_note,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const Spacer(),
                              if (!isPlaying && displaySong != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Last Played',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displaySong?.title ?? 'Music Player',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      displaySong?.artist ?? 'Tap to browse your music',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (displaySong != null)
                            _buildControlsRow(
                              isPlaying: isPlaying,
                              displaySong: displaySong,
                            ),
                          if (displaySong != null) ...[
                            const SizedBox(height: 12),
                            StreamBuilder<Duration>(
                              stream: widget.audioService.positionStream,
                              builder: (context, positionSnapshot) {
                                final position = positionSnapshot.data ?? Duration.zero;

                                return StreamBuilder<Duration?>(
                                  stream: widget.audioService.durationStream,
                                  builder: (context, durationSnapshot) {
                                    final duration = durationSnapshot.data ?? Duration.zero;
                                    final progress = duration.inMilliseconds > 0
                                        ? position.inMilliseconds / duration.inMilliseconds
                                        : 0.0;

                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: Colors.white.withOpacity(0.3),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                        minHeight: 4,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildControlsRow({
    required bool isPlaying,
    required Song displaySong,
  }) {
    const double buttonSize = 42.0;
    const double playButtonSize = 50.0;
    const double spacing = 10.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _FavoriteButton(
          audioService: widget.audioService,
          songId: displaySong.id,
          size: buttonSize,
        ),
        const SizedBox(width: spacing),
        _SkipButton(
          audioService: widget.audioService,
          ensureQueueLoaded: _ensureQueueLoaded,
          isPrevious: true,
          size: buttonSize,
        ),
        const SizedBox(width: spacing),
        _PlayPauseButton(
          audioService: widget.audioService,
          ensureQueueLoaded: _ensureQueueLoaded,
          isPlaying: isPlaying,
          size: playButtonSize,
        ),
        const SizedBox(width: spacing),
        _SkipButton(
          audioService: widget.audioService,
          ensureQueueLoaded: _ensureQueueLoaded,
          isPrevious: false,
          size: buttonSize,
        ),
        const SizedBox(width: spacing),
        _ShuffleButton(
          audioService: widget.audioService,
          ensureQueueLoaded: _ensureQueueLoaded,
          size: buttonSize,
        ),
      ],
    );
  }

  Widget _buildLoadingTile() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade700,
            Colors.red.shade700,
          ],
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}

// Favorite button - only rebuilds itself when favorite status changes
class _FavoriteButton extends StatefulWidget {
  final MusicAudioService audioService;
  final int songId;
  final double size;

  const _FavoriteButton({
    required this.audioService,
    required this.songId,
    required this.size,
  });

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.audioService.isFavorite(widget.songId);
  }

  @override
  void didUpdateWidget(_FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId) {
      _isFavorite = widget.audioService.isFavorite(widget.songId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(21),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          _isFavorite ? Icons.favorite : Icons.favorite_border,
          color: _isFavorite ? Colors.red.shade300 : Colors.white,
          size: 22,
        ),
        onPressed: () async {
          await widget.audioService.toggleFavorite(widget.songId);
          setState(() {
            _isFavorite = !_isFavorite;
          });
        },
      ),
    );
  }
}

// Play/Pause button
class _PlayPauseButton extends StatelessWidget {
  final MusicAudioService audioService;
  final Future<void> Function() ensureQueueLoaded;
  final bool isPlaying;
  final double size;

  const _PlayPauseButton({
    required this.audioService,
    required this.ensureQueueLoaded,
    required this.isPlaying,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.red.shade800,
          size: 28,
        ),
        onPressed: () async {
          if (isPlaying) {
            await audioService.pause();
          } else {
            await ensureQueueLoaded();
            await audioService.play();
          }
        },
      ),
    );
  }
}

// Skip buttons
class _SkipButton extends StatelessWidget {
  final MusicAudioService audioService;
  final Future<void> Function() ensureQueueLoaded;
  final bool isPrevious;
  final double size;

  const _SkipButton({
    required this.audioService,
    required this.ensureQueueLoaded,
    required this.isPrevious,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(21),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          isPrevious ? Icons.skip_previous : Icons.skip_next,
          color: Colors.white,
          size: 24,
        ),
        onPressed: () async {
          await ensureQueueLoaded();
          if (isPrevious) {
            await audioService.skipToPrevious();
          } else {
            await audioService.skipToNext();
          }
        },
      ),
    );
  }
}

// Shuffle button
class _ShuffleButton extends StatefulWidget {
  final MusicAudioService audioService;
  final Future<void> Function() ensureQueueLoaded;
  final double size;

  const _ShuffleButton({
    required this.audioService,
    required this.ensureQueueLoaded,
    required this.size,
  });

  @override
  State<_ShuffleButton> createState() => _ShuffleButtonState();
}

class _ShuffleButtonState extends State<_ShuffleButton> {
  late bool _isShuffle;

  @override
  void initState() {
    super.initState();
    _isShuffle = widget.audioService.isShuffle;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(21),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          _isShuffle ? Icons.shuffle_on_outlined : Icons.shuffle,
          color: Colors.white,
          size: 24,
        ),
        onPressed: () async {
          await widget.ensureQueueLoaded();

          final currentPosition = widget.audioService.handler?.player.position ?? Duration.zero;
          final wasPlaying = widget.audioService.handler?.player.playing ?? false;

          await widget.audioService.toggleShuffle();
          await widget.audioService.seek(currentPosition);

          if (wasPlaying) {
            await widget.audioService.play();
          }

          setState(() {
            _isShuffle = !_isShuffle;
          });
        },
      ),
    );
  }
}