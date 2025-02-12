import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/video_list.dart';
import '../../models/video_buffer_manager.dart';
import '../../models/video_model.dart';
import '../../widgets/video/hls_video_player.dart';
import '../../widgets/primary_nav_bar.dart';
import '../../repositories/video_repository.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';
import '../../utils/number_formatter.dart';
import 'dart:developer' as dev;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/video_feed_provider.dart';
import '../../navigation/screen_state.dart';

class HomeScreen extends StatefulWidget {
  final String? initialVideoId;
  
  const HomeScreen({
    Key? key,
    this.initialVideoId,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _pageController;
  late final VideoFeedProvider _videoFeedProvider;
  late final NavigationStateManager _navigationManager;
  late final HomeScreenState _screenState;
  GlobalKey<HLSVideoPlayerState> _playerKey = GlobalKey();
  
  bool _isTransitioning = false;
  bool _isVideoEndTransition = false;  // Track if transition was triggered by video end
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _videoFeedProvider = context.read<VideoFeedProvider>();
      _navigationManager = NavigationStateManager();
      _screenState = HomeScreenState(_videoFeedProvider);
      _navigationManager.navigateToScreen(_screenState);
      _isInitialized = true;
    }
  }

  @override
  void initState() {
    super.initState();
    dev.log('HomeScreen initialized', name: 'HomeScreen');
    _pageController = PageController();
    
    if (widget.initialVideoId != null) {
      dev.log('Initial video ID provided: ${widget.initialVideoId}', name: 'HomeScreen');
    }
  }

  void _onPageChanged(int index) async {
    dev.log('Page change triggered - index: $index, isVideoEnd: $_isVideoEndTransition', 
      name: 'HomeScreen');
    
    // Only block concurrent manual transitions
    // Allow transitions triggered by video end
    if (_isTransitioning && !_isVideoEndTransition) {
      dev.log('Ignoring manual page change - already transitioning', name: 'HomeScreen');
      return;
    }
    
    _isTransitioning = true;
    
    try {
      // Always end current session before transition
      await _videoFeedProvider.onVideoEnded();
      dev.log('Ended previous video session', name: 'HomeScreen');
      
      // Ensure proper video switch
      final success = await _videoFeedProvider.switchToVideo(index);
      if (!success) {
        dev.log('Failed to switch video in provider', name: 'HomeScreen');
        return;
      }

      if (_playerKey.currentState != null) {
        final targetVideo = _videoFeedProvider.videos[index];
        dev.log('Switching video player to: ${targetVideo.id}', name: 'HomeScreen');
        
        final preloadedController = _videoFeedProvider.getBufferedVideo(targetVideo.id);
        dev.log('Preloaded controller available: ${preloadedController != null}', 
          name: 'HomeScreen');
        
        await _playerKey.currentState!.switchToVideo(
          targetVideo,
          preloadedController: preloadedController,
        );
        
        // Ensure autoplay after transition
        if (preloadedController != null) {
          dev.log('Starting playback of new video', name: 'HomeScreen');
          await preloadedController.play();
        } else {
          dev.log('No controller available for autoplay', name: 'HomeScreen');
        }
        
        dev.log('Successfully switched video player', name: 'HomeScreen');
      } else {
        dev.log('No video player state available', name: 'HomeScreen');
      }
    } catch (e, stackTrace) {
      dev.log(
        'Error during video switch',
        name: 'HomeScreen',
        error: e,
        stackTrace: stackTrace
      );
      
      if (mounted) {
        dev.log('Recreating video player key after error', name: 'HomeScreen');
        setState(() {
          _playerKey = GlobalKey<HLSVideoPlayerState>();
        });
      }
    } finally {
      _isTransitioning = false;
      dev.log('Page change completed', name: 'HomeScreen');
    }
  }

