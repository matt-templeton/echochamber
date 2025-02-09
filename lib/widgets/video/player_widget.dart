import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:developer' as dev;

class PlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String videoId;
  final bool autoplay;
  final bool showControls;
  final Function(bool)? onPlayingStateChanged;
  final VoidCallback? onVideoEnd;
  final VoidCallback? onError;

  const PlayerWidget({
    Key? key,
    required this.videoUrl,
    required this.videoId,
    this.autoplay = true,
    this.showControls = true,
    this.onPlayingStateChanged,
    this.onVideoEnd,
    this.onError,
  }) : super(key: key);

  @override
  State<PlayerWidget> createState() => PlayerWidgetState();
}

class PlayerWidgetState extends State<PlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isError = false;
  bool _isBuffering = false;
  bool _showControls = false;
  double _aspectRatio = 16 / 9;
  Timer? _positionUpdateTimer;
  final _initializationCompleter = Completer<void>();

  Future<void> get initialized => _initializationCompleter.future;

  @override
  void initState() {
    super.initState();
    dev.log('PlayerWidget initState - videoId: ${widget.videoId}', name: 'PlayerWidget');
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    dev.log('Starting player initialization - videoId: ${widget.videoId}', name: 'PlayerWidget');
    
    try {
      // Create controller
      dev.log('Creating controller for URL: ${widget.videoUrl}', name: 'PlayerWidget');
      _controller = VideoPlayerController.network(
        widget.videoUrl,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );

      // Initialize controller
      dev.log('Initializing controller', name: 'PlayerWidget');
      await _controller!.initialize();
      dev.log('Controller initialized successfully', name: 'PlayerWidget');

      if (!mounted) {
        dev.log('Widget not mounted after initialization', name: 'PlayerWidget');
        return;
      }

      // Update state
      setState(() {
        _isInitialized = true;
        _aspectRatio = _controller!.value.aspectRatio;
      });

      // Setup video completion listener
      _controller!.addListener(_onVideoProgress);

      // Start playback if autoplay is enabled
      if (widget.autoplay && mounted) {
        dev.log('Starting autoplay', name: 'PlayerWidget');
        await play();
      }

      _initializationCompleter.complete();
    } catch (e, stackTrace) {
      dev.log('Error initializing player', name: 'PlayerWidget', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isError = true);
        widget.onError?.call();
      }
      _initializationCompleter.completeError(e);
    }
  }

  void _onVideoProgress() {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) return;

    // Handle errors
    if (_controller!.value.hasError) {
      dev.log('Video controller reported error', name: 'PlayerWidget', error: _controller!.value.errorDescription);
      return;
    }

    // Check for video completion
    if (_controller!.value.position >= _controller!.value.duration) {
      dev.log('Video reached end', name: 'PlayerWidget');
      widget.onVideoEnd?.call();
    }

    // Update buffering state
    final isBuffering = _controller!.value.isBuffering;
    if (_isBuffering != isBuffering) {
      setState(() => _isBuffering = isBuffering);
    }

    // Force rebuild to update progress bar
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> play() async {
    if (_controller != null && _isInitialized) {
      await _controller!.play();
      widget.onPlayingStateChanged?.call(true);
    }
  }

  Future<void> pause() async {
    if (_controller != null && _isInitialized) {
      await _controller!.pause();
      widget.onPlayingStateChanged?.call(false);
    }
  }

  Future<void> seekTo(Duration position) async {
    if (_controller != null && _isInitialized) {
      await _controller!.seekTo(position);
    }
  }

  Future<void> changeVideo(String videoUrl, String videoId) async {
    dev.log('Changing video - new videoId: $videoId', name: 'PlayerWidget');
    
    // Pause current playback
    await pause();
    
    // Dispose current controller
    await _cleanupCurrentController();
    
    // Update widget values
    if (mounted) {
      setState(() {
        _isInitialized = false;
        _isError = false;
      });
    }
    
    // Initialize new video
    await _initializePlayer();
  }

  Future<void> _cleanupCurrentController() async {
    if (_controller != null) {
      _controller!.removeListener(_onVideoProgress);
      await _controller!.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    dev.log('Disposing PlayerWidget - videoId: ${widget.videoId}', name: 'PlayerWidget');
    _cleanupCurrentController();
    _positionUpdateTimer?.cancel();
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final videoWidth = _controller!.value.size.width;
          final videoHeight = _controller!.value.size.height;
          final scale = constraints.maxWidth / videoWidth;
          final scaledHeight = videoHeight * scale;
          
          return Container(
            color: Colors.black,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                // Video
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: videoWidth,
                      height: videoHeight,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),
                
                // Buffering indicator
                if (_isBuffering)
                  const Center(child: CircularProgressIndicator()),
                
                // Controls overlay
                if (_showControls && widget.showControls)
                  _buildControls(),
                
                // Progress bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildProgressBar(),
                ),
              ],
            ),
          );
        },
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
                onPressed: () => seekTo(_controller!.value.position - const Duration(seconds: 10)),
              ),
              const SizedBox(width: 20),
              IconButton(
                iconSize: 50,
                icon: Icon(
                  _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (_controller!.value.isPlaying) {
                    pause();
                    setState(() => _showControls = true);
                  } else {
                    play();
                    setState(() => _showControls = false);
                  }
                },
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white, size: 30),
                onPressed: () => seekTo(_controller!.value.position + const Duration(seconds: 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 5,
      color: Colors.black38,
      child: Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: _controller!.value.isInitialized
                  ? _controller!.value.position.inMilliseconds /
                      _controller!.value.duration.inMilliseconds
                  : 0,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
} 