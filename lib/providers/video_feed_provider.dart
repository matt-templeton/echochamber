import 'package:flutter/foundation.dart';
import '../models/video_model.dart';
import '../repositories/video_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:developer' as dev;

class VideoFeedProvider with ChangeNotifier {
  // final VideoFeedService _feedService;
  final VideoRepository _videoRepository;
  final FirebaseAuth _auth;
  final bool _isPaused = false;

  Video? _currentVideo;
  List<Video> _videos = [];
  int _currentIndex = 0;
  bool _isLoading = false;
  bool _isEnabled = true;
  bool _hasUserInteractedWithAudio = false;
  
  String? _error;
  // String _feedType = 'for_you'; // Default feed type
  bool _hasLiked = false;
  // WatchSession? _currentSession;
  Timer? _positionUpdateTimer;

  VideoFeedProvider({
    // VideoFeedService? feedService,
    VideoRepository? videoRepository,
    FirebaseAuth? auth,
  }) : _videoRepository = videoRepository ?? VideoRepository(),
       _auth = auth ?? FirebaseAuth.instance {
    _loadAllVideos();
  }

  Video? get currentVideo => _currentVideo;
  bool get isLoading => _isLoading;
  String? get error => _error;
  // String get feedType => _feedType;
  // WatchSession? get currentSession => _currentSession;
  bool get hasLiked => _hasLiked;
  bool get isPaused => _isPaused;
  bool get hasUserInteractedWithAudio => _hasUserInteractedWithAudio;
  bool get canGoBack => _currentIndex > 0;

  void setEnabled(bool enabled) {
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;
    
    // Schedule notification for after the build phase
    Future.microtask(() {
      notifyListeners();
    });
  }

  Future<void> _loadAllVideos() async {
    dev.log('Loading all videos', name: 'VideoFeedProvider');
    _setLoading(true);
    
    try {
      final snapshot = await _videoRepository.getAllVideos();
      _videos = snapshot.docs
        .map((doc) => Video.fromFirestore(doc))
        .where((video) => video.processingStatus == VideoProcessingStatus.completed)
        .toList();
      
      if (_videos.isNotEmpty) {
        _currentVideo = _videos[0];
        await _checkLikeStatus();
      }
      
      _error = null;
    } catch (e) {
      dev.log('Error loading videos', name: 'VideoFeedProvider', error: e);
      _error = 'Error loading videos: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> moveToNextVideo() async {
    dev.log('Moving to next video. Current index: $_currentIndex', name: 'VideoFeedProvider');
    if (_videos.isEmpty) return;
    
    _currentIndex = (_currentIndex + 1) % _videos.length;
    _currentVideo = _videos[_currentIndex];
    await _checkLikeStatus();
    notifyListeners();
    dev.log('Next video: ${_currentVideo?.id}', name: 'VideoFeedProvider');
  }

  Future<void> moveToPreviousVideo() async {
    dev.log('Moving to previous video. Current index: $_currentIndex', name: 'VideoFeedProvider');
    if (_videos.isEmpty || _currentIndex <= 0) return;
    
    _currentIndex--;
    _currentVideo = _videos[_currentIndex];
    await _checkLikeStatus();
    notifyListeners();
    dev.log('Previous video: ${_currentVideo?.id}', name: 'VideoFeedProvider');
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
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

  }

  void markUserInteractedWithAudio() {
    _hasUserInteractedWithAudio = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionUpdateTimer?.cancel();
    super.dispose();
  }
} 