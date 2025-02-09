import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/video_feed_provider.dart';
import '../../models/video_model.dart';
import 'hls_video_player.dart';
import 'dart:developer' as dev;
import 'package:echochamber/widgets/video/preloaded_video.dart';

class VideoQueue extends StatefulWidget {
  final int queueSize;
  final String? initialVideoId;

  const VideoQueue({
    Key? key,
    required this.queueSize,
    this.initialVideoId,
  }) : assert(queueSize >= 3, 'Queue size must be at least 3'),
       assert(queueSize % 2 == 1, 'Queue size must be odd'),
       super(key: key);

  @override
  State<VideoQueue> createState() => _VideoQueueState();
}

class _VideoQueueState extends State<VideoQueue> {
  late final PageController _pageController;
  late List<HLSVideoPlayer?> _queue;
  int _currentIndex = 0;
  bool _isLoading = false;
  PreloadedVideo? _preloadedVideo;

  @override
  void initState() {
    super.initState();
    dev.log('VideoQueue initState called', name: 'VideoQueue');
    _pageController = PageController(initialPage: _currentIndex);
    _queue = List<HLSVideoPlayer?>.generate(widget.queueSize, (_) => null);
    _initializeCurrentVideo();
  }

  Future<void> _initializeCurrentVideo() async {
    dev.log('Starting _initializeCurrentVideo', name: 'VideoQueue');
    try {
      final provider = context.read<VideoFeedProvider>();
      
      // Wait for provider initialization to complete
      dev.log('Waiting for VideoFeedProvider initialization', name: 'VideoQueue');
      await provider.waitForInitialization();
      
      if (widget.initialVideoId != null) {
        dev.log('Loading specific video: ${widget.initialVideoId}', name: 'VideoQueue');
        await provider.loadSpecificVideo(widget.initialVideoId!);
      } else {
        dev.log('Loading next video', name: 'VideoQueue');
        await provider.loadNextVideo();
      }
      
      if (!mounted) return;
      
      final video = provider.currentVideo;
      dev.log('Current video loaded: ${video?.id}, videoUrl: ${video?.videoUrl}', name: 'VideoQueue');
      
      if (video != null) {
        dev.log('Creating HLSVideoPlayer for video ${video.id}', name: 'VideoQueue');
        try {
          final player = await _createVideoPlayer(video.videoUrl, video.id, true, true);
          
          if (!mounted) return;
          
          setState(() {
            dev.log('Setting player at index $_currentIndex in queue', name: 'VideoQueue');
            _queue[_currentIndex] = player;
          });
          
          // Start preloading next video immediately after current video is ready
          _preloadNextVideo();
          
        } catch (e, stackTrace) {
          dev.log('Error creating player', name: 'VideoQueue', error: e, stackTrace: stackTrace);
        }
      }
    } catch (e, stackTrace) {
      dev.log('Error in _initializeCurrentVideo', name: 'VideoQueue', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _preloadNextVideo() async {
    dev.log('Starting _preloadNextVideo', name: 'VideoQueue');
    if (_isLoading) {
      dev.log('Skipping preload - already loading', name: 'VideoQueue');
      return;
    }
    _isLoading = true;

    try {
      // Schedule provider updates for next frame
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await context.read<VideoFeedProvider>().loadNextVideo();
          if (!mounted) return;

          final video = context.read<VideoFeedProvider>().currentVideo;
          dev.log('Preloading video: ${video?.id}, videoUrl: ${video?.videoUrl}', name: 'VideoQueue');
          
          if (video != null) {
            // Dispose of any existing preloaded video
            await _preloadedVideo?.dispose();
            
            // Create new preloaded video
            _preloadedVideo = PreloadedVideo(
              videoUrl: video.videoUrl,
              videoId: video.id,
            );
          }
        } catch (e, stackTrace) {
          dev.log('Error in _preloadNextVideo', name: 'VideoQueue', error: e, stackTrace: stackTrace);
        }
      });
    } finally {
      _isLoading = false;
    }
  }

  Future<HLSVideoPlayer> _createVideoPlayer(
    String videoUrl,
    String videoId,
    bool shouldPlay,
    bool isVisible,
  ) async {
    final playerKey = GlobalKey<HLSVideoPlayerState>();
    final player = HLSVideoPlayer(
      key: playerKey,
      videoUrl: videoUrl,
      videoId: videoId,
      autoplay: shouldPlay,
      shouldPlay: shouldPlay,
      isVisible: isVisible,
      onPlayingStateChanged: null,  // Remove play state dependency
      onError: () {
        dev.log('Error in HLSVideoPlayer for video $videoId', name: 'VideoQueue');
      },
    );

    // Wait for player initialization
    final state = playerKey.currentState;
    if (state != null) {
      dev.log('Waiting for player initialization', name: 'VideoQueue');
      await state.waitForInitialization();
      dev.log('Player initialization completed', name: 'VideoQueue');
    }

    return player;
  }

