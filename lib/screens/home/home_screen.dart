import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/video_feed_provider.dart';
import '../../widgets/video/video_queue.dart';
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
  int _selectedIndex = 0;
  bool _isFollowingSelected = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    dev.log('HomeScreen initialized', name: 'HomeScreen');
  }

  void _navigateToSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SearchScreen(),
      ),
    );
  }

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
            // Video Queue
            VideoQueue(
              queueSize: 3,
              initialVideoId: widget.initialVideoId,
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