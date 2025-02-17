import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/video/hls_video_player.dart';
import '../../widgets/video/video_comments.dart';
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
  bool _isDragging = false;
  bool _wasPlayingBeforeDrag = false;  // Add this line
  bool _wasPlayingBeforeSearch = false;
  bool _isCommentsExpanded = false;
  bool _isAudioControlsVisible = false;
  HLSVideoPlayerState? _currentPlayerState;

  static const double _kSwipeThreshold = 0.3; // 30% of screen width

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _videoFeedProvider = context.read<VideoFeedProvider>();
      _navigationManager = NavigationStateManager();
      _screenState = HomeScreenState(_videoFeedProvider);
      _pageController = PageController(
        initialPage: 1000, // Start at a large number to allow "infinite" scrolling both ways
        viewportFraction: 1.0,
      );
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

  void _toggleComments() {  // Add this method
    setState(() {
      _isCommentsExpanded = !_isCommentsExpanded;
    });
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

  void _onDragStart(DragStartDetails details) {
    if (_isDragging) return;  // Prevent multiple drag starts
    _isDragging = true;
    _wasPlayingBeforeDrag = _currentPlayerState?.controller?.value.isPlaying ?? false;
    if (_wasPlayingBeforeDrag) {
      _currentPlayerState?.pauseVideo();
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    
    // Update page position based on drag
    final screenWidth = MediaQuery.of(context).size.width;
    final currentPage = _pageController.page ?? 0;
    final dragDistance = details.primaryDelta ?? 0;
    final newPage = currentPage - (dragDistance / screenWidth);
    
    // Only allow dragging right if we can go back
    if (!_videoFeedProvider.canGoBack && newPage < currentPage) {
      return;
    }
    
    // Use jumpTo for smoother dragging
    _pageController.jumpTo(_pageController.offset - dragDistance);
  }

  void _onDragEnd(DragEndDetails details, BuildContext context) {
    if (!_isDragging) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final dragDistance = _pageController.offset - (_pageController.page ?? 0) * screenWidth;
    final dragPercentage = dragDistance.abs() / screenWidth;

    // If drag was too small, snap back
    if (dragPercentage < _kSwipeThreshold) {
      _snapToCurrentPage();
      return;
    }

    // Handle swipe completion - only move one page at a time
    if (dragDistance > 0 && _videoFeedProvider.canGoBack) {
      // Swipe right - go to previous video
      _moveToPage(_pageController.page!.round() - 1);
    } else if (dragDistance < 0) {
      // Swipe left - go to next video
      _moveToPage(_pageController.page!.round() + 1);
    } else {
      // If we can't go back or invalid drag, snap to current
      _snapToCurrentPage();
    }
  }

  void _snapToCurrentPage() {
    _pageController.animateToPage(
      _pageController.page!.round(),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    ).then((_) {
      _isDragging = false;
      if (_wasPlayingBeforeDrag) {
        _currentPlayerState?.resumeVideo();
      }
    });
  }

  void _moveToPage(int page) {
    if (_isAnimating) return;
    _isAnimating = true;
    
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    ).then((_) {
      _isDragging = false;
      _isAnimating = false;
    });
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
        body: Column(  // Wrap Stack in Column
          children: [
            // Video and overlays container
            Expanded(  // This will take remaining space after comments
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (currentVideo != null)
                    GestureDetector(
                      onHorizontalDragStart: _onDragStart,
                      onHorizontalDragUpdate: _onDragUpdate,
                      onHorizontalDragEnd: (details) => _onDragEnd(details, context),
                      child: PageView.builder(
                        scrollDirection: Axis.horizontal,
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),  // Disable built-in gestures
                        onPageChanged: (index) {
                          final currentPage = _pageController.page ?? 0;
                          if (index > currentPage) {
                            videoFeed.moveToNextVideo();
                          } else if (videoFeed.canGoBack) {
                            videoFeed.moveToPreviousVideo();
                          } else {
                            _pageController.jumpToPage(currentPage.round());
                          }
                        },
                        itemBuilder: (context, index) {
                          return SizedBox.expand(
                            child: HLSVideoPlayer(
                              key: ValueKey(currentVideo.id),
                              video: currentVideo,
                              autoplay: true,
                              enableAudioOnInteraction: true,
                              onVideoEnd: _animateToNextVideo,
                              onPlayerStateCreated: (state) => _currentPlayerState = state,
                              onAudioControlsShow: () {
                                if (_isInfoExpanded) {
                                  setState(() => _isInfoExpanded = false);
                                }
                              },
                              onAudioControlsVisibilityChanged: (isVisible) {
                                setState(() => _isAudioControlsVisible = isVisible);
                              },
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
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              margin: const EdgeInsets.only(left: 8),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(50),
                                  onTap: () async {
                                    final playerState = _currentPlayerState;
                                    if (playerState == null) return;
                                    
                                    _wasPlayingBeforeSearch = playerState.controller?.value.isPlaying ?? false;
                                    playerState.pauseVideo();
                                    
                                    final selectedVideoId = await Navigator.of(context).push<String>(
                                      MaterialPageRoute(
                                        builder: (context) => const SearchScreen(),
                                      ),
                                    );

                                    if (!mounted) return;

                                    if (selectedVideoId != null) {
                                      await _videoFeedProvider.loadVideoById(selectedVideoId);
                                      if (mounted) {
                                        setState(() {
                                          _currentPlayerState = null;
                                        });
                                      }
                                      return;
                                    }
                                    
                                    if (mounted && _wasPlayingBeforeSearch) {
                                      playerState.resumeVideo();
                                    }
                                  },
                                  hoverColor: Colors.white.withOpacity(0.2),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.search,
                                      color: Colors.white,
                                      size: 28,
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

                  // Video Info Overlay (Bottom)
                  if (currentVideo != null && !_isAudioControlsVisible)
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
            ),
            // Comments section
            if (currentVideo != null)
              VideoComments(
                isExpanded: _isCommentsExpanded,
                onCollapse: _toggleComments,
                videoId: currentVideo.id,
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
                onPressed: _toggleComments,  // Update this line
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
} 