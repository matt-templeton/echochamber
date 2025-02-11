import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../../models/video_model.dart';
import 'dart:async';
import 'dart:developer' as dev;

class HLSVideoPlayer extends StatefulWidget {
  final Video video;
  final VideoPlayerController? preloadedController;
  final bool autoplay;
  final bool showControls;
  final Function(double)? onBufferProgress;
  final Function(bool)? onPlayingStateChanged;
  final VoidCallback? onVideoEnd;
  final VoidCallback? onError;

  const HLSVideoPlayer({
    Key? key,
    required this.video,
    this.preloadedController,
    this.autoplay = true,
    this.showControls = true,
    this.onBufferProgress,
    this.onPlayingStateChanged,
    this.onVideoEnd,
    this.onError,
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
  double _aspectRatio = 16 / 9;
  Timer? _bufferCheckTimer;
  final _initializationCompleter = Completer<void>();

  Future<void> get initialized => _initializationCompleter.future;

  @override
  void initState() {
    super.initState();
    dev.log('HLSVideoPlayer initState - videoId: ${widget.video.id}', name: 'HLSVideoPlayer');
    
    if (widget.preloadedController != null) {
      _controller = widget.preloadedController!;
      _onControllerInitialized();
    } else {
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    dev.log('Starting player initialization - videoId: ${widget.video.id}', name: 'HLSVideoPlayer');
    
    try {
      dev.log('Creating controller for URL: ${widget.video.videoUrl}', name: 'HLSVideoPlayer');
      _controller = VideoPlayerController.network(
        widget.video.videoUrl,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );

      await _controller.initialize();
      if (!mounted) return;
      
      _onControllerInitialized();
    } catch (e, stackTrace) {
      dev.log('Error initializing video player: $e', name: 'HLSVideoPlayer', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isError = true);
        widget.onError?.call();
      }
      _initializationCompleter.completeError(e);
    }
  }

  void _onControllerInitialized() {
    setState(() {
      _isInitialized = true;
      _aspectRatio = _controller.value.aspectRatio;
    });

    // Start buffer progress tracking
    _startBufferCheck();

    // Listen for video completion
    _controller.addListener(_onVideoProgress);

    // Start playing if autoplay is enabled
    if (widget.autoplay) {
      _controller.play();
      widget.onPlayingStateChanged?.call(true);
    }

    _initializationCompleter.complete();
  }

  void _startBufferCheck() {
    _bufferCheckTimer?.cancel();
    _bufferCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || !_controller.value.isInitialized) return;

      final buffered = _controller.value.buffered;
      if (buffered.isEmpty) return;

      // Calculate buffer progress as percentage of video duration
      final duration = _controller.value.duration.inMilliseconds;
      final bufferedMs = buffered.fold<int>(0, (sum, range) => 
        sum + (range.end - range.start).inMilliseconds
      );
      final progress = bufferedMs / duration;
      
      widget.onBufferProgress?.call(progress);
    });
  }

  void _onVideoProgress() {
    if (!mounted || !_controller.value.isInitialized) return;

    if (_controller.value.hasError) {
      dev.log('Video controller reported error', name: 'HLSVideoPlayer', error: _controller.value.errorDescription);
      return;
    }

    // Check for video completion
    if (_controller.value.position >= _controller.value.duration) {
      dev.log('Video reached end', name: 'HLSVideoPlayer');
      widget.onVideoEnd?.call();
    }

    // Update buffering state
    final isBuffering = _controller.value.isBuffering;
    if (_isBuffering != isBuffering) {
      setState(() => _isBuffering = isBuffering);
    }

    // Force rebuild to update progress bar
    if (mounted) {
      setState(() {});
    }
  }

  /// Switches to a new video
  Future<void> switchToVideo(Video newVideo, {VideoPlayerController? preloadedController}) async {
    dev.log('Switching to video: ${newVideo.id}', name: 'HLSVideoPlayer');
    
    // Keep track of old controller for cleanup
    final oldController = _controller;
    VideoPlayerController? newController;
    
    try {
      // First pause old controller
      dev.log('Pausing old controller', name: 'HLSVideoPlayer');
      await oldController.pause();
      oldController.removeListener(_onVideoProgress);
      
      // Initialize new controller
      if (preloadedController != null) {
        dev.log('Using preloaded controller for video: ${newVideo.id}', name: 'HLSVideoPlayer');
        newController = preloadedController;
      } else {
        dev.log('Creating new controller for video: ${newVideo.id}', name: 'HLSVideoPlayer');
        newController = VideoPlayerController.network(
          newVideo.videoUrl,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
        dev.log('Initializing new controller', name: 'HLSVideoPlayer');
        await newController.initialize();
      }

      if (!mounted) {
        dev.log('Widget unmounted during controller switch', name: 'HLSVideoPlayer');
        await newController.dispose();
        return;
      }

      // Set up new controller before disposing old one
      setState(() {
        _controller = newController!;  // We know it's not null at this point
        _isInitialized = true;
        _isError = false;
        _aspectRatio = newController.value.aspectRatio;
      });

      // Start buffer progress tracking for new video
      _startBufferCheck();
      
      // Setup listeners for new controller
      newController.addListener(_onVideoProgress);

      // Start playing if autoplay is enabled
      if (widget.autoplay) {
        await newController.play();
        widget.onPlayingStateChanged?.call(true);
      }

      // Only dispose old controller after new one is fully set up
      dev.log('Disposing old controller', name: 'HLSVideoPlayer');
      await oldController.dispose();

    } catch (e, stackTrace) {
      dev.log('Error switching video', name: 'HLSVideoPlayer', error: e, stackTrace: stackTrace);
      // If we failed to set up the new controller, keep the old one active
      if (newController != null) {
        await newController.dispose();
      }
      setState(() => _isError = true);
      widget.onError?.call();
      rethrow;
    }
  }

  /// Ensures video is playing and controls are properly initialized
  Future<void> ensurePlayback() async {
    if (!mounted || !_isInitialized) return;

    dev.log('Ensuring video playback', name: 'HLSVideoPlayer');
    
    try {
      if (!_controller.value.isPlaying) {
        await _controller.play();
        widget.onPlayingStateChanged?.call(true);
      }
      
      // Reset controls state
      setState(() {
        _showControls = false;
        _isBuffering = false;
      });
    } catch (e, stackTrace) {
      dev.log('Error ensuring playback', name: 'HLSVideoPlayer', error: e, stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    dev.log('Disposing HLSVideoPlayer - videoId: ${widget.video.id}', name: 'HLSVideoPlayer');
    _bufferCheckTimer?.cancel();
    _controller.removeListener(_onVideoProgress);
    
    // Dispose controller in background to avoid blocking
    Future.microtask(() async {
      await _controller.dispose();
    });
    
    super.dispose();
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
                    widget.onPlayingStateChanged?.call(false);
                    setState(() => _showControls = true);
                  } else {
                    _controller.play();
                    widget.onPlayingStateChanged?.call(true);
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
            ),
          );
        },
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
      8.0,
      paint,
    );
  }

  @override
  bool shouldRepaint(VideoProgressBarPainter oldDelegate) {
    return progress != oldDelegate.progress ||
           buffered != oldDelegate.buffered;
  }
} 