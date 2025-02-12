import 'package:flutter/foundation.dart';
import '../models/video_model.dart';
import '../services/video_feed_service.dart';
import '../repositories/video_repository.dart';
import '../models/video_buffer_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:developer' as dev;

class VideoFeedProvider with ChangeNotifier {
  final VideoFeedService _feedService;
  final VideoRepository _videoRepository;
  final FirebaseAuth _auth;
  final VideoBufferManager _bufferManager;
  
  List<Video> _videos = [];
  int _currentIndex = 0;
  bool _isLoading = false;
  bool _isControllerReady = false;
  bool _isEnabled = true;
  bool _isPaused = false;
  String? _error;
  bool _hasLiked = false;
  WatchSession? _currentSession;
  Timer? _positionUpdateTimer;
  String? _currentVideoId;
  Completer<void>? _initCompleter;
  bool _hasMoreVideos = true;

  VideoFeedProvider({
    VideoFeedService? feedService,
    VideoRepository? videoRepository,
    FirebaseAuth? auth,
  }) : _feedService = feedService ?? VideoFeedService(),
       _videoRepository = videoRepository ?? VideoRepository(),
       _auth = auth ?? FirebaseAuth.instance,
       _bufferManager = VideoBufferManager();

  // Getters
  Video? get currentVideo => _videos.isNotEmpty ? _videos[_currentIndex] : null;
  Video? get nextVideo => _hasNextVideo ? _videos[_currentIndex + 1] : null;
  Video? get previousVideo => _hasPreviousVideo ? _videos[_currentIndex - 1] : null;
  bool get isLoading => _isLoading;
  bool get isControllerReady => _isControllerReady;
  String? get error => _error;
  bool get hasLiked => _hasLiked;
  bool get isPaused => _isPaused;
  List<Video> get videos => List.unmodifiable(_videos);
  int get currentIndex => _currentIndex;
  int get videoCount => _videos.length;
  bool get _hasNextVideo => _currentIndex < _videos.length - 1;
  bool get _hasPreviousVideo => _currentIndex > 0;

  Future<void> waitForInitialization() async {
    if (_initCompleter != null) {
      await _initCompleter!.future;
    }
  }

  VideoPlayerController? getBufferedVideo(String videoId) => _bufferManager.getBufferedVideo(videoId);
  bool hasBufferedVideo(String videoId) => _bufferManager.hasBufferedVideo(videoId);
  Map<String, double> get bufferProgress => _bufferManager.bufferProgress;

  void updateBufferProgress(String videoId, double progress) {
    _bufferManager.updateBufferProgress(videoId, progress);
  }

  void setEnabled(bool enabled) {
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;
    
    // Schedule state changes for after the current build phase
    Future.microtask(() async {
      if (_isEnabled) {  // Check current state in case it changed
        if (_isPaused) {
          await _resumePlayback();
        } else {
          await _initializeVideos();
        }
      } else {
        await _pausePlayback();
      }
      
      notifyListeners();
    });
  }

  Future<void> _pausePlayback() async {
    _isPaused = true;
    dev.log('Pausing video playback', name: 'VideoFeedProvider');
    
    // Save current position before pausing
    if (currentVideo != null) {
      final currentController = _bufferManager.getBufferedVideo(currentVideo!.id);
      if (currentController != null && currentController.value.isInitialized) {
        _bufferManager.savePosition(currentVideo!.id, currentController.value.position);
      }
    }
    
    // Pause buffering but maintain buffers
    _bufferManager.pauseBuffering();
    
    // Pause current video controller if exists
    final currentController = _bufferManager.getBufferedVideo(currentVideo?.id ?? '');
    if (currentController != null) {
      await currentController.pause();
    }
    
    // Maintain state but pause activity
    if (_currentSession != null) {
      await endCurrentSession(false);
    }
  }

