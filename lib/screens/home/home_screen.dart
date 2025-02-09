import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/video_feed_provider.dart';
import '../../widgets/video/hls_video_player.dart';
import '../../widgets/primary_nav_bar.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';
import '../../utils/number_formatter.dart';
import 'dart:developer' as dev;

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
  final PageController _pageController = PageController(initialPage: 1);
  // bool _isSwipingLeft = false;
  int _selectedIndex = 0;
  bool _isFollowingSelected = false;
  bool _isLoading = false;
  // bool _isProcessingPageChange = false;
  // int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    dev.log('HomeScreen initialized', name: 'HomeScreen');
    // Initialize feed when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      if (widget.initialVideoId != null) {
        dev.log('Loading initial video: ${widget.initialVideoId}', name: 'HomeScreen');
        context.read<VideoFeedProvider>().loadSpecificVideo(widget.initialVideoId!);
      } else {
        dev.log('Loading next video', name: 'HomeScreen');
        context.read<VideoFeedProvider>().loadNextVideo();
      }
    });
  }

  @override
  void dispose() {
    dev.log('Disposing HomeScreen', name: 'HomeScreen');
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SearchScreen(),
      ),
    );
  }

  // Future<void> _onPageChanged(int page) async {
  //   if (_isProcessingPageChange || !mounted) return;

  //   try {
  //     _isProcessingPageChange = true;
  //     final provider = context.read<VideoFeedProvider>();
      
  //     // Get current video player key to find the widget
  //     final currentVideoKey = provider.currentVideo != null ? 
  //         ValueKey(provider.currentVideo!.id) : null;
      
  //     // Find the video player widget and trigger cleanup
  //     if (currentVideoKey != null) {
  //       dev.log('Starting preemptive cleanup before page change', name: 'HomeScreen');
  //       // Set controller to non-ready state before cleanup
  //       provider.setControllerReady(false);
        
  //       // Small delay to ensure UI updates
  //       await Future.delayed(const Duration(milliseconds: 100));
  //     }

  //     if (!mounted) return;

  //     if (page > _currentPage) {
  //       dev.log('Loading next video', name: 'HomeScreen');
  //       await provider.loadNextVideo();
  //     } else if (page < _currentPage) {
  //       dev.log('Loading previous video', name: 'HomeScreen');
  //       await provider.loadPreviousVideo();
  //     }

  //     if (!mounted) return;
      
  //     setState(() {
  //       _currentPage = page;
  //     });

  //     // Reset page controller after state is updated
  //     if (_pageController.page != 0) {
  //       await Future.delayed(const Duration(milliseconds: 100));
  //       if (mounted) {
  //         _pageController.jumpToPage(0);
  //       }
  //     }
  //   } catch (e) {
  //     dev.log('Error during page change: $e', name: 'HomeScreen', error: e);
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Error loading video')),
  //       );
  //     }
  //   } finally {
  //     if (mounted) {
  //       _isProcessingPageChange = false;
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final provider = context.read<VideoFeedProvider>();
        provider.dispose();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Video Player with PageView
            Consumer<VideoFeedProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading || _isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  );
                }

                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          provider.error!,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.loadNextVideo(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.currentVideo == null) {
                  return const Center(
                    child: Text(
                      'No videos available',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                return PageView(
                  controller: _pageController,
                  // onPageChanged: _onPageChanged,
                  children: [
                    // Previous page (for left swipe)
                    Container(color: Colors.black),
                    // Current video
                    GestureDetector(
                      // onHorizontalDragStart: (details) {
                      //   // if (!provider.isLoading) {
                      //   //   _isSwipingLeft = details.globalPosition.dx < MediaQuery.of(context).size.width / 2;
                      //   // }
                      //   dev.log('Horizontal drag started', name: 'HomeScreen');
                      // },
                      child: HLSVideoPlayer(
                        key: ValueKey(provider.currentVideo!.id),
                        videoUrl: provider.currentVideo!.videoUrl,
                        videoId: provider.currentVideo!.id,
                        autoplay: true,
                        showControls: true,
                        onVideoEnd: () {
                          if (!provider.isLoading) {
                            provider.loadNextVideo();
                          }
                        },
                      ),
                    ),
                    // Next page (for right swipe)
                    Container(color: Colors.black),
                  ],
                );
              },
            ),

            // UI Overlay (Top)
            SafeArea(
              child: Column(
                children: [
                  // Top Navigation
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Centered Following/For You Toggle
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Consumer<VideoFeedProvider>(
                          builder: (context, feedProvider, child) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() => _isFollowingSelected = true);
                                    feedProvider.setFeedType('following');
                                  },
                                  child: Text(
                                    'Following',
                                    style: TextStyle(
                                      color: _isFollowingSelected ? Colors.white : Colors.white60,
                                      fontSize: 16,
                                      fontWeight: _isFollowingSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() => _isFollowingSelected = false);
                                    feedProvider.setFeedType('for_you');
                                  },
                                  child: Text(
                                    'For You',
                                    style: TextStyle(
                                      color: !_isFollowingSelected ? Colors.white : Colors.white60,
                                      fontSize: 16,
                                      fontWeight: !_isFollowingSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      // Search Button positioned on the right
                      Positioned(
                        right: 8,
                        child: IconButton(
                          icon: const Icon(Icons.search, color: Colors.white),
                          onPressed: _navigateToSearch,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Video Info Overlay (Bottom)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Consumer<VideoFeedProvider>(
                    builder: (context, feedProvider, child) {
                      final video = feedProvider.currentVideo;
                      if (video == null) return const SizedBox.shrink();
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                      );
                    },
                  ),
                ],
              ),
            ),

            // Interaction Buttons Overlay (Right)
            Positioned(
              right: 16,
              bottom: 16,
              child: Column(
                children: [
                  Consumer<VideoFeedProvider>(
                    builder: (context, provider, child) {
                      final video = provider.currentVideo;
                      if (video == null) return const SizedBox.shrink();

                      return Column(
                        children: [
                          IconButton(
                            icon: Icon(
                              provider.hasLiked ? Icons.favorite : Icons.favorite_border,
                              color: provider.hasLiked ? Colors.red : Colors.white,
                              size: 30,
                            ),
                            onPressed: () => provider.toggleLike(),
                          ),
                          Text(
                            formatNumber(video.likesCount),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 30),
                            onPressed: () {},
                          ),
                          Text(
                            formatNumber(video.commentsCount),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: PrimaryNavBar(
          selectedIndex: _selectedIndex,
          onItemSelected: (index) {
            if (index != _selectedIndex) {
              if (index == 4) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              }
              setState(() => _selectedIndex = index);
            }
          },
        ),
      ),
    );
  }
} 