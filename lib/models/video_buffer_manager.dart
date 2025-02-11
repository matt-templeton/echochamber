import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'dart:developer' as dev;
import 'video_model.dart';

/// Priority levels for buffer requests
enum BufferPriority {
  high,    // Current video
  medium,  // Next video preload
  low      // Future video preloads
}

/// Represents a video buffer request
class BufferRequest {
  final Video video;
  final BufferPriority priority;
  final DateTime timestamp;

  BufferRequest({
    required this.video,
    required this.priority,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Configuration for buffer pools
class BufferPoolConfig {
  final int initialSize;
  final int maxSize;
  final Duration retentionPeriod;

  const BufferPoolConfig({
    required this.initialSize,
    required this.maxSize,
    this.retentionPeriod = const Duration(seconds: 30),
  });
}

/// Manages the buffering of videos with priority handling and performance optimization
class VideoBufferManager extends ChangeNotifier {
  final Map<String, VideoPlayerController> _bufferedVideos = {};
  final Map<String, double> _bufferProgress = {};
  String? _currentVideoId;
  bool _isProcessingRequest = false;

  // Getters
  bool get isBuffering => _isProcessingRequest;
  Map<String, double> get bufferProgress => Map.unmodifiable(_bufferProgress);
  bool hasBufferedVideo(String videoId) => _bufferedVideos.containsKey(videoId);
  
  /// Adds a video to the buffer, replacing any existing video
  Future<void> addToBuffer(Video video) async {
    dev.log('Adding video to buffer: ${video.id}', name: 'VideoBufferManager');
    
    if (_isProcessingRequest) {
      dev.log('Already processing a request', name: 'VideoBufferManager');
      return;
    }

    _isProcessingRequest = true;
    
    try {
      // Clear existing video if different
      if (_currentVideoId != null && _currentVideoId != video.id) {
        await _removeFromBuffer(_currentVideoId!);
      }

      if (_bufferedVideos.containsKey(video.id)) {
        dev.log('Video already buffered: ${video.id}', name: 'VideoBufferManager');
        return;
      }

      _currentVideoId = video.id;
      
      // Initialize new controller
      dev.log('Initializing controller for: ${video.id}', name: 'VideoBufferManager');
      final controller = VideoPlayerController.network(
        video.videoUrl,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      try {
        await controller.initialize();
        _bufferedVideos[video.id] = controller;
        _bufferProgress[video.id] = 1.0;
        dev.log('Video added to buffer: ${video.id}', name: 'VideoBufferManager');
      } catch (e, stackTrace) {
        dev.log('Error initializing controller', 
          name: 'VideoBufferManager',
          error: e,
          stackTrace: stackTrace);
        await controller.dispose();
        rethrow;
      }
      
    } finally {
      _isProcessingRequest = false;
      notifyListeners();
    }
  }

  /// Updates the buffer progress for a specific video
  void updateBufferProgress(String videoId, double progress) {
    if (progress < 0.0 || progress > 1.0) {
      dev.log('Invalid buffer progress value: $progress', name: 'VideoBufferManager');
      return;
    }

    _bufferProgress[videoId] = progress;
    notifyListeners();
  }

  /// Retrieves a buffered video controller
  VideoPlayerController? getBufferedVideo(String videoId) {
    return _bufferedVideos[videoId];
  }

  Future<void> _removeFromBuffer(String videoId) async {
    dev.log('Removing video from buffer: $videoId', name: 'VideoBufferManager');
    
    final controller = _bufferedVideos.remove(videoId);
    if (controller != null) {
      await controller.pause();
      await controller.dispose();
    }
    _bufferProgress.remove(videoId);
    
    if (_currentVideoId == videoId) {
      _currentVideoId = null;
    }
    
    notifyListeners();
  }

  @override
  void dispose() {
    for (final controller in _bufferedVideos.values) {
      controller.dispose();
    }
    _bufferedVideos.clear();
    _bufferProgress.clear();
    super.dispose();
  }
}

/// Memory information structure
class MemoryInfo {
  final int total;
  final int used;
  final int free;

  const MemoryInfo({
    required this.total,
    required this.used,
    required this.free,
  });
}

Future<MemoryInfo> _getMemoryInfo() async {
  // This is a placeholder implementation
  // In a real app, you would get actual memory info from the platform
  return const MemoryInfo(
    total: 1024 * 1024 * 1024,  // 1GB
    used: 512 * 1024 * 1024,    // 512MB
    free: 512 * 1024 * 1024,    // 512MB
  );
} 