  Future<void> _resumePlayback() async {
    _isPaused = false;
    dev.log('Resuming video playback', name: 'VideoFeedProvider');
    
    // Resume buffering
    _bufferManager.resumeBuffering();
    
    // Resume current video if exists
    if (currentVideo != null) {
      final currentController = _bufferManager.getBufferedVideo(currentVideo!.id);
      if (currentController != null) {
        // Restore position if available
        final savedPosition = _bufferManager.getPosition(currentVideo!.id);
        if (savedPosition != null) {
          await currentController.seekTo(savedPosition);
        }
        await currentController.play();
        _setControllerReady(true);
      } else {
        // If controller was disposed, reinitialize
        await _bufferManager.addToBuffer(currentVideo!);
      }
    }
    
    // Resume session if needed
    if (currentVideo != null && _auth.currentUser != null) {
      await startWatchSession();
    }
  }

  Future<void> _initializeVideos() async {
    dev.log('Starting _initializeVideos', name: 'VideoFeedProvider');
    dev.log('Current state - videos: ${_videos.length}, currentIndex: $_currentIndex', name: 'VideoFeedProvider');
    
    _initCompleter = Completer<void>();
    
    try {
      _setLoading(true);
      _setControllerReady(false);

      // Load first video
      final firstVideo = await _feedService.getNextVideo();
      if (firstVideo != null) {
        _videos = [firstVideo];
        _currentIndex = 0;
        dev.log('First video loaded - id: ${firstVideo.id}', name: 'VideoFeedProvider');
        
        // Add current video to buffer
        await _bufferManager.addToBuffer(firstVideo);
        dev.log('First video added to buffer', name: 'VideoFeedProvider');
        
        // Pre-fetch next video
        final nextVideo = await _feedService.getNextVideo();
        if (nextVideo != null) {
          _videos.add(nextVideo);
          dev.log('Next video prefetched - id: ${nextVideo.id}', name: 'VideoFeedProvider');
        }
        
        _error = null;
        await _checkLikeStatus();
      } else {
        _error = 'No videos available';
      }
    } catch (e, stackTrace) {
      dev.log('Error loading videos', name: 'VideoFeedProvider', error: e, stackTrace: stackTrace);
      _error = 'Error loading videos: $e';
    } finally {
      _setLoading(false);
      _initCompleter?.complete();
      _initCompleter = null;
      notifyListeners();
      dev.log('_initializeVideos completed - videos: ${_videos.length}, currentIndex: $_currentIndex', 
        name: 'VideoFeedProvider');
    }
  }