  void _onVideoEnd() async {
    if (_isTransitioning) {
      dev.log('Ignoring video end - already transitioning', name: 'HomeScreen');
      return;
    }
    
    dev.log('Video ended - starting transition', name: 'HomeScreen');
    
    try {
      _isVideoEndTransition = true;  // Signal this is an auto-transition
      
      // First ensure the current video session is ended
      await _videoFeedProvider.onVideoEnded();
      dev.log('Video session ended', name: 'HomeScreen');
      
      // Then trigger the page change
      if (mounted && _pageController.hasClients) {
        dev.log('Starting page transition animation', name: 'HomeScreen');
        await _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        // Note: Don't need to handle video switching here as _onPageChanged will be called
        dev.log('Page transition animation completed', name: 'HomeScreen');
      } else {
        dev.log('Cannot transition page - widget unmounted or no page controller', 
          name: 'HomeScreen');
      }
    } finally {
      _isVideoEndTransition = false;  // Reset the flag
      _isTransitioning = false;
      dev.log('Video end handling completed', name: 'HomeScreen');
    }
  }

  void _onBufferProgress(String videoId, double progress) {
    dev.log('Buffer progress - videoId: $videoId, progress: ${(progress * 100).toStringAsFixed(1)}%', 
      name: 'HomeScreen');
    _videoFeedProvider.updateBufferProgress(videoId, progress);
  }

  @override
  void dispose() {
    _screenState.onExit();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FirebaseAuth>();
    final isAuthenticated = auth.currentUser != null;
    final videoFeed = context.watch<VideoFeedProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player with PageView for swipe gestures
          SizedBox.expand(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              scrollDirection: Axis.horizontal,
              physics: const PageScrollPhysics(),  // Keep swipe behavior
              itemCount: videoFeed.videoCount,
              itemBuilder: (context, index) {
                final video = videoFeed.videos[index];
                final isCurrentVideo = index == videoFeed.currentIndex;
                
                return SizedBox.expand(
                  child: HLSVideoPlayer(
                    key: isCurrentVideo ? _playerKey : null,
                    video: video,
                    preloadedController: videoFeed.getBufferedVideo(video.id),
                    autoplay: isCurrentVideo,
                    onBufferProgress: (progress) => _onBufferProgress(video.id, progress),
                    onVideoEnd: isCurrentVideo ? _onVideoEnd : null,
                  ),
                );
              },
            ),
          ),

          // UI Overlay (Top)
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Container(
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SearchScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Video Info Overlay (Bottom)
          if (videoFeed.currentVideo != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Video Info (Left)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '@${videoFeed.currentVideo!.author['name']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              videoFeed.currentVideo!.description,
                              style: const TextStyle(color: Colors.white),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Interaction Buttons (Right)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              videoFeed.hasLiked ? Icons.favorite : Icons.favorite_border,
                              color: isAuthenticated 
                                ? (videoFeed.hasLiked ? Colors.red : Colors.white)
                                : Colors.white.withOpacity(0.5),
                            ),
                            iconSize: 30,
                            onPressed: isAuthenticated ? () => videoFeed.toggleLike() : () {
                              // Show login prompt
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Please sign in to like videos'),
                                  action: SnackBarAction(
                                    label: 'Sign In',
                                    onPressed: () {
                                      // TODO: Navigate to sign in screen
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Sign in functionality coming soon'),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                          Text(
                            '${videoFeed.currentVideo!.likesCount}',
                            style: TextStyle(
                              color: isAuthenticated 
                                ? Colors.white 
                                : Colors.white.withOpacity(0.5)
                            ),
                          ),
                          const SizedBox(height: 16),
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline),
                            color: Colors.white,
                            iconSize: 30,
                            onPressed: () {
                              // TODO: Implement comments functionality
                            },
                          ),
                          Text(
                            '${videoFeed.currentVideo!.commentsCount}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: PrimaryNavBar(
        selectedIndex: 0,  // Home is selected
        onItemSelected: (index) {
          if (index == 4) {  // Profile tab
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const ProfileScreen(),
              ),
            );
          }
        },
      ),
    );
  }
} 