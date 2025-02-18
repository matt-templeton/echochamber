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
  final Map<String, bool> _enabledTracks = {};  // Track enabled state
  final Map<String, double> _trackVolumes = {};  // Track volume state

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
        // Initialize all audio controllers immediately
        _initializeAudioControllers(tracks);
      }
      dev.log('Found ${tracks.length} audio tracks for video ${widget.video.id}', name: 'HLSVideoPlayer');
    } catch (e) {
      dev.log('Error loading audio tracks: $e', name: 'HLSVideoPlayer', error: e);
    }
  }

  Future<void> _initializeAudioControllers(List<AudioTrack> tracks) async {
    dev.log('Initializing audio controllers for all tracks', name: 'HLSVideoPlayer');
    
    // Initialize track states
    for (final track in tracks) {
      _enabledTracks[track.id] = track.type == AudioTrackType.original;
      _trackVolumes[track.id] = track.type == AudioTrackType.original ? 0.85 : 0.0;
    }
    
    // Initialize all non-original tracks
    for (final track in tracks) {
      if (track.type == AudioTrackType.original) continue;
      
      try {
        dev.log('Initializing controller for track ${track.id}', name: 'HLSVideoPlayer');
        final controller = VideoPlayerController.network(
          track.masterPlaylistUrl,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
        );
        
        await controller.initialize();
        _audioControllers[track.id] = controller;
        
        // Start with volume at 0
        await controller.setVolume(0.0);
        
        // Start playback immediately and seek to current position
        if (_controller?.value.isPlaying ?? false) {
          final position = _controller?.value.position;
          if (position != null) {
            await controller.seekTo(position);
          }
          await controller.play();
        }
        
      } catch (e) {
        dev.log('Error initializing controller for track ${track.id}: $e', 
          name: 'HLSVideoPlayer', 
          error: e);
      }
    }
  }

  Future<void> _handleTrackToggle(String trackId, bool enabled) async {
    final track = _audioTracks?.firstWhere((t) => t.id == trackId);
    if (track == null) return;

    // Update track state
    _enabledTracks[trackId] = enabled;
    _trackVolumes[trackId] = enabled ? 0.85 : 0.0;

    if (track.type == AudioTrackType.original) {
      // For original track, just control main video volume
      if (enabled) {
        await _controller?.setVolume(0.85);
        // Mute all other tracks
        for (final controller in _audioControllers.values) {
          await controller.setVolume(0.0);
        }
        // Update state for all other tracks
        for (final t in _audioTracks ?? []) {
          if (t.id != trackId) {
            _enabledTracks[t.id] = false;
            _trackVolumes[t.id] = 0.0;
          }
        }
      } else {
        await _controller?.setVolume(0.0);
      }
    } else {
      // For isolated tracks
      if (enabled) {
        // Mute main video when using isolated tracks
        await _controller?.setVolume(0.0);
        await _audioControllers[trackId]?.setVolume(0.85);
        // Update original track state
        final originalTrack = _audioTracks?.firstWhere((t) => t.type == AudioTrackType.original);
        if (originalTrack != null) {
          _enabledTracks[originalTrack.id] = false;
          _trackVolumes[originalTrack.id] = 0.0;
        }
      } else {
        await _audioControllers[trackId]?.setVolume(0.0);
        
        // If no isolated tracks have volume > 0, unmute main video
        final anyIsolatedTracksEnabled = _audioControllers.values
            .any((controller) => controller.value.volume > 0);
        if (!anyIsolatedTracksEnabled) {
          await _controller?.setVolume(0.85);
          // Update original track state
          final originalTrack = _audioTracks?.firstWhere((t) => t.type == AudioTrackType.original);
          if (originalTrack != null) {
            _enabledTracks[originalTrack.id] = true;
            _trackVolumes[originalTrack.id] = 0.85;
          }
        }
      }
    }
  }

  void _handleVolumeChange(String trackId, double volume) {
    final track = _audioTracks?.firstWhere((t) => t.id == trackId);
    if (track == null) return;

    // Update track volume state
    _trackVolumes[trackId] = volume;
    _enabledTracks[trackId] = volume > 0;

    if (track.type == AudioTrackType.original) {
      _controller?.setVolume(volume);
      if (volume > 0) {
        // If original track volume is increased, mute all other tracks
        for (final controller in _audioControllers.values) {
          controller.setVolume(0.0);
        }
        // Update state for all other tracks
        for (final t in _audioTracks ?? []) {
          if (t.id != trackId) {
            _enabledTracks[t.id] = false;
            _trackVolumes[t.id] = 0.0;
          }
        }
      }
    } else {
      // For isolated tracks
      _audioControllers[trackId]?.setVolume(volume);
      if (volume > 0) {
        // If any isolated track has volume, mute main video
        _controller?.setVolume(0.0);
        // Update original track state
        final originalTrack = _audioTracks?.firstWhere((t) => t.type == AudioTrackType.original);
        if (originalTrack != null) {
          _enabledTracks[originalTrack.id] = false;
          _trackVolumes[originalTrack.id] = 0.0;
        }
      } else {
        // If no isolated tracks have volume, unmute main video
        final anyIsolatedTracksEnabled = _audioControllers.values
            .any((controller) => controller.value.volume > 0);
        if (!anyIsolatedTracksEnabled) {
          _controller?.setVolume(0.85);
          // Update original track state
          final originalTrack = _audioTracks?.firstWhere((t) => t.type == AudioTrackType.original);
          if (originalTrack != null) {
            _enabledTracks[originalTrack.id] = true;
            _trackVolumes[originalTrack.id] = 0.85;
          }
        }
      }
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    final controller = _controller;
    // Don't start the hide timer if we're dragging, in loop mode, or interacting with the progress bar
    if (controller != null && controller.value.isPlaying && !_isDragging && !_isLoopMode) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && !_isDragging && !_isLoopMode) {
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

    if (controller.value.position >= controller.value.duration && !_isLoopMode) {
      
      // Reset video position to beginning
      _seekAllToPosition(Duration.zero);
      _pauseAll();
      
      // Call onVideoEnd callback if provided
      widget.onVideoEnd?.call();
    }

    final isBuffering = controller.value.isBuffering;
    if (_isBuffering != isBuffering && !_isDisposed) {
      setState(() => _isBuffering = isBuffering);
    }

    // Keep controls visible if we're dragging or in loop mode
    if (_isDragging || _isLoopMode) {
      setState(() => _showControls = true);
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
      _pauseAll();
    }
  }

  void resumeVideo() {
    if (_isDisposed || !mounted) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    
    if (_wasPlayingBeforeDrag) {
      _playAll();
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

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final isPortrait = screenSize.height > screenSize.width;
    
    // Calculate video dimensions to fill screen while maintaining aspect ratio
    double videoWidth = screenSize.width;
    double videoHeight = screenSize.width / _aspectRatio;
    
    if (videoHeight < screenSize.height) {
      videoHeight = screenSize.height;
      videoWidth = videoHeight * _aspectRatio;
    }

    return Container(
      color: Colors.black,
      child: MouseRegion(
        onHover: (_) {
          if (!_showControls && mounted && _isInitialized) {
            setState(() => _showControls = true);
            _startHideControlsTimer();
          }
        },
        child: GestureDetector(
          onTap: () {
            _enableAudioIfNeeded();
            _handleTap();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Center video and ensure it fills the screen
              Center(
                child: SizedBox.fromSize(
                  size: Size(videoWidth, videoHeight),
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
                  child: _buildAudioTrackControls(),
                ),

              // Loop mode indicator - moved to last position in stack
              if (_isLoopMode)
                Positioned(
                  right: 8,
                  bottom: 36 + MediaQuery.of(context).padding.bottom,  // Moved even closer to progress bar
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Material(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                      elevation: 2,
                      child: InkWell(
                        onTap: () {
                          _exitLoopMode();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),  // Reduced padding
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.repeat, color: Colors.white, size: 12),  // Reduced icon size
                              const SizedBox(width: 4),  // Reduced spacing
                              const Icon(Icons.close, color: Colors.white, size: 12),  // Reduced icon size
                            ],
                          ),
                        ),
                      ),
                    ),
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
                    _pauseAll();
                    setState(() => _showControls = true);
                    _hideControlsTimer?.cancel();
                  } else {
                    _playAll();
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
                _pauseAll();
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
                _playAll();
              }
              
              setState(() {
                _isDragging = false;
              });
            },
            onTapDown: (TapDownDetails details) {
              if (!mounted || !_isInitialized) return;
              
              // Pause video immediately
              _wasPlayingBeforeDrag = _controller!.value.isPlaying;
              if (_wasPlayingBeforeDrag) {
                _pauseAll();
              }
              
              // Start timer for long press
              _longPressTimer = Timer(_longPressDuration, () {
                if (mounted) {
                  setState(() {
                    _isLoopMode = true;
                    _isDragging = true;  // Set dragging state when entering loop mode
                    _loopStartPosition = details.localPosition.dx / constraints.maxWidth;
                    _loopEndPosition = null;
                  });
                  // Cancel hide controls timer to keep controls visible
                  _hideControlsTimer?.cancel();
                }
              });
            },
            onTapUp: (TapUpDetails details) {
              _longPressTimer?.cancel();
              
              if (!_isLoopMode) {
                _handleSeek(details.localPosition.dx, constraints.maxWidth);
                if (_wasPlayingBeforeDrag) {
                  _playAll();
                }
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
                          // Loop region highlight - moved after progress track to overlay it
                          if (_isLoopMode && _loopStartPosition != null)
                            Stack(
                              children: [
                                // Loop region highlight
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
                                // Start bracket handle
                                Positioned(
                                  left: constraints.maxWidth * (_loopStartPosition ?? 0) - 8,
                                  top: -8,
                                  bottom: -8,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.resizeLeft,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onHorizontalDragUpdate: (details) {
                                        if (!mounted || !_isInitialized) return;
                                        setState(() {
                                          _loopStartPosition = ((_loopStartPosition ?? 0) + 
                                            details.delta.dx / constraints.maxWidth)
                                              .clamp(0.0, (_loopEndPosition ?? 1.0));
                                        });
                                        // Restart loop with new positions
                                        _startLooping();
                                      },
                                      child: Container(
                                        width: 16,
                                        child: Center(
                                          child: Container(
                                            width: 2,
                                            height: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // End bracket handle
                                if (_loopEndPosition != null)
                                  Positioned(
                                    left: constraints.maxWidth * _loopEndPosition! - 8,
                                    top: -8,
                                    bottom: -8,
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.resizeRight,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onHorizontalDragUpdate: (details) {
                                          if (!mounted || !_isInitialized) return;
                                          setState(() {
                                            _loopEndPosition = (_loopEndPosition! + 
                                              details.delta.dx / constraints.maxWidth)
                                                .clamp(_loopStartPosition ?? 0.0, 1.0);
                                          });
                                          // Restart loop with new positions
                                          _startLooping();
                                        },
                                        child: Container(
                                          width: 16,
                                          child: Center(
                                            child: Container(
                                              width: 2,
                                              height: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
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

  Widget _buildAudioTrackControls() {
    return AudioTrackControls(
      tracks: _audioTracks!,
      isExpanded: _showAudioControls,
      onCollapse: () {
        setState(() => _showAudioControls = false);
        widget.onAudioControlsVisibilityChanged?.call(false);
      },
      onTrackToggle: _handleTrackToggle,
      onVolumeChange: _handleVolumeChange,
      initialEnabledTracks: _enabledTracks,
      initialTrackVolumes: _trackVolumes,
      isLoopMode: _isLoopMode,
      loopStartTime: _loopStartPosition != null ? 
        _controller!.value.duration.inSeconds * _loopStartPosition! : null,
      loopEndTime: _loopEndPosition != null ? 
        _controller!.value.duration.inSeconds * _loopEndPosition! : null,
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

    // Only start if we have a valid loop region
    if (endTime <= startTime) {
      dev.log('Invalid loop region - end time must be after start time', name: 'HLSVideoPlayer');
      return;
    }

    // Start playback from loop start if we're outside the loop region
    final currentPosition = _controller!.value.position;
    if (currentPosition < startTime || currentPosition > endTime) {
      _seekAllToPosition(startTime);
    }
    _playAll();

    // Set up loop timer to check position and loop when needed
    _loopTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || _controller == null || !_isLoopMode) {
        timer.cancel();
        return;
      }

      // Check main video position
      final mainPosition = _controller!.value.position;
      if (mainPosition >= endTime) {
        _seekAllToPosition(startTime);
      }

      // Check all audio track positions and ensure they stay in sync
      for (final controller in _audioControllers.values) {
        final trackPosition = controller.value.position;
        
        // Check if track needs to loop
        if (trackPosition >= endTime) {
          controller.seekTo(startTime);
          controller.play();
        }
        
        // Check if track is out of sync with main video
        final syncDiff = (trackPosition - mainPosition).inMilliseconds.abs();
        if (syncDiff > 100) {  // If more than 100ms out of sync
          controller.seekTo(mainPosition);
          controller.play();
        }
      }
    });
  }

  Future<void> _seekAllToPosition(Duration position) async {
    // Seek main video
    await _controller?.seekTo(position);
    
    // Seek ALL audio tracks, regardless of enabled state
    for (final controller in _audioControllers.values) {
      await controller.seekTo(position);
      // Ensure track is playing if main video is playing
      if (_controller?.value.isPlaying ?? false) {
        await controller.play();
      }
    }
  }

  Future<void> _playAll() async {
    // Play main video
    await _controller?.play();
    
    // Play ALL audio tracks, using volume to control which are heard
    for (final entry in _audioControllers.entries) {
      final controller = entry.value;
      final trackId = entry.key;
      await controller.play();
      await controller.setVolume(_trackVolumes[trackId] ?? 0.0);
    }
  }

  Future<void> _pauseAll() async {
    // Pause main video
    await _controller?.pause();
    
    // Pause all audio tracks
    for (final controller in _audioControllers.values) {
      await controller.pause();
    }
  }

  void _exitLoopMode() {
    dev.log('_exitLoopMode called', name: 'HLSVideoPlayer');
    if (!mounted) {
      dev.log('Widget not mounted, exiting', name: 'HLSVideoPlayer');
      return;
    }
    
    
    // Cancel the loop timer first
    _loopTimer?.cancel();
    _loopTimer = null;

    // Store current position before resetting loop state
    final currentPosition = _controller?.value.position;
    
    setState(() {
      _isLoopMode = false;
      _loopStartPosition = null;
      _loopEndPosition = null;
      _isDragging = false;  // Ensure dragging state is reset
      _showControls = true; // Keep controls visible briefly
    });
    
    // If we have a valid position and controller, seek to it and continue playing
    if (currentPosition != null && _controller != null) {
      _controller!.seekTo(currentPosition);
      if (_wasPlayingBeforeDrag) {
        _controller!.play();
        _startHideControlsTimer();
      }
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