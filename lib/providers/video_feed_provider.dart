import 'package:flutter/foundation.dart';
import '../models/video_model.dart';
import '../services/video_feed_service.dart';

class VideoFeedProvider with ChangeNotifier {
  final VideoFeedService _feedService;
  Video? _currentVideo;
  Video? _nextVideo;
  bool _isLoading = false;
  String? _error;
  String _feedType = 'for_you'; // Default feed type

  VideoFeedProvider({VideoFeedService? feedService}) 
      : _feedService = feedService ?? VideoFeedService() {
    _initializeVideos();
  }

  Video? get currentVideo => _currentVideo;
  Video? get nextVideo => _nextVideo;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get feedType => _feedType;

  Future<void> _initializeVideos() async {
    _setLoading(true);
    try {
      // Load first video
      _currentVideo = await _feedService.getNextVideo();
      
      if (_currentVideo != null) {
        // Pre-fetch next video
        _nextVideo = await _feedService.getNextVideo();
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
    if (_isLoading) return;
    
    _setLoading(true);
    try {
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

  void resetFeed() {
    _feedService.resetFeed();
    _currentVideo = null;
    _nextVideo = null;
    _error = null;
    _initializeVideos();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setFeedType(String type) {
    if (type != _feedType) {
      _feedType = type;
      _feedService.resetFeed();
      _currentVideo = null;
      _nextVideo = null;
      _error = null;
      _initializeVideos();
    }
  }
} 