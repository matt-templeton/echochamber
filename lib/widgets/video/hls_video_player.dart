import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../../providers/video_feed_provider.dart';
import 'dart:async';
import 'dart:developer' as dev;

class HLSVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String videoId;
  final bool autoplay;
  final bool showControls;
  final bool shouldPlay;
  final bool isVisible;
  final Function(bool)? onPlayingStateChanged;
  final VoidCallback? onVideoEnd;
  final VoidCallback? onError;
  final GlobalKey<HLSVideoPlayerState> playerKey;

  HLSVideoPlayer({
    Key? key,
    required this.videoUrl,
    required this.videoId,
    this.autoplay = true,
    this.showControls = true,
    this.shouldPlay = true,
    this.isVisible = true,
    this.onPlayingStateChanged,
    this.onVideoEnd,
    this.onError,
  }) : playerKey = key as GlobalKey<HLSVideoPlayerState>? ?? GlobalKey<HLSVideoPlayerState>(),
       super(key: key);

  void pause() {
    // This will be handled by the state
  }

  void updateState({required bool shouldPlay, required bool isVisible}) {
    // This will be handled by the state
  }

  @override
  State<HLSVideoPlayer> createState() => HLSVideoPlayerState();
}

class HLSVideoPlayerState extends State<HLSVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isError = false;
  bool _isBuffering = false;
  bool _showControls = false;
  bool _isDragging = false;
  double _dragProgress = 0.0;
  double _aspectRatio = 16 / 9;
  Timer? _positionUpdateTimer;
  bool _shouldBeVisible = true;
  bool _shouldBePlaying = true;
  late VideoFeedProvider _videoFeedProvider;
  Completer<void>? _initializationCompleter;

  Future<void> waitForInitialization() async {
    if (_initializationCompleter != null) {
      await _initializationCompleter!.future;
    }
  }

  @override
  void initState() {
    super.initState();
    dev.log('HLSVideoPlayer initState - videoId: ${widget.videoId}, videoUrl: ${widget.videoUrl}', name: 'HLSVideoPlayer');
    dev.log('Initial state - shouldPlay: ${widget.shouldPlay}, isVisible: ${widget.isVisible}, autoplay: ${widget.autoplay}', name: 'HLSVideoPlayer');
    _shouldBeVisible = widget.isVisible;
    _shouldBePlaying = widget.shouldPlay;
    _videoFeedProvider = context.read<VideoFeedProvider>();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    dev.log('Starting player initialization - videoId: ${widget.videoId}, videoUrl: ${widget.videoUrl}', name: 'HLSVideoPlayer');
    _initializationCompleter = Completer<void>();
    
    try {
      dev.log('Creating controller for URL: ${widget.videoUrl}', name: 'HLSVideoPlayer');
      try {
        _controller = VideoPlayerController.network(
          widget.videoUrl,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false,
          ),
        );
        dev.log('Successfully created video controller', name: 'HLSVideoPlayer');
      } catch (e, stackTrace) {
        dev.log('Error creating video controller', name: 'HLSVideoPlayer', error: e, stackTrace: stackTrace);
        _initializationCompleter?.completeError(e);
        rethrow;
      }

      dev.log('Initializing controller', name: 'HLSVideoPlayer');
      try {
        await _controller.initialize();
        dev.log('Controller initialized successfully', name: 'HLSVideoPlayer');
      } catch (e, stackTrace) {
        dev.log('Error initializing controller', name: 'HLSVideoPlayer', error: e, stackTrace: stackTrace);
        _initializationCompleter?.completeError(e);
        rethrow;
      }
      
      if (!mounted) {
        dev.log('Widget not mounted after initialization', name: 'HLSVideoPlayer');
        _initializationCompleter?.completeError('Widget not mounted');
        return;
      }

      setState(() {
        _isInitialized = true;
        _aspectRatio = _controller.value.aspectRatio;
      });
      dev.log('State updated after initialization', name: 'HLSVideoPlayer');

      // Notify provider that controller is ready
      if (mounted) {
        dev.log('Setting controller ready state', name: 'HLSVideoPlayer');
        try {
          _videoFeedProvider.setControllerReady(true);
          dev.log('Controller ready state set successfully', name: 'HLSVideoPlayer');
        } catch (e, stackTrace) {
          dev.log('Error setting controller ready state', name: 'HLSVideoPlayer', error: e, stackTrace: stackTrace);
          _initializationCompleter?.completeError(e);
          return;
        }
      }

      // Start watch session and position updates
      if (mounted) {
        dev.log('Starting watch session', name: 'HLSVideoPlayer');
        try {
          await _videoFeedProvider.onVideoStarted(widget.videoId);
          _startPositionUpdates();
          dev.log('Watch session started successfully', name: 'HLSVideoPlayer');
        } catch (e, stackTrace) {
          dev.log('Error starting watch session', name: 'HLSVideoPlayer', error: e, stackTrace: stackTrace);
          _initializationCompleter?.completeError(e);
          return;
        }
      }

      // Listen for video completion
      _controller.addListener(_onVideoProgress);

      // Start playing if shouldPlay is true
      if (_shouldBePlaying && mounted) {
        dev.log('Starting playback - shouldPlay: $_shouldBePlaying', name: 'HLSVideoPlayer');
        try {
          await _controller.play();
          dev.log('Playback started successfully', name: 'HLSVideoPlayer');
          widget.onPlayingStateChanged?.call(true);
        } catch (e, stackTrace) {
          dev.log('Error starting playback', name: 'HLSVideoPlayer', error: e, stackTrace: stackTrace);
          // Don't complete with error here as initialization is technically successful
        }
      } else {
        dev.log('Not starting playback - shouldPlay: $_shouldBePlaying', name: 'HLSVideoPlayer');
      }

      _initializationCompleter?.complete();
    } catch (e, stackTrace) {
      dev.log('Error initializing video player: $e', name: 'HLSVideoPlayer', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isError = true);
        widget.onError?.call();
      }
      _initializationCompleter?.completeError(e);
    }
  }

  void _startPositionUpdates() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_controller.value.isPlaying) {
        _videoFeedProvider.updateWatchPosition(_controller.value.position);
      }
    });
  }

  void _onVideoProgress() {
    try {
      if (!mounted || !_controller.value.isInitialized) return;

      if (_controller.value.hasError) {
        dev.log('Video controller reported error', name: 'HLSVideoPlayer', error: _controller.value.errorDescription);
        return;
      }

      if (_controller.value.position >= _controller.value.duration) {
        dev.log('Video reached end', name: 'HLSVideoPlayer');
        _videoFeedProvider.onVideoEnded();
        widget.onVideoEnd?.call();
      }

      // Update buffering state
      final bool isBuffering = _controller.value.isBuffering;
      if (_isBuffering != isBuffering) {
        dev.log('Buffering state changed to: $isBuffering', name: 'HLSVideoPlayer');
        setState(() => _isBuffering = isBuffering);
      }

      // Force rebuild to update progress bar position
      if (mounted && !_isDragging) {
        setState(() {});
      }
    } catch (e, stackTrace) {
      dev.log('Error in video progress callback', name: 'HLSVideoPlayer', error: e, stackTrace: stackTrace);
    }
  }

  void _cleanupResources() {
    dev.log('Cleaning up video player resources', name: 'HLSVideoPlayer');
    _positionUpdateTimer?.cancel();
    
    try {
      // Ensure we stop playback first
      if (_controller.value.isPlaying) {
        _controller.pause();
      }
      
      // Cancel any pending operations
      _controller.removeListener(_onVideoProgress);
      
      dev.log('Video player resources cleaned up', name: 'HLSVideoPlayer');
    } catch (e) {
      dev.log('Error during cleanup: $e', name: 'HLSVideoPlayer', error: e);
    }
  }

  @override
  void deactivate() {
    dev.log('Deactivating video player', name: 'HLSVideoPlayer');
    // Handle provider state reset here instead of in dispose
    try {
      _videoFeedProvider.setControllerReady(false);
      _videoFeedProvider.cleanupVideoSession(widget.videoId);
    } catch (e, stackTrace) {
      dev.log('Error during deactivation cleanup', name: 'HLSVideoPlayer', error: e, stackTrace: stackTrace);
    }
    _cleanupResources();
    super.deactivate();
  }

  @override
  void dispose() {
    dev.log('Disposing HLSVideoPlayer - videoId: ${widget.videoId}', name: 'HLSVideoPlayer');
    _positionUpdateTimer?.cancel();
    _controller.removeListener(_onVideoProgress);
    
    try {
      if (_controller.value.isPlaying) {
        dev.log('Pausing video before disposal', name: 'HLSVideoPlayer');
        _controller.pause();
      }
      
      dev.log('Disposing video controller', name: 'HLSVideoPlayer');
      _controller.dispose();
    } catch (e, stackTrace) {
      dev.log('Error during disposal', name: 'HLSVideoPlayer', error: e, stackTrace: stackTrace);
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    dev.log('Building HLSVideoPlayer - videoId: ${widget.videoId}, initialized: $_isInitialized, error: $_isError, shouldBeVisible: $_shouldBeVisible', name: 'HLSVideoPlayer');
    
    if (!_shouldBeVisible) {
      dev.log('Returning empty container - player not visible', name: 'HLSVideoPlayer');
      return const SizedBox.shrink();
    }

    if (!_isInitialized) {
      dev.log('Returning loading indicator - player not initialized', name: 'HLSVideoPlayer');
      return const Center(child: CircularProgressIndicator());
    }

    if (_isError) {
      dev.log('Returning error indicator - player in error state', name: 'HLSVideoPlayer');
      return const Center(
        child: Icon(Icons.error_outline, color: Colors.red, size: 48),
      );
    }

    dev.log('Building full video player UI', name: 'HLSVideoPlayer');
    return GestureDetector(
      onTap: () {
        setState(() => _showControls = !_showControls);
      },
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: Stack(
          children: [
            VideoPlayer(_controller),
            if (_isBuffering)
              const Center(child: CircularProgressIndicator()),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildProgressBar(),
            ),
            if (_showControls && widget.showControls)
              _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.black26,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,  // Changed from spaceBetween
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.replay_10,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () {
                  final newPosition = _controller.value.position - const Duration(seconds: 10);
                  _controller.seekTo(newPosition);
                },
              ),
              const SizedBox(width: 20),
              IconButton(
                iconSize: 50,
                icon: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (_controller.value.isPlaying) {
                    _controller.pause();
                    setState(() => _showControls = true);
                  } else {
                    _controller.play();
                    setState(() => _showControls = false);
                  }
                },
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: const Icon(
                  Icons.forward_10,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () {
                  final newPosition = _controller.value.position + const Duration(seconds: 10);
                  _controller.seekTo(newPosition);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 20,
        color: Colors.black38,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final duration = _controller.value.duration;
            final position = _controller.value.position;
            
            // Use drag progress when dragging, otherwise use actual video position
            final progress = _isDragging
                ? _dragProgress
                : position.inMilliseconds / duration.inMilliseconds;

            return CustomPaint(
              painter: VideoProgressBarPainter(
                progress: progress,
                buffered: _controller.value.buffered.map((range) {
                  return BufferedRange(
                    start: range.start.inMilliseconds / duration.inMilliseconds,
                    end: range.end.inMilliseconds / duration.inMilliseconds,
                  );
                }).toList(),
                backgroundColor: Colors.white24,
                bufferedColor: Colors.white38,
                progressColor: Colors.white,
              ),
            );
          },
        ),
      ),
      onTapDown: (details) async {
        final tapPosition = details.localPosition.dx / context.size!.width;
        final duration = _controller.value.duration;
        final targetPosition = duration * tapPosition;
        
        setState(() {
          _dragProgress = tapPosition;  // Update the visual position immediately
        });
        
        await _controller.seekTo(targetPosition);
        setState(() {
          _dragProgress = tapPosition;  // Ensure the visual position is updated
        });
      },
      // onHorizontalDragStart: (details) {
      //   setState(() {
      //     _isDragging = true;
      //     _dragProgress = details.localPosition.dx / context.size!.width;
      //   });
      //   _controller.pause();
      // },
      // onHorizontalDragUpdate: (details) {
      //   setState(() {
      //     _dragProgress = details.localPosition.dx / context.size!.width;
      //     _dragProgress = _dragProgress.clamp(0.0, 1.0);
      //   });
      // },
      // onHorizontalDragEnd: (details) async {
      //   final duration = _controller.value.duration;
      //   final targetPosition = duration * _dragProgress;
        
      //   setState(() {
      //     _isDragging = false;
      //   });
        
      //   await _controller.seekTo(targetPosition);
      //   _controller.play();
      // },
    );
  }

  @override
  void didUpdateWidget(HLSVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    dev.log('didUpdateWidget called - videoId: ${widget.videoId}, old videoId: ${oldWidget.videoId}', name: 'HLSVideoPlayer');
    dev.log('State changes - shouldPlay: ${oldWidget.shouldPlay} -> ${widget.shouldPlay}, isVisible: ${oldWidget.isVisible} -> ${widget.isVisible}', name: 'HLSVideoPlayer');
    
    if (widget.videoUrl != oldWidget.videoUrl) {
      dev.log('Video URL changed - reinitializing player', name: 'HLSVideoPlayer');
      _cleanupResources();
      _initializePlayer();
      return;
    }

    if (widget.shouldPlay != oldWidget.shouldPlay) {
      dev.log('shouldPlay changed from ${oldWidget.shouldPlay} to ${widget.shouldPlay}', name: 'HLSVideoPlayer');
      _shouldBePlaying = widget.shouldPlay;
      if (_shouldBePlaying && _isInitialized) {
        dev.log('Playing video', name: 'HLSVideoPlayer');
        _controller.play();
        widget.onPlayingStateChanged?.call(true);
      } else if (!_shouldBePlaying && _isInitialized) {
        dev.log('Pausing video', name: 'HLSVideoPlayer');
        _controller.pause();
        widget.onPlayingStateChanged?.call(false);
      }
    }

    if (widget.isVisible != oldWidget.isVisible) {
      dev.log('isVisible changed from ${oldWidget.isVisible} to ${widget.isVisible}', name: 'HLSVideoPlayer');
      _shouldBeVisible = widget.isVisible;
      if (!_shouldBeVisible && _isInitialized && _controller.value.isPlaying) {
        dev.log('Pausing video due to visibility change', name: 'HLSVideoPlayer');
        _controller.pause();
        widget.onPlayingStateChanged?.call(false);
      }
    }
  }

  void updateState({required bool shouldPlay, required bool isVisible}) {
    if (!mounted) return;
    
    dev.log('Updating state - shouldPlay: $shouldPlay, isVisible: $isVisible', name: 'HLSVideoPlayer');
    _shouldBeVisible = isVisible;
    if (shouldPlay != _shouldBePlaying) {
      _shouldBePlaying = shouldPlay;
      if (_isInitialized) {
        if (_shouldBePlaying) {
          dev.log('Playing video from updateState', name: 'HLSVideoPlayer');
          _controller.play();
          widget.onPlayingStateChanged?.call(true);
        } else {
          dev.log('Pausing video from updateState', name: 'HLSVideoPlayer');
          _controller.pause();
          widget.onPlayingStateChanged?.call(false);
        }
      }
    }
  }

  void pause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
      _shouldBePlaying = false;
      widget.onPlayingStateChanged?.call(false);
    }
  }
}

class BufferedRange {
  final double start;
  final double end;

  BufferedRange({required this.start, required this.end});
}

class VideoProgressBarPainter extends CustomPainter {
  final double progress;
  final List<BufferedRange> buffered;
  final Color backgroundColor;
  final Color bufferedColor;
  final Color progressColor;

  VideoProgressBarPainter({
    required this.progress,
    required this.buffered,
    required this.backgroundColor,
    required this.bufferedColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    // Draw background
    paint.color = backgroundColor;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Draw buffered ranges
    paint.color = bufferedColor;
    for (final range in buffered) {
      canvas.drawLine(
        Offset(range.start * size.width, size.height / 2),
        Offset(range.end * size.width, size.height / 2),
        paint,
      );
    }

    // Draw progress
    paint.color = progressColor;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(progress * size.width, size.height / 2),
      paint,
    );

    // Draw progress indicator ball
    paint
      ..color = progressColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(progress * size.width, size.height / 2),
      8.0, // Radius of the ball
      paint,
    );
  }

  @override
  bool shouldRepaint(VideoProgressBarPainter oldDelegate) {
    return progress != oldDelegate.progress ||
           buffered != oldDelegate.buffered;
  }
} 