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
    if (_bufferedVideos.length <= maxBufferedVideos - 1) return;

    dev.log('Clearing old buffers', name: 'VideoBufferManager');
    dev.log('Current buffer size: ${_bufferedVideos.length}, Max allowed: $maxBufferedVideos', name: 'VideoBufferManager');
    
    // More aggressive cleanup - keep one slot free
    while (_bufferedVideos.length > maxBufferedVideos - 1) {
      // Find oldest video to remove
      final oldestVideo = _bufferedVideos.entries.first;
      dev.log('Removing old video from buffer: ${oldestVideo.key}', name: 'VideoBufferManager');
      _removeFromBuffer(oldestVideo.key);
    }
    
    dev.log('Buffer cleanup complete. New size: ${_bufferedVideos.length}', name: 'VideoBufferManager');
  }

  /// Removes a video from buffer
  void _removeFromBuffer(String videoId) {
    dev.log('Removing video from buffer: $videoId', name: 'VideoBufferManager');
    
    final controller = _bufferedVideos.remove(videoId);
    if (controller != null) {
      // Ensure controller is paused before disposal
      controller.pause().then((_) {
        controller.dispose();
      });
    }
    _bufferProgress.remove(videoId);
    notifyListeners();
  }

  /// Adds a request to the queue with priority ordering
  void _addToQueueWithPriority(BufferRequest request) {
    dev.log('Adding to buffer queue: ${request.video.id}', name: 'VideoBufferManager');
    dev.log('Priority: ${request.priority}', name: 'VideoBufferManager');
    
    // Remove any existing requests for the same video
    final existingCount = _bufferQueue.where((r) => r.video.id == request.video.id).length;
    _bufferQueue.removeWhere((r) => r.video.id == request.video.id);
    if (existingCount > 0) {
      dev.log('Removed existing queue entry for: ${request.video.id}', name: 'VideoBufferManager');
    }

    // Find position to insert based on priority
    final index = _bufferQueue.toList().indexWhere(
      (r) => r.priority.index > request.priority.index
    );

    if (index == -1) {
      _bufferQueue.addLast(request);
      dev.log('Added to end of queue: ${request.video.id}', name: 'VideoBufferManager');
    } else {
      final newQueue = Queue<BufferRequest>.from([
        ..._bufferQueue.take(index),
        request,
        ..._bufferQueue.skip(index),
      ]);
      _bufferQueue.clear();
      _bufferQueue.addAll(newQueue);
      dev.log('Inserted into queue at position $index: ${request.video.id}', name: 'VideoBufferManager');
    }
    
    dev.log('Current queue size: ${_bufferQueue.length}', name: 'VideoBufferManager');
    dev.log('Queue order: ${_bufferQueue.map((r) => "${r.video.id}(${r.priority})").join(", ")}', name: 'VideoBufferManager');
  }

  /// Processes the buffer queue
  Future<void> _processBufferQueue() async {
    if (_isProcessingQueue || _bufferQueue.isEmpty) return;

    _isProcessingQueue = true;
    dev.log('Starting buffer queue processing', name: 'VideoBufferManager');
    dev.log('Current buffer queue size: ${_bufferQueue.length}', name: 'VideoBufferManager');
    dev.log('Currently buffered videos: ${_bufferedVideos.keys.join(", ")}', name: 'VideoBufferManager');
    notifyListeners();

    try {
      while (_bufferQueue.isNotEmpty) {
        final request = _bufferQueue.first;
        dev.log('Processing buffer request for video: ${request.video.id}', name: 'VideoBufferManager');
        dev.log('Buffer priority: ${request.priority}', name: 'VideoBufferManager');
        
        // Initialize video controller with actual video URL
        dev.log('Initializing controller for: ${request.video.id}', name: 'VideoBufferManager');
        final controller = VideoPlayerController.network(
          request.video.videoUrl,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );

        try {
          await controller.initialize();
          dev.log('Controller initialization successful for: ${request.video.id}', name: 'VideoBufferManager');
        } catch (e) {
          dev.log('Controller initialization failed for: ${request.video.id}', name: 'VideoBufferManager', error: e);
          continue;
        }
        
        // Add to buffered videos
        _bufferedVideos[request.video.id] = controller;
        _bufferProgress[request.video.id] = 1.0; // Fully buffered
        dev.log('Video added to buffer: ${request.video.id}', name: 'VideoBufferManager');
        
        _bufferQueue.removeFirst();
        dev.log('Removed from queue: ${request.video.id}', name: 'VideoBufferManager');
        dev.log('Remaining queue size: ${_bufferQueue.length}', name: 'VideoBufferManager');
        
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
      dev.log('Buffer queue processing completed', name: 'VideoBufferManager');
      dev.log('Final buffered videos: ${_bufferedVideos.keys.join(", ")}', name: 'VideoBufferManager');
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