import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'music_audio_service.dart';
import 'player_page.dart';
import 'song_model.dart';
import 'dart:ui';
import 'player_route.dart'; // ✅ Import the route

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  // ✅ Hero flight builder for smooth morph
  Widget _heroFlightBuilder(
      BuildContext context,
      Animation<double> animation,
      HeroFlightDirection flightDirection,
      BuildContext fromHeroContext,
      BuildContext toHeroContext,
      ) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.95, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
      ),
      child: toHeroContext.widget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioService = MusicAudioService();

    const double miniPlayerHeight = 85.0;

    return StreamBuilder<Song?>(
      stream: audioService.currentSongStream,
      initialData: audioService.currentSong, // ✅ Instant state
      builder: (context, songSnapshot) {
        final currentSong = songSnapshot.data;
        if (currentSong == null) return const SizedBox.shrink();

        return StreamBuilder<bool>(
          stream: audioService.playingStream,
          builder: (context, playingSnapshot) {
            final isPlaying = playingSnapshot.data ?? false;

            return GestureDetector(
              onTap: () {
                // ✅ Use custom slide-up route
                Navigator.of(context).push(
                  slideUpPlayerRoute(const PlayerPage()),
                );
              },
              child: Container(
                height: miniPlayerHeight,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 25,
                      spreadRadius: 0,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 35,
                      spreadRadius: -5,
                      offset: const Offset(0, 12),
                    ),
                  ],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.12),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Progress bar
                          StreamBuilder<Duration>(
                            stream: audioService.positionStream,
                            builder: (context, positionSnapshot) {
                              final position = positionSnapshot.data ?? Duration.zero;

                              return StreamBuilder<Duration?>(
                                stream: audioService.durationStream,
                                builder: (context, durationSnapshot) {
                                  final duration = durationSnapshot.data ?? Duration.zero;
                                  final progress = duration.inMilliseconds > 0
                                      ? position.inMilliseconds / duration.inMilliseconds
                                      : 0.0;

                                  return Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.purple.shade400,
                                          Colors.blue.shade400,
                                        ],
                                      ),
                                    ),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: Colors.white.withOpacity(0.15),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white.withOpacity(0.9),
                                      ),
                                      minHeight: 3,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          // Content
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                              child: Row(
                                children: [
                                  // ✅ Album Art with Hero animation
                                  // ✅ Album Art with Hero animation
                                  Hero(
                                    tag: 'artwork_${currentSong.id}',
                                    // ✅ Add placeholderBuilder to prevent flicker
                                    placeholderBuilder: (context, heroSize, child) {
                                      return Container(
                                        width: 55,
                                        height: 55,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          color: Colors.purple.withOpacity(0.3),
                                        ),
                                      );
                                    },
                                    flightShuttleBuilder: (
                                        BuildContext flightContext,
                                        Animation<double> animation,
                                        HeroFlightDirection flightDirection,
                                        BuildContext fromHeroContext,
                                        BuildContext toHeroContext,
                                        ) {
                                      // Use a smooth scale transition
                                      return ScaleTransition(
                                        scale: Tween<double>(begin: 0.2, end: 1.0).animate(
                                          CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOutCubic,
                                          ),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: toHeroContext.widget,
                                        ),
                                      );
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.purple.withOpacity(0.5),
                                            blurRadius: 15,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: QueryArtworkWidget(
                                        id: currentSong.id,
                                        type: ArtworkType.AUDIO,
                                        artworkWidth: 55,
                                        artworkHeight: 55,
                                        artworkBorder: BorderRadius.circular(12),
                                        keepOldArtwork: true, // ✅ Important to prevent reload
                                        nullArtworkWidget: Container(
                                          width: 55,
                                          height: 55,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.purple.shade400,
                                                Colors.blue.shade400,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.music_note,
                                            color: Colors.white,
                                            size: 26,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Song info
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentSong.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          currentSong.artist,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 13.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Control buttons
                                  _buildControlButton(
                                    icon: Icons.skip_previous_rounded,
                                    onPressed: () => audioService.skipToPrevious(),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildControlButton(
                                    icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    onPressed: () {
                                      isPlaying ? audioService.pause() : audioService.play();
                                    },
                                    isPrimary: true,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildControlButton(
                                    icon: Icons.skip_next_rounded,
                                    onPressed: () => audioService.skipToNext(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return Container(
      width: isPrimary ? 46 : 40,
      height: isPrimary ? 46 : 40,
      decoration: BoxDecoration(
        gradient: isPrimary
            ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade400,
            Colors.blue.shade400,
          ],
        )
            : null,
        color: isPrimary ? null : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(isPrimary ? 23 : 20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: isPrimary
            ? [
          BoxShadow(
            color: Colors.purple.withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ]
            : null,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          color: Colors.white,
          size: isPrimary ? 26 : 22,
        ),
        onPressed: onPressed,
      ),
    );
  }
}