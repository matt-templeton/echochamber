import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../../models/video_model.dart';
import '../../models/audio_track_model.dart';
import '../../providers/video_feed_provider.dart';
import '../../repositories/video_repository.dart';
import 'audio_track_controls.dart';
import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart' show kIsWeb;

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
  final bool enableAudioOnInteraction;
  final Function(HLSVideoPlayerState)? onPlayerStateCreated;
  final VoidCallback? onAudioControlsShow;
  final Function(bool isVisible)? onAudioControlsVisibilityChanged;

  const HLSVideoPlayer({
    Key? key,
    required this.video,
    this.autoplay = true,
    this.showControls = true,
    this.onVideoEnd,
    this.enableAudioOnInteraction = false,
    this.onPlayerStateCreated,
    this.onAudioControlsShow,
    this.onAudioControlsVisibilityChanged,
  }) : super(key: key);

  @override
  State<HLSVideoPlayer> createState() => HLSVideoPlayerState();
}

class HLSVideoPlayerState extends State<HLSVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isError = false;
  bool _isBuffering = false;
  bool _showControls = false;
  bool _isDragging = false;
  bool _wasPlayingBeforeDrag = false;
  bool _isDisposed = false;
  double _aspectRatio = 16 / 9;
  Timer? _hideControlsTimer;
  bool _showAudioControls = false;
  List<AudioTrack>? _audioTracks;
  final Map<String, VideoPlayerController> _audioControllers = {};

  // Loop functionality state
  bool _isLoopMode = false;
  double? _loopStartPosition;
  double? _loopEndPosition;
  Timer? _longPressTimer;
  Timer? _loopTimer;
  static const Duration _longPressDuration = Duration(milliseconds: 500);

  // Add getter for controller
  VideoPlayerController? get controller => _controller;

  @override
  void initState() {
    super.initState();
    widget.onPlayerStateCreated?.call(this);
    // Always show controls initially on web
    if (kIsWeb) {
      _showControls = true;
    }
    _initializePlayer();
    _loadAudioTracks();
  }

  Future<void> _initializePlayer() async {
    dev.log('Starting player initialization - videoId: ${widget.video.id}',
      name: 'HLSVideoPlayer');
    
    try {
      final controller = VideoPlayerController.network(
        widget.video.videoUrl,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      _controller = controller;

      // Set initial volume based on previous user interaction
      if (kIsWeb) {
        final videoFeedProvider = context.read<VideoFeedProvider>();
        await controller.setVolume(videoFeedProvider.hasUserInteractedWithAudio ? 1.0 : 0.0);
      }

      await controller.initialize();
      if (!mounted) return;
      
      setState(() {
        _isInitialized = true;
        _aspectRatio = controller.value.aspectRatio;
      });

      controller.addListener(_onVideoProgress);

      if (widget.autoplay) {
        controller.play();
        _startHideControlsTimer();
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

  Future<void> _loadAudioTracks() async {
    try {
      dev.log('Loading audio tracks for video ${widget.video.id}', name: 'HLSVideoPlayer');
      final repository = VideoRepository();
      final tracks = await repository.getVideoAudioTracks(widget.video.id);
      if (mounted) {
        setState(() => _audioTracks = tracks);
      }
      dev.log('Found ${tracks.length} audio tracks for video ${widget.video.id}', name: 'HLSVideoPlayer');
    } catch (e) {
      dev.log('Error loading audio tracks: $e', name: 'HLSVideoPlayer', error: e);
    }
  }

  Future<void> _handleTrackToggle(String trackId, bool enabled) async {
    final track = _audioTracks?.firstWhere((t) => t.id == trackId);
    if (track == null) return;

    dev.log('Toggling track ${track.type}: enabled=$enabled', name: 'HLSVideoPlayer');

    if (track.type == AudioTrackType.original) {
      // If enabling original track
      if (enabled) {
        dev.log('Enabling original track - unmuting main video', name: 'HLSVideoPlayer');
        await _controller?.setVolume(1.0);
        // Stop all other tracks
        for (final controller in _audioControllers.values) {
          await controller.pause();
          await controller.dispose();
        }
        _audioControllers.clear();
      }
    } else {
      // If this is an isolated track
      if (enabled) {
        // Mute main video when using isolated tracks
        dev.log('Enabling isolated track - muting main video', name: 'HLSVideoPlayer');
        await _controller?.setVolume(0.0);
        
        // Initialize controller if needed
        if (!_audioControllers.containsKey(trackId)) {
          final controller = VideoPlayerController.network(
            track.masterPlaylistUrl,
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: true,
              allowBackgroundPlayback: false,
            ),
          );
          await controller.initialize();
          _audioControllers[trackId] = controller;
        }
        
        // Sync with main video position
        final mainPosition = _controller?.value.position;
        if (mainPosition != null) {
          await _audioControllers[trackId]?.seekTo(mainPosition);
        }
        
        // Start playback if main video is playing
        if (_controller?.value.isPlaying ?? false) {
          await _audioControllers[trackId]?.play();
        }
      } else {
        // If disabling an isolated track
        await _audioControllers[trackId]?.pause();
        await _audioControllers[trackId]?.dispose();
        _audioControllers.remove(trackId);
        
        // If no isolated tracks are enabled, unmute main video
        if (_audioControllers.isEmpty) {
          dev.log('No isolated tracks active - unmuting main video', name: 'HLSVideoPlayer');
          await _controller?.setVolume(1.0);
        }
      }
    }
  }

  void _handleVolumeChange(String trackId, double volume) {
    _audioControllers[trackId]?.setVolume(volume);
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    final controller = _controller;
    if (controller != null && controller.value.isPlaying) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && !_isDragging) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _onVideoProgress() {
    final controller = _controller;
    if (_isDisposed || controller == null) return;
    if (!mounted || !controller.value.isInitialized) return;

    if (controller.value.hasError) {
      dev.log('Video controller reported error',
        name: 'HLSVideoPlayer',
        error: controller.value.errorDescription);
      return;
    }

    if (controller.value.position >= controller.value.duration) {
      dev.log('Video reached end', name: 'HLSVideoPlayer');
      
      // Reset video position to beginning
      controller.seekTo(Duration.zero);
      controller.pause();
      
      // Call onVideoEnd callback if provided
      widget.onVideoEnd?.call();
    }

    final isBuffering = controller.value.isBuffering;
    if (_isBuffering != isBuffering && !_isDisposed) {
      setState(() => _isBuffering = isBuffering);
    }

    if (mounted && !_isDisposed) {
      setState(() {});
    }
  }

  void _handleTap() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _startHideControlsTimer();
      } else {
        _hideControlsTimer?.cancel();
      }
    });
  }

  void _enableAudioIfNeeded() {
    if (kIsWeb && widget.enableAudioOnInteraction) {
      final videoFeedProvider = context.read<VideoFeedProvider>();
      if (!videoFeedProvider.hasUserInteractedWithAudio) {
        videoFeedProvider.markUserInteractedWithAudio();
        _controller?.setVolume(1.0);
      }
    }
  }

  void pauseVideo() {
    if (_isDisposed || !mounted) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    
    _wasPlayingBeforeDrag = controller.value.isPlaying;
    if (_wasPlayingBeforeDrag) {
      controller.pause();
    }
  }

  void resumeVideo() {
    if (_isDisposed || !mounted) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    
    if (_wasPlayingBeforeDrag) {
      controller.play();
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _longPressTimer?.cancel();
    _loopTimer?.cancel();
    _isDisposed = true;
    _controller?.dispose();
    // Dispose all audio controllers
    for (final controller in _audioControllers.values) {
      controller.dispose();
    }
    _audioControllers.clear();
    super.dispose();
  }

  @override
  void didUpdateWidget(HLSVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.video.id != oldWidget.video.id) {
      // Video changed, reinitialize player
      _controller?.dispose();
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

    return SizedBox.expand(
      child: MouseRegion(
        onHover: (_) {
          // Only show controls on hover, don't try to enable audio
          if (!_showControls && mounted && _isInitialized) {
            setState(() => _showControls = true);
            _startHideControlsTimer();
          }
        },
        child: GestureDetector(
          // Only try to enable audio on explicit interactions
          onTap: () {
            _enableAudioIfNeeded();
            _handleTap();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: _aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
              if (_isBuffering)
                const Center(child: CircularProgressIndicator()),
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: Stack(
                      children: [
                        // Gradient overlay for better contrast
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                              stops: const [0.0, 0.2, 0.8, 1.0],
                            ),
                          ),
                        ),
                        if (widget.showControls)
                          Center(child: _buildControls()),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _buildProgressBar(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Audio track controls button - only show when panel is closed
              if (_audioTracks != null && _audioTracks!.isNotEmpty && !_showAudioControls)
                Positioned(
                  right: 16,
                  top: MediaQuery.of(context).padding.top + 8,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: IconButton(
                      icon: const Icon(Icons.multitrack_audio),
                      color: Colors.white,
                      onPressed: () {
                        widget.onAudioControlsShow?.call();
                        widget.onAudioControlsVisibilityChanged?.call(true);
                        setState(() => _showAudioControls = true);
                      },
                    ),
                  ),
                ),

              // Audio track controls panel
              if (_audioTracks != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AudioTrackControls(
                    tracks: _audioTracks!,
                    isExpanded: _showAudioControls,
                    onCollapse: () {
                      setState(() => _showAudioControls = false);
                      widget.onAudioControlsVisibilityChanged?.call(false);
                    },
                    onTrackToggle: _handleTrackToggle,
                    onVolumeChange: _handleVolumeChange,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    return Container(
      color: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white, size: 30),
                onPressed: () {
                  final newPosition = controller.value.position - const Duration(seconds: 10);
                  controller.seekTo(newPosition);
                  _startHideControlsTimer();
                },
              ),
              const SizedBox(width: 20),
              IconButton(
                iconSize: 50,
                icon: Icon(
                  controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (kIsWeb) {
                    final videoFeedProvider = context.read<VideoFeedProvider>();
                    if (!videoFeedProvider.hasUserInteractedWithAudio) {
                      videoFeedProvider.markUserInteractedWithAudio();
                      controller.setVolume(1.0);
                    }
                  }
                  
                  if (controller.value.isPlaying) {
                    controller.pause();
                    setState(() => _showControls = true);
                    _hideControlsTimer?.cancel();
                  } else {
                    controller.play();
                    _startHideControlsTimer();
                  }
                },
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white, size: 30),
                onPressed: () {
                  final newPosition = controller.value.position + const Duration(seconds: 10);
                  controller.seekTo(newPosition);
                  _startHideControlsTimer();
                },
              ),
              if (kIsWeb) ...[
                const SizedBox(width: 20),
                IconButton(
                  icon: Icon(
                    controller.value.volume > 0 ? Icons.volume_up : Icons.volume_off,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () {
                    final videoFeedProvider = context.read<VideoFeedProvider>();
                    videoFeedProvider.markUserInteractedWithAudio();
                    if (controller.value.volume > 0) {
                      controller.setVolume(0);
                    } else {
                      controller.setVolume(1.0);
                    }
                    setState(() {});
                    _startHideControlsTimer();
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    if (!mounted || !_isInitialized || _controller == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Handle invalid constraints
        if (constraints.maxWidth <= 0) {
          return const SizedBox.shrink();
        }

        final duration = _controller!.value.duration;
        final position = _controller!.value.position;
        
        // Handle invalid duration or position
        if (duration.inMilliseconds == 0) {
          return const SizedBox.shrink();
        }
        
        // Calculate progress with validation
        final progress = (position.inMilliseconds / duration.inMilliseconds)
            .clamp(0.0, 1.0);
        
        // Validate progress is a valid number
        if (progress.isNaN || progress.isInfinite) {
          return const SizedBox.shrink();
        }

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (DragStartDetails details) {
              if (!mounted || !_isInitialized) return;
              
              // Cancel any existing long press timer
              _longPressTimer?.cancel();
              
              setState(() {
                _isDragging = true;
                _wasPlayingBeforeDrag = _controller!.value.isPlaying;
              });
              if (_wasPlayingBeforeDrag) {
                _controller!.pause();
              }
              
              // If not in loop mode, handle normal seek
              if (!_isLoopMode) {
                _handleSeek(details.localPosition.dx, constraints.maxWidth);
              }
            },
            onHorizontalDragUpdate: (DragUpdateDetails details) {
              if (!_isDragging || !mounted || !_isInitialized) return;
              
              if (_isLoopMode && _loopStartPosition != null) {
                // In loop mode, update end position
                setState(() {
                  _loopEndPosition = (details.localPosition.dx / constraints.maxWidth)
                      .clamp(0.0, 1.0);
                });
              } else {
                _handleSeek(details.localPosition.dx, constraints.maxWidth);
              }
            },
            onHorizontalDragEnd: (DragEndDetails details) {
              if (!mounted || !_isInitialized) return;
              
              if (_isLoopMode && _loopStartPosition != null && _loopEndPosition != null) {
                // Ensure start is before end
                if (_loopStartPosition! > _loopEndPosition!) {
                  final temp = _loopStartPosition;
                  _loopStartPosition = _loopEndPosition;
                  _loopEndPosition = temp;
                }
                
                // Only start looping if region is > 1 second
                final duration = _controller!.value.duration;
                final loopDuration = (_loopEndPosition! - _loopStartPosition!) * duration.inMilliseconds;
                if (loopDuration >= 1000) {
                  _startLooping();
                } else {
                  _exitLoopMode();
                }
              } else if (_wasPlayingBeforeDrag) {
                _controller!.play();
              }
              
              setState(() {
                _isDragging = false;
              });
            },
            onTapDown: (TapDownDetails details) {
              if (!mounted || !_isInitialized) return;
              
              // Start timer for long press
              _longPressTimer = Timer(_longPressDuration, () {
                if (mounted) {
                  setState(() {
                    _isLoopMode = true;
                    _loopStartPosition = details.localPosition.dx / constraints.maxWidth;
                    _loopEndPosition = null;
                  });
                }
              });
            },
            onTapUp: (TapUpDetails details) {
              _longPressTimer?.cancel();
              
              if (!_isLoopMode) {
                _handleSeek(details.localPosition.dx, constraints.maxWidth);
              }
            },
            onTapCancel: () {
              _longPressTimer?.cancel();
            },
            child: Stack(
              children: [
                // Clickable area - full height transparent container
                Container(
                  height: 40,
                  color: Colors.transparent,
                ),
                // Progress bar group - centered in the clickable area
                Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      height: 20,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Background track
                          Center(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          // Loop region highlight
                          if (_isLoopMode && _loopStartPosition != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                height: 4,
                                margin: EdgeInsets.only(
                                  left: constraints.maxWidth * (_loopStartPosition ?? 0),
                                ),
                                width: constraints.maxWidth * 
                                  ((_loopEndPosition ?? _loopStartPosition ?? 0) - (_loopStartPosition ?? 0))
                                    .abs(),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          // Progress track
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              height: 4,
                              width: constraints.maxWidth * progress,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          // Progress indicator ball
                          Positioned(
                            left: (constraints.maxWidth * progress - 8).clamp(0, constraints.maxWidth - 16),
                            top: 2,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _isLoopMode ? Colors.blue : Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Loop mode indicator
                          if (_isLoopMode)
                            Positioned(
                              right: 8,
                              top: -24,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.repeat, color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: _exitLoopMode,
                                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                                    ),
                                  ],
                                ),
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
      },
    );
  }

  void _handleSeek(double dx, double maxWidth) {
    final progress = (dx / maxWidth).clamp(0.0, 1.0);
    final duration = _controller!.value.duration;
    final targetPosition = duration * progress;
    _controller!.seekTo(targetPosition);
  }

  void _startLooping() {
    if (!mounted || !_isInitialized || _controller == null) return;
    if (_loopStartPosition == null || _loopEndPosition == null) return;

    // Cancel any existing loop timer
    _loopTimer?.cancel();

    final duration = _controller!.value.duration;
    final startTime = duration * _loopStartPosition!;
    final endTime = duration * _loopEndPosition!;

    // Start playback from loop start
    _controller!.seekTo(startTime);
    _controller!.play();

    // Set up loop timer to check position and loop when needed
    _loopTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || _controller == null || !_isLoopMode) {
        timer.cancel();
        return;
      }

      final position = _controller!.value.position;
      if (position >= endTime) {
        _controller!.seekTo(startTime);
      }
    });
  }

  void _exitLoopMode() {
    if (!mounted) return;
    
    setState(() {
      _isLoopMode = false;
      _loopStartPosition = null;
      _loopEndPosition = null;
    });
    
    _loopTimer?.cancel();
    _loopTimer = null;
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