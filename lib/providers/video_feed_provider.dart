import 'package:flutter/foundation.dart';
import '../models/video_model.dart';
import '../services/video_feed_service.dart';
import '../repositories/video_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:developer' as dev;

class VideoFeedProvider with ChangeNotifier {
  final VideoFeedService _feedService;
  final VideoRepository _videoRepository;
  final FirebaseAuth _auth;
  Video? _currentVideo;
  Video? _nextVideo;
  Video? _previousVideo;
  bool _isLoading = false;
  bool _isControllerReady = false;
  String? _error;
  String _feedType = 'for_you'; // Default feed type
  bool _hasLiked = false;
  WatchSession? _currentSession;
  Timer? _positionUpdateTimer;
  String? _currentVideoId;
  Completer<void>? _initCompleter;

  VideoFeedProvider({
    VideoFeedService? feedService,
    VideoRepository? videoRepository,
    FirebaseAuth? auth,
  }) : _feedService = feedService ?? VideoFeedService(),
       _videoRepository = videoRepository ?? VideoRepository(),
       _auth = auth ?? FirebaseAuth.instance {
    _initializeVideos();
  }

  Video? get currentVideo => _currentVideo;
  Video? get nextVideo => _nextVideo;
  Video? get previousVideo => _previousVideo;
  bool get isLoading => _isLoading;
  bool get isControllerReady => _isControllerReady;
  String? get error => _error;
  String get feedType => _feedType;
  WatchSession? get currentSession => _currentSession;
  bool get hasPreviousVideo => _previousVideo != null;
  bool get hasLiked => _hasLiked;

  Future<void> waitForInitialization() async {
    if (_initCompleter != null) {
      await _initCompleter!.future;
    }
  }

  Future<void> _initializeVideos() async {
    dev.log('Starting _initializeVideos', name: 'VideoFeedProvider');
    
    // Create a new completer for initialization
    _initCompleter = Completer<void>();
    
    try {
      _setLoading(true);
      _setControllerReady(false);

      // Load first video
      dev.log('Loading first video', name: 'VideoFeedProvider');
      _currentVideo = await _feedService.getNextVideo();
      dev.log('Loaded first video: ${_currentVideo?.id}', name: 'VideoFeedProvider');
      
      if (_currentVideo != null) {
        // Pre-fetch next video
        dev.log('Pre-fetching next video', name: 'VideoFeedProvider');
        _nextVideo = await _feedService.getNextVideo();
        dev.log('Pre-fetched next video: ${_nextVideo?.id}', name: 'VideoFeedProvider');
        _previousVideo = null;
        _error = null;
        
        // Check like status for first video
        await _checkLikeStatus();
      } else {
        _error = 'No videos available';
        dev.log('No videos available', name: 'VideoFeedProvider');
      }
    } catch (e, stackTrace) {
      dev.log('Error loading videos', name: 'VideoFeedProvider', error: e, stackTrace: stackTrace);
      _error = 'Error loading videos: $e';
    } finally {
      _setLoading(false);
      dev.log('Finished _initializeVideos', name: 'VideoFeedProvider');
      _initCompleter?.complete();
      _initCompleter = null;
    }
  }

