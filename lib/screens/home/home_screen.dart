import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/primary_nav_bar.dart';
import '../../widgets/video_player_widget.dart';

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
    // Calculate the bottom margin to be just above the navigation bar
    final bottomMargin = MediaQuery.of(context).padding.bottom;
    
    return Scaffold(
      body: Stack(
        children: [
          // Video Player
          const VideoPlayerWidget(),

          // Top Bar
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _isFollowingSelected = true),
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
                            onPressed: () => setState(() => _isFollowingSelected = false),
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

          // Video Interaction Buttons (Right Side)
          Positioned(
            right: 16,
            bottom: bottomMargin,
            child: Column(
              children: [
                // Like Button
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.favorite_border, color: Colors.white),
                      onPressed: () {},
                    ),
                    const Text(
                      '0',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Comment Button
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                      onPressed: () {},
                    ),
                    const Text(
                      '0',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Video Info (Bottom Left)
          Positioned(
            left: 16,
            bottom: bottomMargin,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Creator Name and Time
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: '@creator ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: '• 2h ago',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Video Title
                const Text(
                  'Video Title',
                  style: TextStyle(
                    color: Colors.white,
                  ),
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
              context.go('/profile');
            }
            setState(() => _selectedIndex = index);
          }
        },
      ),
    );
  }
} 