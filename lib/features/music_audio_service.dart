import 'dart:async';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart' as audio_svc;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'song_model.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart'; // ✅ ADD THIS

class MusicAudioService {
  static final MusicAudioService _instance = MusicAudioService._internal();
  factory MusicAudioService() => _instance;
  MusicAudioService._internal() {
    debugPrint('🎵 MusicAudioService singleton created');
  }

  audio_svc.AudioHandler? _audioHandler;
  AudioPlayerHandler? get handler => _audioHandler as AudioPlayerHandler?;

  List<Song> _queue = [];
  List<Song> _originalQueue = [];
  int _currentIndex = 0;
  bool _isShuffle = false;
  RepeatMode _repeatMode = RepeatMode.off;
  Set<int> _favorites = {};

  // ✅ REPLACED: StreamController with BehaviorSubject for INSTANT state
  final _currentSongSubject = BehaviorSubject<Song?>();

  Stream<Song?> get currentSongStream => _currentSongSubject.stream;
  Song? get currentSong => _currentSongSubject.valueOrNull; // ✅ INSTANT synchronous access

  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isShuffle => _isShuffle;
  RepeatMode get repeatMode => _repeatMode;
  Set<int> get favorites => _favorites;

  Stream<Duration> get positionStream =>
      handler?.player.positionStream ?? Stream.value(Duration.zero);
  Stream<Duration?> get durationStream =>
      handler?.player.durationStream ?? Stream.value(null);
  Stream<PlayerState> get playerStateStream =>
      handler?.player.playerStateStream ?? Stream.value(PlayerState(false, ProcessingState.idle));
  Stream<bool> get playingStream =>
      handler?.player.playingStream ?? Stream.value(false);

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize(audio_svc.AudioHandler audioHandler) async {
    debugPrint('🎵 MusicAudioService.initialize called');
    _audioHandler = audioHandler;
    _isInitialized = true;

    await _loadFavorites();

    handler?.player.currentIndexStream.listen((index) {
      if (index != null && _queue.isNotEmpty && index < _queue.length) {
        _currentIndex = index;
        _currentSongSubject.add(_queue[_currentIndex]); // ✅ UPDATED
        _saveLastPlayback();
      }
    });

    handler?.player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        if (_repeatMode == RepeatMode.off) {
          handler?.stop();
        }
      }
    });

    debugPrint('✅ MusicAudioService initialized with AudioHandler');
  }

  Future<void> setQueue(List<Song> songs, {int initialIndex = 0}) async {
    debugPrint('🎵 setQueue called with ${songs.length} songs');

    if (_audioHandler == null) {
      debugPrint('⚠️ AudioHandler not initialized');
      return;
    }

    _originalQueue = List.from(songs);
    _queue = List.from(songs);
    _currentIndex = initialIndex.clamp(0, songs.length - 1);

    await handler?.setQueueFromSongs(songs, initialIndex: _currentIndex);

    if (_isShuffle) {
      await _applyShuffle();
    }

    _currentSongSubject.add(_queue[_currentIndex]); // ✅ UPDATED
    await _audioHandler?.play();
  }

  Future<void> play() async {
    await _audioHandler?.play();
  }

  Future<void> pause() async {
    await _audioHandler?.pause();
    await _saveLastPlayback();
  }

  Future<void> stop() async {
    await _audioHandler?.stop();
    _currentSongSubject.add(null); // ✅ UPDATED
  }

  Future<void> skipToNext() async {
    await _audioHandler?.skipToNext();
  }

  Future<void> skipToPrevious() async {
    await _audioHandler?.skipToPrevious();
  }

  Future<void> seek(Duration position) async {
    await _audioHandler?.seek(position);
  }

  Future<void> skipToIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;

    await handler?.player.seek(Duration.zero, index: index);
    _currentIndex = index;
    _currentSongSubject.add(_queue[_currentIndex]); // ✅ UPDATED
    await _audioHandler?.play();
  }

  Future<void> toggleShuffle() async {
    _isShuffle = !_isShuffle;

    if (_queue.isEmpty || handler == null) return;

    if (_isShuffle) {
      await _applyShuffle();
    } else {
      final currentSong = _queue[_currentIndex];
      final originalIndex = _originalQueue.indexWhere((s) => s.id == currentSong.id);

      _queue = List.from(_originalQueue);
      _currentIndex = originalIndex.clamp(0, _queue.length - 1);

      await handler?.setQueueFromSongs(_queue, initialIndex: _currentIndex);
      _currentSongSubject.add(_queue[_currentIndex]); // ✅ UPDATED
      await _audioHandler?.play();
    }
  }

  Future<void> _applyShuffle() async {
    if (_queue.isEmpty || handler == null) return;

    final currentSong = _queue[_currentIndex];
    final shuffledSongs = List<Song>.from(_queue)..shuffle(Random());

    shuffledSongs.remove(currentSong);
    shuffledSongs.insert(0, currentSong);

    _queue = shuffledSongs;
    _currentIndex = 0;

    await handler?.setQueueFromSongs(_queue, initialIndex: 0);
    _currentSongSubject.add(_queue[0]); // ✅ UPDATED
    await _audioHandler?.play();
  }

  Future<void> toggleRepeat() async {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.all;
        await handler?.player.setLoopMode(LoopMode.all);
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
        await handler?.player.setLoopMode(LoopMode.one);
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.off;
        await handler?.player.setLoopMode(LoopMode.off);
        break;
    }
  }

  Future<void> toggleFavorite(int songId) async {
    if (_favorites.contains(songId)) {
      _favorites.remove(songId);
    } else {
      _favorites.add(songId);
    }
    await _saveFavorites();

    if (currentSong?.id == songId && handler != null) {
      await handler?.updateMediaItemWithFavorite(currentSong!, _favorites.contains(songId));
    }
  }

  bool isFavorite(int songId) => _favorites.contains(songId);

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'favorites',
      _favorites.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('favorites') ?? [];
    _favorites = favList.map((e) => int.parse(e)).toSet();
  }

  Future<void> _saveLastPlayback() async {
    if (currentSong == null || handler == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_song', jsonEncode(currentSong!.toJson()));
    await prefs.setInt('last_position', handler!.player.position.inMilliseconds);
    await prefs.setInt('last_index', _currentIndex);
  }

  Future<Map<String, dynamic>?> loadLastPlayback() async {
    final prefs = await SharedPreferences.getInstance();
    final songJson = prefs.getString('last_song');
    final position = prefs.getInt('last_position');
    final index = prefs.getInt('last_index');

    if (songJson == null) return null;

    return {
      'song': Song.fromJson(jsonDecode(songJson)),
      'position': position ?? 0,
      'index': index ?? 0,
    };
  }

  Future<Song?> getLastPlayedSongMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    final songJson = prefs.getString('last_song');

    if (songJson == null) return null;

    try {
      return Song.fromJson(jsonDecode(songJson));
    } catch (e) {
      debugPrint('❌ Error loading last played song metadata: $e');
      return null;
    }
  }

  void dispose() {
    _currentSongSubject.close(); // ✅ UPDATED: close BehaviorSubject
  }
}