  Future<void> _onPageChanged(int index) async {
    dev.log('Page changed to index: $index', name: 'VideoQueue');
    if (_isLoading) {
      dev.log('Skipping page change - already loading', name: 'VideoQueue');
      return;
    }
    _isLoading = true;

    try {
      final direction = index > _currentIndex ? 1 : -1;
      dev.log('Swipe direction: ${direction > 0 ? "right" : "left"}', name: 'VideoQueue');
      
      // Schedule state updates for next frame
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Load next/previous video and shift queue before updating states
        if (direction > 0) {
          await _shiftQueueRight();
        } else {
          await _shiftQueueLeft();
        }

        if (!mounted) return;

        setState(() {
          // Update current index after queue shift
          _currentIndex = index;
        });
        
        // Update video states after queue shift is complete
        for (var i = 0; i < _queue.length; i++) {
          final player = _queue[i];
          if (player != null) {
            dev.log('Updating player at index $i - shouldPlay: ${i == index}, isVisible: ${i == index}', name: 'VideoQueue');
            player.updateState(
              shouldPlay: i == index,
              isVisible: i == index,
            );
          }
        }
      });
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _shiftQueueRight() async {
    dev.log('Starting _shiftQueueRight', name: 'VideoQueue');
    
    // If we have a preloaded video, use it
    if (_preloadedVideo?.isLoaded == true) {
      dev.log('Using preloaded video: ${_preloadedVideo!.videoId}', name: 'VideoQueue');
      try {
        final player = await _createVideoPlayer(
          _preloadedVideo!.videoUrl,
          _preloadedVideo!.videoId,
          true,
          true,
        );
        
        setState(() {
          dev.log('Queue state before right shift: ${_queue.map((p) => p?.videoId).toList()}', name: 'VideoQueue');
          
          // Create new video player for the next video before removing the old one
          final nextIndex = (_currentIndex + 1) % widget.queueSize;
          _queue[nextIndex] = player;
          
          // Remove first element and add null at the end
          _queue.removeAt(0);
          _queue.add(null);
          
          dev.log('Queue state after right shift: ${_queue.map((p) => p?.videoId).toList()}', name: 'VideoQueue');
        });
        
        // Start preloading next video immediately after shift
        _preloadNextVideo();
      } catch (e, stackTrace) {
        dev.log('Error creating player from preloaded video', name: 'VideoQueue', error: e, stackTrace: stackTrace);
      }
    } else {
      // Fall back to regular loading if no preloaded video is available
      await context.read<VideoFeedProvider>().loadNextVideo();
      if (!mounted) return;

      final video = context.read<VideoFeedProvider>().currentVideo;
      if (video != null) {
        try {
          final player = await _createVideoPlayer(
            video.videoUrl,
            video.id,
            true,
            true,
          );
          
          setState(() {
            final nextIndex = (_currentIndex + 1) % widget.queueSize;
            _queue[nextIndex] = player;
            _queue.removeAt(0);
            _queue.add(null);
          });
          
          // Start preloading next video immediately after fallback load
          _preloadNextVideo();
        } catch (e, stackTrace) {
          dev.log('Error in _shiftQueueRight', name: 'VideoQueue', error: e, stackTrace: stackTrace);
        }
      }
    }
  }

  Future<void> _shiftQueueLeft() async {
    await context.read<VideoFeedProvider>().loadPreviousVideo();
    if (!mounted) return;

    final video = context.read<VideoFeedProvider>().currentVideo;
    if (video != null) {
      setState(() {
        // Remove last element and add null at the beginning
        _queue.removeLast();
        _queue.insert(0, null);
        
        // Create new video player for the previous video
        final prevIndex = (_currentIndex - 1 + widget.queueSize) % widget.queueSize;
        _queue[prevIndex] = HLSVideoPlayer(
          videoUrl: video.videoUrl,
          videoId: video.id,
          autoplay: false,
          shouldPlay: false,
          isVisible: false,
          onPlayingStateChanged: (isPlaying) {
            if (mounted && isPlaying && prevIndex > 0) {
              _preloadNextVideo();
            }
          },
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    dev.log('Building VideoQueue widget, queue length: ${_queue.length}, current index: $_currentIndex', name: 'VideoQueue');
    for (var i = 0; i < _queue.length; i++) {
      final player = _queue[i];
      dev.log('Queue slot $i: ${player != null ? "HLSVideoPlayer(${player.videoId})" : "null"}', name: 'VideoQueue');
    }
    
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: widget.queueSize,
      itemBuilder: (context, index) {
        final player = _queue[index];
        dev.log('Building item at index $index: ${player != null ? "HLSVideoPlayer(${player.videoId})" : "null"}', name: 'VideoQueue');
        return player ?? Container(
          color: Colors.black,
          child: const Center(
            child: Text('No video available', style: TextStyle(color: Colors.white)),
          ),
        );
      },
    );
  }
} 