import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../../models/video_model.dart';
import '../../providers/video_feed_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:developer' as dev;

class HLSVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String videoId;
  final bool autoplay;
  final bool showControls;
  final VoidCallback? onVideoEnd;
  final VoidCallback? onError;

  const HLSVideoPlayer({
    Key? key,
    required this.videoUrl,
    required this.videoId,
    this.autoplay = true,
    this.showControls = true,
    this.onVideoEnd,
    this.onError,
  }) : super(key: key);

  @override
  State<HLSVideoPlayer> createState() => _HLSVideoPlayerState();
}

class _HLSVideoPlayerState extends State<HLSVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isError = false;
  bool _isBuffering = false;
  bool _showControls = false;
  bool _isDragging = false;
  double _dragProgress = 0.0;
  double _aspectRatio = 16 / 9;
  Timer? _positionUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _controller = VideoPlayerController.network(
        widget.videoUrl,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
        ),
      );

      await _controller.initialize();
      
      setState(() {
        _isInitialized = true;
        _aspectRatio = _controller.value.aspectRatio;
      });

      // Notify provider that controller is ready
      if (context.mounted) {
        context.read<VideoFeedProvider>().setControllerReady(true);
      }

      // Start watch session and position updates
      final provider = context.read<VideoFeedProvider>();
      await provider.onVideoStarted(widget.videoId);
      _startPositionUpdates();

      // Listen for video completion
      _controller.addListener(_onVideoProgress);

      // Start playing immediately if autoplay is true
      if (widget.autoplay && mounted) {
        await _controller.play();
      }

    } catch (e) {
      setState(() => _isError = true);
      widget.onError?.call();
      print('Error initializing video player: $e');
    }
  }

  void _startPositionUpdates() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_controller.value.isPlaying) {
        final provider = context.read<VideoFeedProvider>();
        provider.updateWatchPosition(_controller.value.position);
      }
    });
  }

  void _onVideoProgress() {
    if (_controller.value.position >= _controller.value.duration) {
      final provider = context.read<VideoFeedProvider>();
      provider.onVideoEnded();
      widget.onVideoEnd?.call();
    }

    // Update buffering state
    final bool isBuffering = _controller.value.isBuffering;
    if (_isBuffering != isBuffering) {
      setState(() => _isBuffering = isBuffering);
    }

    // Force rebuild to update progress bar position
    if (mounted && !_isDragging) {
      setState(() {});
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
      
      // Ensure position is saved before cleanup
      if (mounted && _controller.value.isInitialized) {
        final provider = context.read<VideoFeedProvider>();
        provider.updateWatchPosition(_controller.value.position);
      }
      
      dev.log('Video player resources cleaned up', name: 'HLSVideoPlayer');
    } catch (e) {
      dev.log('Error during cleanup: $e', name: 'HLSVideoPlayer', error: e);
    }
  }

  @override
  void dispose() {
    dev.log('Disposing video player', name: 'HLSVideoPlayer');
    _positionUpdateTimer?.cancel();
    _controller.removeListener(_onVideoProgress);
    
    // Ensure we pause before disposing to prevent surface issues
    try {
      if (_controller.value.isPlaying) {
        _controller.pause();
      }
      
      // Reset controller ready state when disposing
      if (mounted) {
        try {
          context.read<VideoFeedProvider>().setControllerReady(false);
        } catch (e) {
          dev.log('Error resetting controller state: $e', name: 'HLSVideoPlayer');
        }
      }

      // Ensure proper cleanup sequence
      _controller.dispose();
    } catch (e) {
      dev.log('Error disposing video controller: $e', name: 'HLSVideoPlayer');
    }
    
    super.dispose();
  }

  @override
  void deactivate() {
    dev.log('Deactivating video player', name: 'HLSVideoPlayer');
    _cleanupResources();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isError) {
      return const Center(
        child: Icon(Icons.error_outline, color: Colors.red, size: 48),
      );
    }

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
            // Always show progress bar at the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildProgressBar(),
            ),
            // Show controls overlay when _showControls is true
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
      onHorizontalDragStart: (details) {
        setState(() {
          _isDragging = true;
          _dragProgress = details.localPosition.dx / context.size!.width;
        });
        _controller.pause();
      },
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragProgress = details.localPosition.dx / context.size!.width;
          _dragProgress = _dragProgress.clamp(0.0, 1.0);
        });
      },
      onHorizontalDragEnd: (details) async {
        final duration = _controller.value.duration;
        final targetPosition = duration * _dragProgress;
        
        setState(() {
          _isDragging = false;
        });
        
        await _controller.seekTo(targetPosition);
        _controller.play();
      },
    );
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