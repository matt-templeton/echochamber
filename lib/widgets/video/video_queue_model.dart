import 'package:flutter/foundation.dart';
import '../../models/video_model.dart';
import 'dart:developer' as dev;

class VideoQueueModel extends ChangeNotifier {
  final int queueSize;
  final List<Video> _videos = [];
  int _currentIndex = 0;
  bool _isLoading = false;

  VideoQueueModel({
    required this.queueSize,
  }) : assert(queueSize >= 3, 'Queue size must be at least 3'),
       assert(queueSize % 2 == 1, 'Queue size must be odd');

  // Getters
  Video? get currentVideo => _videos.isNotEmpty ? _videos[_currentIndex] : null;
  Video? get nextVideo => hasNextVideo ? _videos[_currentIndex + 1] : null;
  Video? get previousVideo => hasPreviousVideo ? _videos[_currentIndex - 1] : null;
  bool get hasNextVideo => _currentIndex < _videos.length - 1;
  bool get hasPreviousVideo => _currentIndex > 0;
  bool get isLoading => _isLoading;
  List<Video> get videos => List.unmodifiable(_videos);
  int get currentIndex => _currentIndex;

  // Queue Management
  void addVideo(Video video) {
    dev.log('Adding video to queue: ${video.id}', name: 'VideoQueueModel');
    _videos.add(video);
    notifyListeners();
  }

  void removeFirst() {
    if (_videos.isNotEmpty) {
      dev.log('Removing first video from queue: ${_videos.first.id}', name: 'VideoQueueModel');
      _videos.removeAt(0);
      if (_currentIndex > 0) _currentIndex--;
      notifyListeners();
    }
  }

  void removeLast() {
    if (_videos.isNotEmpty) {
      dev.log('Removing last video from queue: ${_videos.last.id}', name: 'VideoQueueModel');
      _videos.removeLast();
      if (_currentIndex >= _videos.length) _currentIndex = _videos.length - 1;
      notifyListeners();
    }
  }

  // Navigation
  void moveToNext() {
    if (hasNextVideo && !_isLoading) {
      dev.log('Moving to next video', name: 'VideoQueueModel');
      _currentIndex++;
      notifyListeners();
    }
  }

  void moveToPrevious() {
    if (hasPreviousVideo && !_isLoading) {
      dev.log('Moving to previous video', name: 'VideoQueueModel');
      _currentIndex--;
      notifyListeners();
    }
  }

  // Loading State
  void setLoading(bool loading) {
    if (_isLoading != loading) {
      dev.log('Setting loading state: $loading', name: 'VideoQueueModel');
      _isLoading = loading;
      notifyListeners();
    }
  }

  // Queue Maintenance
  void trimQueue() {
    while (_videos.length > queueSize) {
      if (_currentIndex > queueSize ~/ 2) {
        removeFirst();
      } else {
        removeLast();
      }
    }
  }

  // Reset
  void reset() {
    dev.log('Resetting video queue', name: 'VideoQueueModel');
    _videos.clear();
    _currentIndex = 0;
    _isLoading = false;
    notifyListeners();
  }
} 