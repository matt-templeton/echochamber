import 'package:flutter/foundation.dart';
import '../models/video_model.dart';
import '../services/video_feed_service.dart';
import '../repositories/video_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

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
  WatchSession? _currentSession;
  Timer? _positionUpdateTimer;
  String? _currentVideoId;

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

  Future<void> _initializeVideos() async {
    _setLoading(true);
    _setControllerReady(false);
    try {
      // Load first video
      _currentVideo = await _feedService.getNextVideo();
      
      if (_currentVideo != null) {
        // Pre-fetch next video
        _nextVideo = await _feedService.getNextVideo();
        _previousVideo = null;
      } else {
        _error = 'No videos available';
      }
    } catch (e) {
      _error = 'Error loading videos: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadNextVideo() async {
    if (_isLoading) {
      return;
    }
    
    _setLoading(true);
    _setControllerReady(false);
    try {
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
      }
    } catch (e) {
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
      }
    } catch (e) {
      _error = 'Error loading video: $e';
    } finally {
      _setLoading(false);
    }
  }

  void setControllerReady(bool ready) {
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
    _isControllerReady = ready;
    notifyListeners();
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

    _currentVideoId = videoId;
    await _videoRepository.addToWatchHistory(videoId, user.uid);
    await startWatchSession();
  }

  Future<void> onVideoEnded() async {
    if (_currentSession != null) {
      await endCurrentSession(true);
    }
    _currentVideoId = null;
  }

  Future<void> updateWatchPosition(Duration position) async {
    if (_currentSession == null || _currentVideoId == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    await _videoRepository.updateWatchHistoryEntry(
      _currentSession!.id,
      watchDuration: position.inSeconds,
      completed: false,
    );
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

  @override
  void dispose() {
    _positionUpdateTimer?.cancel();
    if (_currentSession != null) {
      endCurrentSession(false);
    }
    super.dispose();
  }
} 