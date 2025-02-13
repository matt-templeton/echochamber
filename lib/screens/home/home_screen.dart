import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/video/hls_video_player.dart';
import '../../widgets/primary_nav_bar.dart';
import '../../models/video_model.dart';
// import '../../repositories/video_repository.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';
import 'dart:developer' as dev;
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
  late final VideoFeedProvider _videoFeedProvider;
  late final NavigationStateManager _navigationManager;
  late final HomeScreenState _screenState;
  late final PageController _pageController;
  bool _isInitialized = false;
  bool _isInfoExpanded = true;  // Track expansion state
  bool _isAnimating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _videoFeedProvider = context.read<VideoFeedProvider>();
      _navigationManager = NavigationStateManager();
      _screenState = HomeScreenState(_videoFeedProvider);
      _pageController = PageController();
      _navigationManager.navigateToScreen(_screenState);
      _isInitialized = true;
    }
  }

  @override
  void initState() {
    super.initState();
    dev.log('HomeScreen initialized', name: 'HomeScreen');
  }

  Future<void> _toggleLike() async {
    await _videoFeedProvider.toggleLike();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _screenState.onExit();
    super.dispose();
  }

  Future<void> _animateToNextVideo() async {
    if (_isAnimating) return;
    _isAnimating = true;
    
    try {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } finally {
      _isAnimating = false;
    }
  }

  Widget _buildVideoInfo(Video video, bool isAuthenticated, VideoFeedProvider videoFeed) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 56 + MediaQuery.of(context).padding.bottom,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Info section with animation
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Info icon that's always visible
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () => setState(() => _isInfoExpanded = !_isInfoExpanded),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: _isInfoExpanded ? 0.0 : 0.0,
                        child: Icon(
                          _isInfoExpanded ? Icons.close : Icons.info_outline,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                // Animated info content
                AnimatedSlide(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  offset: _isInfoExpanded ? Offset.zero : const Offset(-1.0, 0.0),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isInfoExpanded ? 1.0 : 0.0,
                    child: Container(
                      padding: const EdgeInsets.only(left: 50), // Space for the icon
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '@${video.author['name']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            video.description,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Interaction buttons
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
                onPressed: isAuthenticated ? _toggleLike : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please sign in to like videos'),
                      action: SnackBarAction(
                        label: 'Sign In',
                        onPressed: () {
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
                '${video.likesCount}',
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
                '${video.commentsCount}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FirebaseAuth>();
    final isAuthenticated = auth.currentUser != null;
    final videoFeed = context.watch<VideoFeedProvider>();
    final currentVideo = videoFeed.currentVideo;

    return WillPopScope(
      onWillPop: () async => false,  // Prevent back gesture
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (currentVideo != null)
              PageView.builder(
                scrollDirection: Axis.vertical,
                controller: _pageController,
                onPageChanged: (index) {
                  videoFeed.moveToNextVideo();
                },
                itemBuilder: (context, index) {
                  return SizedBox.expand(
                    child: HLSVideoPlayer(
                      key: ValueKey(currentVideo.id),
                      video: currentVideo,
                      autoplay: true,
                      enableAudioOnInteraction: true,
                      onVideoEnd: _animateToNextVideo,
                    ),
                  );
                },
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
            if (currentVideo != null)
              _buildVideoInfo(currentVideo, isAuthenticated, videoFeed),

            // Loading indicator
            if (videoFeed.isLoading)
              const Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: CircularProgressIndicator(),
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
      ),
    );
  }
} 