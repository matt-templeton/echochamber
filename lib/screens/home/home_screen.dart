import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/primary_nav_bar.dart';
import '../../widgets/video/video_player.dart';
import '../../providers/video_feed_provider.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isFollowingSelected = false;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VideoFeedProvider(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Video Player (Full Screen)
            Consumer<VideoFeedProvider>(
              builder: (context, feedProvider, child) {
                if (feedProvider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final video = feedProvider.currentVideo;
                if (video == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'No videos available',
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => feedProvider.loadNextVideo(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                return SizedBox.expand(
                  child: EchoVideoPlayer(
                    videoUrl: video.videoUrl,
                    autoPlay: true,
                    onVideoEnd: () => feedProvider.loadNextVideo(),
                  ),
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
                          onPressed: () {},
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
              // bottom: MediaQuery.of(context).padding.bottom, // Account for nav bar
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
                  IconButton(
                    icon: const Icon(Icons.favorite_border, color: Colors.white, size: 30),
                    onPressed: () {},
                  ),
                  const Text('0', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 30),
                    onPressed: () {},
                  ),
                  const Text('0', style: TextStyle(color: Colors.white)),
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