  Future<void> loadMoreVideos() async {
    if (_isLoading || !_hasMoreVideos) {
      dev.log('Skipping loadMoreVideos - isLoading: $_isLoading, hasMoreVideos: $_hasMoreVideos', 
        name: 'VideoFeedProvider');
      return;
    }
    
    try {
      _setLoading(true);
      dev.log('Loading more videos - current count: ${_videos.length}', name: 'VideoFeedProvider');
      
      final nextVideo = await _feedService.getNextVideo();
      if (nextVideo != null) {
        _videos.add(nextVideo);
        dev.log('Added new video to list - id: ${nextVideo.id}, new count: ${_videos.length}', 
          name: 'VideoFeedProvider');
        notifyListeners();
      } else {
        _hasMoreVideos = false;
        dev.log('No more videos available', name: 'VideoFeedProvider');
      }
    } catch (e) {
      dev.log('Error loading more videos', name: 'VideoFeedProvider', error: e);
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> switchToVideo(int index) async {
    dev.log('Attempting to switch to video index: $index (current: $_currentIndex)', 
      name: 'VideoFeedProvider');
    
    if (index < 0 || index >= _videos.length) {
      dev.log('Invalid video index: $index, videos length: ${_videos.length}', 
        name: 'VideoFeedProvider');
      return false;
    }
    
    try {
      // End current session if exists
      if (_currentSession != null) {
        dev.log('Ending current session before switch', name: 'VideoFeedProvider');
        await endCurrentSession(false);
      }

      _currentIndex = index;
      final targetVideo = _videos[index];
      dev.log('Switching to video - id: ${targetVideo.id}, index: $index', 
        name: 'VideoFeedProvider');

      // Add to buffer if not already buffered
      if (!_bufferManager.hasBufferedVideo(targetVideo.id)) {
        dev.log('Adding video to buffer - id: ${targetVideo.id}', name: 'VideoFeedProvider');
        await _bufferManager.addToBuffer(targetVideo);
      } else {
        dev.log('Video already in buffer - id: ${targetVideo.id}', name: 'VideoFeedProvider');
      }

      // Check if we need to load more videos
      if (index >= _videos.length - 2 && _hasMoreVideos) {
        dev.log('Near end of list, loading more videos', name: 'VideoFeedProvider');
        await loadMoreVideos();
      }

      await _checkLikeStatus();
      notifyListeners();
      dev.log('Successfully switched to video index: $index', name: 'VideoFeedProvider');
      return true;
    } catch (e) {
      dev.log('Error switching video', name: 'VideoFeedProvider', error: e);
      return false;
    }
  }

  void resetFeed() {
    _feedService.resetFeed();
    _videos.clear();
    _currentIndex = 0;
    _error = null;
    _hasMoreVideos = true;
    _setControllerReady(false);
    _initializeVideos();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setControllerReady(bool ready) {
    dev.log('_setControllerReady called with: $ready currently: $_isControllerReady', name: 'VideoFeedProvider');
    if (_isControllerReady != ready) {
      _isControllerReady = ready;
      notifyListeners();
    }
  }

  Future<void> startWatchSession() async {
    if (currentVideo == null || _currentSession != null) return;

    try {
      _currentSession = await _videoRepository.startWatchSession(
        currentVideo!.id,
        _auth.currentUser!.uid,
      );
      notifyListeners();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> endCurrentSession(bool completed) async {
    if (_currentSession == null || currentVideo == null) return;

    try {
      await _videoRepository.endWatchSession(
        _currentSession!.id,
        currentVideo!.id,
      );
      _currentSession = null;
      notifyListeners();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> onVideoStarted(String videoId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      _currentVideoId = videoId;
      // Ensure watch history entry exists
      await _videoRepository.addToWatchHistory(videoId, user.uid);
      // Start the watch session
      _currentSession = await _videoRepository.startWatchSession(videoId, user.uid);
      notifyListeners();
    } catch (e) {
      debugPrint('Error starting video session: $e');
      // Even if session creation fails, don't crash the app
      _currentVideoId = videoId;
    }
  }

  Future<void> onVideoEnded() async {
    try {
      dev.log('onVideoEnded currentSession: $_currentSession', name: 'VideoFeedProvider');
      if (_currentSession != null) {
        await endCurrentSession(true);
      }
    } catch (e) {
      debugPrint('Error ending video session: $e');
    } finally {
      _currentVideoId = null;
    }
  }

  Stream<QuerySnapshot> getWatchHistory({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.empty();
    }

    return _videoRepository.streamWatchHistory(
      user.uid,
      limit: limit,
      startAfter: startAfter,
    );
  }

  Future<void> clearWatchHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _videoRepository.clearWatchHistory(user.uid);
    notifyListeners();
  }

  Future<void> removeFromHistory(String entryId) async {
    await _videoRepository.deleteWatchHistoryEntry(entryId);
    notifyListeners();
  }

  Future<void> _checkLikeStatus() async {
    if (currentVideo == null || _auth.currentUser == null) {
      _hasLiked = false;
      return;
    }
    
    try {
      _hasLiked = await _videoRepository.hasUserLikedVideo(
        currentVideo!.id,
        _auth.currentUser!.uid,
      );
      notifyListeners();
    } catch (e) {
      // Handle error silently
      _hasLiked = false;
    }
  }

  Future<void> toggleLike() async {
    if (currentVideo == null || _auth.currentUser == null) return;

    try {
      if (_hasLiked) {
        await _videoRepository.unlikeVideo(currentVideo!.id, _auth.currentUser!.uid);
        _hasLiked = false;
        _videos[_currentIndex] = currentVideo!.copyWith(
          likesCount: currentVideo!.likesCount - 1
        );
      } else {
        await _videoRepository.likeVideo(currentVideo!.id, _auth.currentUser!.uid);
        _hasLiked = true;
        _videos[_currentIndex] = currentVideo!.copyWith(
          likesCount: currentVideo!.likesCount + 1
        );
      }
      notifyListeners();
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  void dispose() {
    _positionUpdateTimer?.cancel();
    if (_currentSession != null) {
      endCurrentSession(false);
    }
    _bufferManager.dispose();
    super.dispose();
  }
} 