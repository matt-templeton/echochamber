import 'package:flutter/material.dart';
import 'package:better_player_enhanced/better_player.dart';
import '../../models/video_model.dart';

class HLSVideoPlayer extends StatefulWidget {
  final Video? video;
  final bool autoPlay;
  final bool showControls;
  final VoidCallback? onError;
  final VoidCallback? onVideoEnd;
  final Function(String)? onQualityChanged;

  const HLSVideoPlayer({
    super.key,
    this.video,
    this.autoPlay = false,
    this.showControls = true,
    this.onError,
    this.onVideoEnd,
    this.onQualityChanged,
  });

  @override
  State<HLSVideoPlayer> createState() => _HLSVideoPlayerState();
}

class _HLSVideoPlayerState extends State<HLSVideoPlayer> {
  BetterPlayerController? _controller;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    if (widget.video != null) {
      _initializePlayer();
    }
  }

  void _initializePlayer() {
    // Create resolutions map from video variants
    final resolutions = widget.video?.validationMetadata?.variants?.fold<Map<String, String>>(
      {},
      (map, variant) => map..[variant.quality] = variant.playlistUrl,
    ) ?? {};

    // Create data source from HLS URL
    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      widget.video!.videoUrl,
      videoFormat: BetterPlayerVideoFormat.hls,
      headers: const {
        "User-Agent": "EchoChamber/1.0"
      },
      resolutions: resolutions,
    );

    // Configure player
    final configuration = BetterPlayerConfiguration(
      autoPlay: widget.autoPlay,
      aspectRatio: 9 / 16, // Portrait mode for short-form videos
      fit: BoxFit.contain,
      controlsConfiguration: BetterPlayerControlsConfiguration(
        enableFullscreen: false, // Disable fullscreen for short-form videos
        enablePlayPause: widget.showControls,
        enableProgressBar: widget.showControls,
        enableProgressText: widget.showControls,
        enableQualities: widget.showControls,
        loadingWidget: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        progressBarPlayedColor: Colors.white,
        progressBarHandleColor: Colors.white,
        progressBarBufferedColor: Colors.white70,
        progressBarBackgroundColor: Colors.white38,
      ),
      eventListener: (BetterPlayerEvent event) {
        if (event.betterPlayerEventType == BetterPlayerEventType.finished) {
          widget.onVideoEnd?.call();
        } else if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
          setState(() => _isError = true);
          widget.onError?.call();
        } else if (event.betterPlayerEventType == BetterPlayerEventType.changedResolution) {
          final quality = event.parameters?["quality"] as String?;
          if (quality != null) {
            widget.onQualityChanged?.call(quality);
          }
        }
      },
    );

    _controller = BetterPlayerController(configuration);
    _controller!.setupDataSource(dataSource);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HLSVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.video?.id != widget.video?.id) {
      _controller?.dispose();
      if (widget.video != null) {
        _initializePlayer();
      } else {
        _controller = null;
      }
    }
  }

  // Method exposed for testing
  @visibleForTesting
  void setErrorState(bool isError) {
    setState(() => _isError = isError);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.video == null) {
      return _buildPlaceholder();
    }

    if (_isError) {
      return _buildErrorWidget();
    }

    return _buildVideoPlayer();
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
        child: Center(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: BetterPlayer(
              controller: _controller!,
            ),
          ),
        ),
      ),
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