  Future<void> loadNextVideo() async {
    dev.log('Starting loadNextVideo', name: 'VideoFeedProvider');
    
    // Wait for initialization to complete if it's still ongoing
    await waitForInitialization();
    
    if (_isLoading) {
      dev.log('Already loading next video, waiting for completion', name: 'VideoFeedProvider');
      return;
    }
    
    _setLoading(true);
    _setControllerReady(false);
    
    try {
      dev.log('Starting to load next video', name: 'VideoFeedProvider');
      
      // Ensure current session is ended
      if (_currentSession != null) {
        await endCurrentSession(false);
      }

      // Store current video as previous
      if (_currentVideo != null) {
        _previousVideo = _currentVideo;
      }

      // Move next video to current
      if (_nextVideo != null) {
        _currentVideo = _nextVideo;
        _nextVideo = null;
      } else {
        _currentVideo = await _feedService.getNextVideo();
      }
      
      // Pre-fetch next video
      _nextVideo = await _feedService.getNextVideo();
      
      if (_currentVideo == null && _nextVideo == null) {
        _error = 'No more videos available';
      } else {
        _error = null;
        await _checkLikeStatus();
      }
      
      dev.log('Successfully loaded next video', name: 'VideoFeedProvider');
    } catch (e, stackTrace) {
      dev.log('Error loading next video', name: 'VideoFeedProvider', error: e, stackTrace: stackTrace);
      _error = 'Error loading next video: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPreviousVideo() async {
    if (_isLoading || _previousVideo == null) {
      return;
    }
    
    _setLoading(true);
    _setControllerReady(false);
    try {
      // Store current video as next
      if (_currentVideo != null) {
        _nextVideo = _currentVideo;
      }

      // Move previous video to current
      _currentVideo = _previousVideo;
      _previousVideo = null;
      
      _error = null;
      await _checkLikeStatus();
    } catch (e) {
      _error = 'Error loading previous video: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadSpecificVideo(String videoId) async {
    if (_isLoading) {
      return;
    }
    
    _setLoading(true);
    _setControllerReady(false);
    try {
      // Load the specific video
      _currentVideo = await _videoRepository.getVideoById(videoId);
      
      // Pre-fetch next video
      _nextVideo = await _feedService.getNextVideo();
      
      if (_currentVideo == null) {
        _error = 'Video not found';
      } else {
        _error = null;
        await _checkLikeStatus();
      }
    } catch (e) {
      _error = 'Error loading video: $e';
    } finally {
      _setLoading(false);
    }
  }

  void setControllerReady(bool ready) {
    dev.log('Setting controller ready state to: $ready', name: 'VideoFeedProvider');
    if (!ready && _currentSession != null) {
      // Ensure we cleanup any existing session when controller becomes not ready
      endCurrentSession(false).catchError((e) {
        dev.log('Error ending session: $e', name: 'VideoFeedProvider', error: e);
      });
    }
    _setControllerReady(ready);
  }

  void resetFeed() {
    _feedService.resetFeed();
    _currentVideo = null;
    _nextVideo = null;
    _error = null;
    _setControllerReady(false);
    _initializeVideos();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setControllerReady(bool ready) {
    if (_isControllerReady != ready) {
      _isControllerReady = ready;
      notifyListeners();
    }
  }

  void setFeedType(String type) {
    if (type != _feedType) {
      _feedType = type;
      _feedService.resetFeed();
      _currentVideo = null;
      _nextVideo = null;
      _error = null;
      _setControllerReady(false);
      _initializeVideos();
    }
  }

  Future<void> startWatchSession() async {
    if (_currentVideo == null || _currentSession != null) return;

    try {
      _currentSession = await _videoRepository.startWatchSession(
        _currentVideo!.id,
        _auth.currentUser!.uid,
      );
      notifyListeners();
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> endCurrentSession(bool completed) async {
    if (_currentSession == null || _currentVideo == null) return;

    try {
      await _videoRepository.endWatchSession(
        _currentSession!.id,
        _currentVideo!.id,
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
      if (_currentSession != null) {
        await endCurrentSession(true);
      }
    } catch (e) {
      debugPrint('Error ending video session: $e');
    } finally {
      _currentVideoId = null;
    }
  }

  Future<void> updateWatchPosition(Duration position) async {
    if (_currentSession == null || _currentVideoId == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _videoRepository.updateWatchHistoryEntry(
        _currentSession!.id,
        watchDuration: position.inSeconds,
        completed: false,
      );
    } catch (e) {
      if (e.toString().contains('not-found')) {
        // If the watch history entry doesn't exist, create a new one
        try {
          await _videoRepository.addToWatchHistory(_currentVideoId!, user.uid);
          // Retry the update after creating the entry
          await _videoRepository.updateWatchHistoryEntry(
            _currentSession!.id,
            watchDuration: position.inSeconds,
            completed: false,
          );
        } catch (retryError) {
          // Log error but don't crash the app
          debugPrint('Error creating/updating watch history: $retryError');
        }
      } else {
        // Log other errors but don't crash the app
        debugPrint('Error updating watch position: $e');
      }
    }
  }

  // Add cleanup method for video sessions
  Future<void> cleanupVideoSession(String videoId) async {
    dev.log('Cleaning up video session for videoId: $videoId', name: 'VideoFeedProvider');
    try {
      // Only cleanup if this is the current video
      if (_currentVideoId == videoId) {
        if (_currentSession != null) {
          await endCurrentSession(false);
        }
        _currentVideoId = null;
        setControllerReady(false);
      }
    } catch (e, stackTrace) {
      dev.log('Error cleaning up video session', name: 'VideoFeedProvider', error: e, stackTrace: stackTrace);
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
    if (_currentVideo == null || _auth.currentUser == null) {
      _hasLiked = false;
      return;
    }
    
    try {
      _hasLiked = await _videoRepository.hasUserLikedVideo(
        _currentVideo!.id,
        _auth.currentUser!.uid,
      );
      notifyListeners();
    } catch (e) {
      // Handle error silently
      _hasLiked = false;
    }
  }

  Future<void> toggleLike() async {
    if (_currentVideo == null || _auth.currentUser == null) return;

    try {
      if (_hasLiked) {
        await _videoRepository.unlikeVideo(_currentVideo!.id, _auth.currentUser!.uid);
        _hasLiked = false;
        _currentVideo = _currentVideo!.copyWith(
          likesCount: _currentVideo!.likesCount - 1
        );
      } else {
        await _videoRepository.likeVideo(_currentVideo!.id, _auth.currentUser!.uid);
        _hasLiked = true;
        _currentVideo = _currentVideo!.copyWith(
          likesCount: _currentVideo!.likesCount + 1
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
    super.dispose();
  }
} 