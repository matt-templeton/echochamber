import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class EchoVideoPlayer extends StatefulWidget {
  final String? videoUrl;
  final bool autoPlay;
  final bool showControls;
  final VoidCallback? onError;
  final VoidCallback? onVideoEnd;

  const EchoVideoPlayer({
    super.key,
    this.videoUrl,
    this.autoPlay = false,
    this.showControls = true,
    this.onError,
    this.onVideoEnd,
  });

  @override
  State<EchoVideoPlayer> createState() => _EchoVideoPlayerState();
}

class _EchoVideoPlayerState extends State<EchoVideoPlayer> {
  VideoPlayerController? _controller;
  Future<void>? _initializeVideoPlayerFuture;
  bool _isError = false;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    if (widget.videoUrl != null) {
      _initializePlayer();
    }
    // Add position listener for progress updates
    _controller?.addListener(() {
      setState(() {}); // Rebuild for progress updates
    });
  }

  void _initializePlayer() {
    // Initialize the controller with the video URL
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl!),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
    );

    // Initialize the controller and store the future for later use
    _initializeVideoPlayerFuture = _controller!.initialize().then((_) {
      // Add listener for video end
      _controller!.addListener(_videoListener);
      
      // Set initial volume to maximum
      _controller!.setVolume(1.0);
      
      // Start playing if autoPlay is true
      if (widget.autoPlay && mounted) {
        _controller!.play();
      }
    }).catchError((error) {
      debugPrint('Error initializing video player: $error');
      setState(() => _isError = true);
      widget.onError?.call();
    });
  }

  void _videoListener() {
    // Check if video has ended
    if (_controller!.value.position >= _controller!.value.duration) {
      widget.onVideoEnd?.call();
    }
  }

  @override
  void dispose() {
    if (_controller != null) {
      _controller!.removeListener(_videoListener);
      _controller!.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(EchoVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle changes in videoUrl
    if (oldWidget.videoUrl != widget.videoUrl) {
      if (_controller != null) {
        _controller!.dispose();
      }
      if (widget.videoUrl != null) {
        _initializePlayer();
      } else {
        _controller = null;
        _initializeVideoPlayerFuture = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If no video URL is provided, show the placeholder
    if (widget.videoUrl == null) {
      return _buildPlaceholder();
    }

    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (_isError) {
            return _buildErrorWidget();
          }
          return _buildVideoPlayer();
        }
        return _buildLoadingWidget();
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library,
              size: 64,
              color: Colors.white54,
            ),
            SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return SizedBox.expand(
      child: Container(
        color: Colors.black,
        child: Transform.scale(
          scale: _getScale(),
          child: Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoPlayer(_controller!),
                  if (widget.showControls) _buildControls(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _getScale() {
    final size = MediaQuery.of(context).size;
    final videoRatio = _controller!.value.aspectRatio;
    final screenRatio = size.width / size.height;

    if (videoRatio < screenRatio) {
      // If video is taller than screen, scale based on width
      return screenRatio / videoRatio;
    } else {
      // If video is wider than screen, scale based on height
      return 1.0;
    }
  }

  Widget _buildControls() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Center play/pause button
            Center(
              child: AnimatedOpacity(
                opacity: _showControls || !_controller!.value.isPlaying ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(50.0),
                  ),
                  child: IconButton(
                    padding: const EdgeInsets.all(12.0),
                    icon: Icon(
                      _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 50.0,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_controller!.value.isPlaying) {
                          _controller!.pause();
                        } else {
                          _controller!.play();
                        }
                      });
                    },
                  ),
                ),
              ),
            ),
            // Bottom controls bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              _formatDuration(_controller!.value.position),
                              style: const TextStyle(color: Colors.white),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2.0,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                                  activeTrackColor: Colors.white,
                                  inactiveTrackColor: Colors.white.withOpacity(0.3),
                                  thumbColor: Colors.white,
                                  overlayColor: Colors.white.withOpacity(0.3),
                                ),
                                child: Slider(
                                  value: _controller!.value.position.inMilliseconds.toDouble(),
                                  min: 0.0,
                                  max: _controller!.value.duration.inMilliseconds.toDouble(),
                                  onChanged: (value) {
                                    final position = Duration(milliseconds: value.round());
                                    _controller!.seekTo(position);
                                  },
                                ),
                              ),
                            ),
                            Text(
                              _formatDuration(_controller!.value.duration),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      // Volume control
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _controller!.value.volume > 0 
                                    ? Icons.volume_up 
                                    : Icons.volume_off,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_controller!.value.volume > 0) {
                                    _controller!.setVolume(0);
                                  } else {
                                    _controller!.setVolume(1);
                                  }
                                });
                              },
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2.0,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                                  activeTrackColor: Colors.white,
                                  inactiveTrackColor: Colors.white.withOpacity(0.3),
                                  thumbColor: Colors.white,
                                  overlayColor: Colors.white.withOpacity(0.3),
                                ),
                                child: Slider(
                                  value: _controller!.value.volume,
                                  min: 0.0,
                                  max: 1.0,
                                  onChanged: (value) {
                                    setState(() {
                                      _controller!.setVolume(value);
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 60,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error loading video',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _isError = false;
                _initializePlayer();
              });
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
} 