import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:developer' as dev;

class PreloadedVideo {
  final String videoUrl;
  final String videoId;
  VideoPlayerController? _controller;
  bool _isLoaded = false;
  final _initializationCompleter = Completer<void>();

  PreloadedVideo({
    required this.videoUrl,
    required this.videoId,
  }) {
    _startPreloading();
  }

  bool get isLoaded => _isLoaded;
  VideoPlayerController? get controller => _controller;
  Future<void> get initialized => _initializationCompleter.future;

  Future<void> _startPreloading() async {
    dev.log('Starting video preload for videoId: $videoId', name: 'PreloadedVideo');
    try {
      dev.log('Creating controller for preload', name: 'PreloadedVideo');
      try {
        _controller = VideoPlayerController.network(
          videoUrl,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
        dev.log('Successfully created controller', name: 'PreloadedVideo');
      } catch (e, stackTrace) {
        dev.log('Error creating controller', name: 'PreloadedVideo', error: e, stackTrace: stackTrace);
        throw e;
      }
      
      dev.log('Initializing controller for preload', name: 'PreloadedVideo');
      try {
        await _controller!.initialize();
        dev.log('Controller initialization completed', name: 'PreloadedVideo');
      } catch (e, stackTrace) {
        dev.log('Error during controller initialization', name: 'PreloadedVideo', error: e, stackTrace: stackTrace);
        throw e;
      }

      dev.log('Setting loaded state to true', name: 'PreloadedVideo');
      _isLoaded = true;
      dev.log('Completing initialization', name: 'PreloadedVideo');
      _initializationCompleter.complete();
      dev.log('Video preload complete for videoId: $videoId', name: 'PreloadedVideo');
    } catch (e, stackTrace) {
      dev.log('Error preloading video', name: 'PreloadedVideo', error: e, stackTrace: stackTrace);
      _initializationCompleter.completeError(e);
      dev.log('Cleaning up after error', name: 'PreloadedVideo');
      _controller?.dispose();
      _controller = null;
    }
  }

  Future<void> dispose() async {
    dev.log('Disposing preloaded video: $videoId', name: 'PreloadedVideo');
    await _controller?.dispose();
    _controller = null;
    _isLoaded = false;
  }

  VideoPlayerController? takeController() {
    final controller = _controller;
    _controller = null;
    _isLoaded = false;
    return controller;
  }
} 