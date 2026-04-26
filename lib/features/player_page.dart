import 'package:flutter/material.dart' hide RepeatMode;
import 'package:on_audio_query/on_audio_query.dart';
import 'music_audio_service.dart';
import 'song_model.dart';
import 'dart:math';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with SingleTickerProviderStateMixin {
  final MusicAudioService _audioService = MusicAudioService();
  bool _showQueue = false;
  late PageController _pageController;

  // Cache for artwork to prevent flickering
  final Map<int, Widget> _artworkCache = {};

  // Tracks a programmatic animateToPage target so onPageChanged
  // does not call skipToIndex while the animation is in flight.
  int? _programmaticTargetPage;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _audioService.currentIndex,
      viewportFraction: 0.85,
    );

    // Preload current and adjacent artwork
    _preloadArtwork();
  }

  void _preloadArtwork() {
    final queue = _audioService.queue;
    if (queue.isEmpty) return;

    final currentIndex = _audioService.currentIndex;

    // Preload current, previous, and next artwork
    for (int i = max(0, currentIndex - 1); i <= min(queue.length - 1, currentIndex + 1); i++) {
      if (!_artworkCache.containsKey(queue[i].id)) {
        _artworkCache[queue[i].id] = _buildArtworkWidget(queue[i].id);
      }
    }
  }

  Widget _buildArtworkWidget(int songId) {
    return QueryArtworkWidget(
      id: songId,
      type: ArtworkType.AUDIO,
      artworkBorder: BorderRadius.circular(20),
      keepOldArtwork: true,
      nullArtworkWidget: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple.shade700,
              Colors.blue.shade700,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.music_note,
          size: 100,
          color: Colors.white70,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _artworkCache.clear();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Song?>(
      stream: _audioService.currentSongStream,
      builder: (context, songSnapshot) {
        final currentSong = songSnapshot.data ?? _audioService.currentSong;

        // ✅ Safer PageController sync
        if (_pageController.hasClients &&
            !_showQueue &&
            _pageController.positions.length == 1) {
          final targetIndex = _audioService.currentIndex;
          final currentPage = _pageController.page?.round() ?? targetIndex;

          if (targetIndex != currentPage) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted &&
                  _pageController.hasClients &&
                  _pageController.positions.length == 1) {
                _programmaticTargetPage = targetIndex;
                _pageController.animateToPage(
                  targetIndex,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            });
          }
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/header_background.jpg'),
                  fit: BoxFit.cover,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6a1b9a),
                    Color(0xFF8e24aa),
                  ],
                ),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                toolbarHeight: 60,
                leading: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                ),
                title: const Text(
                  'Now Playing',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: Icon(
                      _showQueue ? Icons.music_note : Icons.queue_music,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      setState(() {
                        _showQueue = !_showQueue;
                      });
                    },
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          body: Material(
            color: Colors.transparent,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/player_background.jpg'),
                  fit: BoxFit.cover,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2d1b3d),
                    Color(0xFF1a1a2e),
                  ],
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
                child: currentSong == null
                    ? const Center(
                  child: Text(
                    'No song playing',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                )
                    : _showQueue
                    ? _buildQueueView()
                    : _buildPlayerView(currentSong),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerView(Song song) {
    return SafeArea(
      child: Column(
        children: [
          Flexible(child: SizedBox(height: 80)),
          Flexible(
            flex: 4,
            child: SizedBox(
              height: 320,
              child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                final isProgrammatic = _programmaticTargetPage != null;
                if (index == _programmaticTargetPage) {
                  _programmaticTargetPage = null;
                }
                if (!isProgrammatic && index != _audioService.currentIndex) {
                  _audioService.skipToIndex(index);
                }
                _preloadArtwork();
              },
              itemCount: _audioService.queue.length,
              itemBuilder: (context, index) {
                final song = _audioService.queue[index];
                final isCurrentPage = index == _audioService.currentIndex;

                if (!_artworkCache.containsKey(song.id)) {
                  _artworkCache[song.id] = _buildArtworkWidget(song.id);
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final maxSize = constraints.maxHeight;
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double value = 1.0;
                        if (_pageController.position.haveDimensions) {
                          value = _pageController.page! - index;
                          value = (1 - (value.abs() * 0.3)).clamp(0.1, 1.0);
                        }

                        return Center(
                          child: SizedBox(
                            height: Curves.easeInOut.transform(value) * maxSize,
                            width: Curves.easeInOut.transform(value) * maxSize,
                            child: child,
                          ),
                        );
                      },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                        if (isCurrentPage)
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.4),
                            blurRadius: 40,
                            spreadRadius: -5,
                          ),
                      ],
                    ),
                    // ✅ Only wrap current song's artwork in Hero
                    child: isCurrentPage
                        ? Hero(
                      tag: 'artwork_${song.id}',
                      // ✅ Add custom flight shuttle builder to prevent flicker
                      flightShuttleBuilder: (
                          BuildContext flightContext,
                          Animation<double> animation,
                          HeroFlightDirection flightDirection,
                          BuildContext fromHeroContext,
                          BuildContext toHeroContext,
                          ) {
                        // Use the destination widget during flight
                        return DefaultTextStyle(
                          style: DefaultTextStyle.of(toHeroContext).style,
                          child: toHeroContext.widget,
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _artworkCache[song.id]!,
                      ),
                    )
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _artworkCache[song.id]!,
                    ),
                  ),
                );
                  },
                );
              },
            ),
          ),
          ),
          Flexible(child: SizedBox(height: 40)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        song.artist,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _audioService.isFavorite(song.id) ? Icons.favorite : Icons.favorite_border,
                    color: _audioService.isFavorite(song.id) ? Colors.red.shade400 : Colors.white70,
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() {
                      _audioService.toggleFavorite(song.id);
                    });
                  },
                ),
              ],
            ),
          ),
          Flexible(child: SizedBox(height: 30)),
          StreamBuilder<Duration>(
            stream: _audioService.positionStream,
            builder: (context, positionSnapshot) {
              final position = positionSnapshot.data ?? Duration.zero;

              return StreamBuilder<Duration?>(
                stream: _audioService.durationStream,
                builder: (context, durationSnapshot) {
                  final duration = durationSnapshot.data ?? Duration.zero;
                  final progress = duration.inMilliseconds > 0
                      ? position.inMilliseconds / duration.inMilliseconds
                      : 0.0;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30.0),
                        child: GestureDetector(
                          onHorizontalDragUpdate: (details) {
                            final RenderBox box = context.findRenderObject() as RenderBox;
                            final position = details.localPosition.dx / box.size.width;
                            final seekPosition = duration * position.clamp(0.0, 1.0);
                            _audioService.seek(seekPosition);
                          },
                          child: _buildWaveformProgressBar(progress, song.id),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          Flexible(child: SizedBox(height: 30)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    _audioService.isShuffle ? Icons.shuffle_on_outlined : Icons.shuffle,
                    color: _audioService.isShuffle ? Colors.purple.shade300 : Colors.white70,
                    size: 26,
                  ),
                  onPressed: () {
                    setState(() {
                      _audioService.toggleShuffle();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 42),
                  onPressed: () => _audioService.skipToPrevious(),
                ),
                StreamBuilder<bool>(
                  stream: _audioService.playingStream,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data ?? false;
                    return Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.purple.shade400,
                            Colors.blue.shade400,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                        onPressed: () {
                          isPlaying ? _audioService.pause() : _audioService.play();
                        },
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 42),
                  onPressed: () => _audioService.skipToNext(),
                ),
                IconButton(
                  icon: Icon(
                    _audioService.repeatMode == RepeatMode.off
                        ? Icons.repeat
                        : _audioService.repeatMode == RepeatMode.all
                        ? Icons.repeat_on_outlined
                        : Icons.repeat_one_on_outlined,
                    color: _audioService.repeatMode != RepeatMode.off
                        ? Colors.purple.shade300
                        : Colors.white70,
                    size: 26,
                  ),
                  onPressed: () {
                    setState(() {
                      _audioService.toggleRepeat();
                    });
                  },
                ),
              ],
            ),
          ),
          Flexible(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildWaveformProgressBar(double progress, int songId) {
    final random = Random(songId);
    final barCount = 60;

    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(barCount, (index) {
          final baseHeight = 0.3 + random.nextDouble() * 0.7;
          final barProgress = index / barCount;
          final isPlayed = barProgress <= progress;

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 0.5),
              height: baseHeight * 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: isPlayed
                    ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.purple.shade300,
                    Colors.blue.shade400,
                  ],
                )
                    : null,
                color: isPlayed ? null : Colors.white.withOpacity(0.3),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildQueueView() {
    return StreamBuilder<Song?>(
      stream: _audioService.currentSongStream,
      builder: (context, snapshot) {
        final queue = _audioService.queue;
        final currentIndex = _audioService.currentIndex;

        return SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: queue.length,
            itemBuilder: (context, index) {
              final song = queue[index];
              final isCurrent = index == currentIndex;

              if (!_artworkCache.containsKey(song.id)) {
                _artworkCache[song.id] = _buildArtworkWidget(song.id);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: isCurrent
                        ? LinearGradient(
                      colors: [
                        Colors.purple.withOpacity(0.3),
                        Colors.blue.withOpacity(0.3),
                      ],
                    )
                        : null,
                    color: isCurrent ? null : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent ? Colors.purple.withOpacity(0.5) : Colors.white.withOpacity(0.1),
                      width: isCurrent ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: QueryArtworkWidget(
                          id: song.id,
                          type: ArtworkType.AUDIO,
                          artworkWidth: 50,
                          artworkHeight: 50,
                          keepOldArtwork: true,
                          nullArtworkWidget: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.purple.shade700, Colors.blue.shade700],
                              ),
                            ),
                            child: const Icon(Icons.music_note, color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      song.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      song.artist,
                      style: TextStyle(
                        color: isCurrent ? Colors.purple.shade200 : Colors.white.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isCurrent
                        ? Icon(Icons.equalizer, color: Colors.purple.shade300)
                        : null,
                    onTap: () {
                      _audioService.skipToIndex(index);
                      setState(() {
                        _showQueue = false;
                      });
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}