class AudioPlayerHandler extends audio_svc.BaseAudioHandler
    with audio_svc.SeekHandler, audio_svc.QueueHandler {

  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;

  final MusicAudioService _musicService = MusicAudioService();

  AudioPlayerHandler() {
    debugPrint('🎵 AudioPlayerHandler constructor called');

    mediaItem.add(audio_svc.MediaItem(
      id: 'none',
      title: 'No song playing',
      artist: 'Unknown',
    ));

    _player.playbackEventStream.listen((event) {
      _broadcastState();
    });

    _broadcastState();
    debugPrint('🎵 AudioPlayerHandler initialized');
  }

  audio_svc.MediaItem _songToMediaItem(Song song, {bool isFavorite = false}) {
    Uri? artUri;
    try {
      artUri = Uri.parse('content://media/external/audio/albumart/${song.albumId}');
    } catch (e) {
      debugPrint('⚠️ Error creating art URI: $e');
    }

    return audio_svc.MediaItem(
      id: song.id.toString(),
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration != null
          ? Duration(milliseconds: song.duration!)
          : null,
      artUri: artUri,
      extras: {
        'isFavorite': isFavorite,
      },
    );
  }

  Future<void> setQueueFromSongs(List<Song> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return;

    final sources = songs.map((song) {
      final isFavorite = _musicService.isFavorite(song.id);
      return AudioSource.uri(
        Uri.parse(song.uri),
        tag: _songToMediaItem(song, isFavorite: isFavorite),
      );
    }).toList();

    await _player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
      initialIndex: initialIndex,
    );

    final currentSong = songs[initialIndex];
    final isFavorite = _musicService.isFavorite(currentSong.id);
    mediaItem.add(_songToMediaItem(currentSong, isFavorite: isFavorite));

    debugPrint('🎵 Queue set with ${songs.length} songs, starting at index $initialIndex');
  }

  Future<void> updateMediaItemWithFavorite(Song song, bool isFavorite) async {
    mediaItem.add(_songToMediaItem(song, isFavorite: isFavorite));
    _broadcastState();
  }

  void _broadcastState() {
    final playing = _player.playing;

    audio_svc.AudioProcessingState processingState;
    switch (_player.processingState) {
      case ProcessingState.idle:
        processingState = audio_svc.AudioProcessingState.idle;
        break;
      case ProcessingState.loading:
        processingState = audio_svc.AudioProcessingState.loading;
        break;
      case ProcessingState.buffering:
        processingState = audio_svc.AudioProcessingState.buffering;
        break;
      case ProcessingState.ready:
        processingState = audio_svc.AudioProcessingState.ready;
        break;
      case ProcessingState.completed:
        processingState = audio_svc.AudioProcessingState.completed;
        break;
    }

    final currentIndex = _player.currentIndex;
    bool isFavorite = false;
    if (currentIndex != null && _player.sequence != null && currentIndex < _player.sequence!.length) {
      final tag = _player.sequence![currentIndex].tag;
      if (tag is audio_svc.MediaItem) {
        isFavorite = tag.extras?['isFavorite'] as bool? ?? false;
      }
    }

    playbackState.add(audio_svc.PlaybackState(
      controls: [
        audio_svc.MediaControl.skipToPrevious,
        playing
            ? audio_svc.MediaControl.pause
            : audio_svc.MediaControl.play,
        audio_svc.MediaControl.skipToNext,
        audio_svc.MediaControl(
          androidIcon: isFavorite ? 'drawable/ic_favorite_filled' : 'drawable/ic_favorite_outline',
          label: isFavorite ? 'Unfavorite' : 'Favorite',
          action: audio_svc.MediaAction.custom,
        ),
      ],
      systemActions: const {
        audio_svc.MediaAction.seek,
        audio_svc.MediaAction.seekForward,
        audio_svc.MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex,
    ));

    if (currentIndex != null && _player.sequence != null && currentIndex < _player.sequence!.length) {
      final tag = _player.sequence![currentIndex].tag;
      if (tag is audio_svc.MediaItem) {
        mediaItem.add(tag);
      }
    }
  }

  @override
  Future<void> play() async {
    debugPrint('🎵 Play called');
    await _player.play();
  }

  @override
  Future<void> pause() async {
    debugPrint('🎵 Pause called');
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    debugPrint('🎵 Seek called: $position');
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    debugPrint('🎵 Skip to next');
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    debugPrint('🎵 Skip to previous');

    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> stop() async {
    debugPrint('🎵 Stop called');
    await _player.stop();
  }

  @override
  Future<void> fastForward() async {
    final newPosition = _player.position + const Duration(seconds: 10);
    await _player.seek(newPosition);
  }

  @override
  Future<void> rewind() async {
    final newPosition = _player.position - const Duration(seconds: 10);
    await _player.seek(newPosition > Duration.zero ? newPosition : Duration.zero);
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'toggleFavorite') {
      final currentIndex = _player.currentIndex;
      if (currentIndex != null && _player.sequence != null && currentIndex < _player.sequence!.length) {
        final tag = _player.sequence![currentIndex].tag;
        if (tag is audio_svc.MediaItem) {
          final songId = int.parse(tag.id);
          await _musicService.toggleFavorite(songId);
          _broadcastState();
        }
      }
    }
  }
}

enum RepeatMode { off, all, one }