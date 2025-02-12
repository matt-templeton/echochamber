import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../../models/video_model.dart';
import '../../providers/video_feed_provider.dart';
import 'dart:async';
import 'dart:developer' as dev;

/// Represents a quality variant with its properties
class QualityVariant {
  final String quality;
  final int bitrate;
  final String url;

  const QualityVariant({
    required this.quality,
    required this.bitrate,
    required this.url,
  });
}

/// Performance metrics for video playback
class PlaybackMetrics {
  final double bufferHealth;
  final double playbackRate;
  final int droppedFrames;
  final Duration bufferDuration;
  final bool isBuffering;

  const PlaybackMetrics({
    required this.bufferHealth,
    required this.playbackRate,
    required this.droppedFrames,
    required this.bufferDuration,
    required this.isBuffering,
  });
}

class HLSVideoPlayer extends StatefulWidget {
  final Video video;
  final bool autoplay;
  final bool showControls;
  final VoidCallback? onVideoEnd;

  const HLSVideoPlayer({
    Key? key,
    required this.video,
    this.autoplay = true,
    this.showControls = true,
    this.onVideoEnd,
  }) : super(key: key);

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
  bool _wasPlayingBeforeDrag = false;
  bool _isDisposed = false;
  double _aspectRatio = 16 / 9;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    dev.log('Starting player initialization - videoId: ${widget.video.id}',
      name: 'HLSVideoPlayer');
    
    try {
      _controller = VideoPlayerController.network(
        widget.video.videoUrl,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      await _controller.initialize();
      if (!mounted) return;
      
      setState(() {
        _isInitialized = true;
        _aspectRatio = _controller.value.aspectRatio;
      });

      _controller.addListener(_onVideoProgress);

      if (widget.autoplay) {
        _controller.play();
      }

    } catch (e, stackTrace) {
      dev.log('Error initializing video player: $e',
        name: 'HLSVideoPlayer',
        error: e,
        stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isError = true);
      }
    }
  }

  void _onVideoProgress() {
    if (_isDisposed) return;
    if (!mounted || !_controller.value.isInitialized) return;

    if (_controller.value.hasError) {
      dev.log('Video controller reported error',
        name: 'HLSVideoPlayer',
        error: _controller.value.errorDescription);
      return;
    }

    if (_controller.value.position >= _controller.value.duration) {
      dev.log('Video reached end', name: 'HLSVideoPlayer');
      
      // Reset video position to beginning
      _controller.seekTo(Duration.zero);
      _controller.pause();
      
      
      // Move to next video
      context.read<VideoFeedProvider>().moveToNextVideo();
    }

    final isBuffering = _controller.value.isBuffering;
    if (_isBuffering != isBuffering && !_isDisposed) {
      setState(() => _isBuffering = isBuffering);
    }

    if (mounted && !_isDisposed) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HLSVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.video.id != oldWidget.video.id) {
      // Video changed, reinitialize player
      _controller.dispose();
      _initializePlayer();
    }
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
            if (_showControls && widget.showControls)
              _buildControls(),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildProgressBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.black26,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white, size: 30),
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
                icon: const Icon(Icons.forward_10, color: Colors.white, size: 30),
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
    return Container(
      height: 20,
      color: Colors.black38,
      child: GestureDetector(
        onHorizontalDragStart: (DragStartDetails details) {
          setState(() {
            _isDragging = true;
            _wasPlayingBeforeDrag = _controller.value.isPlaying;
          });
          if (_wasPlayingBeforeDrag) {
            _controller.pause();
          }
        },
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          if (!_isDragging) return;
          
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final double width = renderBox.size.width;
          final double localX = details.localPosition.dx;
          final double progress = localX / width;
          
          // Ensure progress is between 0 and 1
          final double clampedProgress = progress.clamp(0.0, 1.0);
          
          // Calculate the target position
          final Duration targetPosition = _controller.value.duration * clampedProgress;
          
          // Seek to the target position
          _controller.seekTo(targetPosition);
        },
        onHorizontalDragEnd: (DragEndDetails details) {
          if (_wasPlayingBeforeDrag) {
            _controller.play();
          }
          setState(() {
            _isDragging = false;
          });
        },
        onTapDown: (TapDownDetails details) {
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final double width = renderBox.size.width;
          final double localX = details.localPosition.dx;
          final double progress = localX / width;
          
          // Ensure progress is between 0 and 1
          final double clampedProgress = progress.clamp(0.0, 1.0);
          
          // Calculate the target position
          final Duration targetPosition = _controller.value.duration * clampedProgress;
          
          // Seek to the target position
          _controller.seekTo(targetPosition);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final duration = _controller.value.duration;
            final position = _controller.value.position;
            final progress = position.inMilliseconds / duration.inMilliseconds;

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
                isDragging: _isDragging,
              ),
            );
          },
        ),
      ),
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
  final bool isDragging;

  VideoProgressBarPainter({
    required this.progress,
    required this.buffered,
    required this.backgroundColor,
    required this.bufferedColor,
    required this.progressColor,
    this.isDragging = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    // Safely handle progress value
    final safeProgress = progress.isNaN || progress < 0.0 ? 0.0 : progress > 1.0 ? 1.0 : progress;

    // Draw background
    paint.color = backgroundColor;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Draw buffered ranges - safely handle each range
    paint.color = bufferedColor;
    for (final range in buffered) {
      final safeStart = range.start.isNaN || range.start < 0.0 ? 0.0 : range.start > 1.0 ? 1.0 : range.start;
      final safeEnd = range.end.isNaN || range.end < 0.0 ? 0.0 : range.end > 1.0 ? 1.0 : range.end;
      
      if (safeEnd > safeStart) {
        canvas.drawLine(
          Offset(safeStart * size.width, size.height / 2),
          Offset(safeEnd * size.width, size.height / 2),
          paint,
        );
      }
    }

    // Draw progress
    paint.color = progressColor;
    if (safeProgress > 0.0) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(safeProgress * size.width, size.height / 2),
        paint,
      );
    }

    // Draw progress indicator ball - only if we have valid progress
    if (!progress.isNaN && progress >= 0.0 && progress <= 1.0) {
      paint
        ..color = isDragging ? progressColor.withOpacity(0.7) : progressColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(safeProgress * size.width, size.height / 2),
        isDragging ? 10.0 : 8.0,  // Make the ball slightly larger while dragging
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(VideoProgressBarPainter oldDelegate) {
    return progress != oldDelegate.progress ||
           buffered != oldDelegate.buffered ||
           isDragging != oldDelegate.isDragging;
  }
} 