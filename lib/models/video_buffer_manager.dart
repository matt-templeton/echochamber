import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'video_model.dart';
import 'dart:collection';
import 'dart:developer' as dev;

/// Priority levels for buffer requests
enum BufferPriority {
  high,    // Swipe-triggered loads
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

/// Manages the buffering of videos with priority handling
class VideoBufferManager extends ChangeNotifier {
  final Map<String, VideoPlayerController> _bufferedVideos = {};
  final Map<String, double> _bufferProgress = {};
  final Queue<BufferRequest> _bufferQueue = Queue<BufferRequest>();
  final int maxBufferedVideos;
  bool _isProcessingQueue = false;

  VideoBufferManager({
    this.maxBufferedVideos = 3,
  }) : assert(maxBufferedVideos > 0, 'maxBufferedVideos must be greater than 0');

  // Getters
  bool get isBuffering => _isProcessingQueue;
  Map<String, double> get bufferProgress => Map.unmodifiable(_bufferProgress);
  bool hasBufferedVideo(String videoId) => _bufferedVideos.containsKey(videoId);

  /// Updates the buffer progress for a specific video
  void updateBufferProgress(String videoId, double progress) {
    if (progress < 0.0 || progress > 1.0) {
      dev.log('Invalid buffer progress value: $progress', name: 'VideoBufferManager');
      return;
    }

    _bufferProgress[videoId] = progress;
    notifyListeners();
  }

  /// Adds a video to the buffer with specified priority
  Future<void> addToBuffer(Video video, BufferPriority priority) async {
    dev.log('Adding video to buffer: ${video.id} with priority: $priority', name: 'VideoBufferManager');
    
    // If already buffered or in queue, update priority if higher
    if (_bufferedVideos.containsKey(video.id)) {
      dev.log('Video already buffered: ${video.id}', name: 'VideoBufferManager');
      return;
    }

    // Create buffer request
    final request = BufferRequest(
      video: video,
      priority: priority,
    );

    // Add to queue based on priority
    _addToQueueWithPriority(request);
    
    // Start processing queue if not already processing
    if (!_isProcessingQueue) {
      _processBufferQueue();
    }
  }

  /// Retrieves a buffered video controller
  VideoPlayerController? getBufferedVideo(String videoId) {
    return _bufferedVideos[videoId];
  }

  /// Gets the buffer progress for a video
  double getBufferProgressForVideo(String videoId) {
    return _bufferProgress[videoId] ?? 0.0;
  }

  /// Clears old buffers when limit is reached
  void _clearOldBuffers() {
    if (_bufferedVideos.length <= maxBufferedVideos) return;

    dev.log('Clearing old buffers', name: 'VideoBufferManager');
    
    // Sort videos by last access time and remove oldest
    final oldestVideos = _bufferedVideos.entries
        .toList()
        .sublist(0, _bufferedVideos.length - maxBufferedVideos);

    for (final entry in oldestVideos) {
      _removeFromBuffer(entry.key);
    }
  }

  /// Removes a video from buffer
  void _removeFromBuffer(String videoId) {
    dev.log('Removing video from buffer: $videoId', name: 'VideoBufferManager');
    
    final controller = _bufferedVideos.remove(videoId);
    _bufferProgress.remove(videoId);
    controller?.dispose();
    notifyListeners();
  }

  /// Adds a request to the queue with priority ordering
  void _addToQueueWithPriority(BufferRequest request) {
    // Remove any existing requests for the same video
    _bufferQueue.removeWhere((r) => r.video.id == request.video.id);

    // Find position to insert based on priority
    final index = _bufferQueue.toList().indexWhere(
      (r) => r.priority.index > request.priority.index
    );

    if (index == -1) {
      _bufferQueue.addLast(request);
    } else {
      final newQueue = Queue<BufferRequest>.from([
        ..._bufferQueue.take(index),
        request,
        ..._bufferQueue.skip(index),
      ]);
      _bufferQueue.clear();
      _bufferQueue.addAll(newQueue);
    }
  }

  /// Processes the buffer queue
  Future<void> _processBufferQueue() async {
    if (_isProcessingQueue || _bufferQueue.isEmpty) return;

    _isProcessingQueue = true;
    notifyListeners();

    try {
      while (_bufferQueue.isNotEmpty) {
        final request = _bufferQueue.first;
        
        // Initialize video controller with actual video URL
        final controller = VideoPlayerController.network(
          request.video.videoUrl,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );

        await controller.initialize();
        
        // Add to buffered videos
        _bufferedVideos[request.video.id] = controller;
        _bufferProgress[request.video.id] = 1.0; // Fully buffered
        
        _bufferQueue.removeFirst();
        _clearOldBuffers();
        notifyListeners();
      }
    } catch (e, stackTrace) {
      dev.log(
        'Error processing buffer queue',
        name: 'VideoBufferManager',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isProcessingQueue = false;
      notifyListeners();
    }
  }

  /// Cleans up resources
  @override
  void dispose() {
    for (final controller in _bufferedVideos.values) {
      controller.dispose();
    }
    _bufferedVideos.clear();
    _bufferProgress.clear();
    _bufferQueue.clear();
    super.dispose();
  }
} 