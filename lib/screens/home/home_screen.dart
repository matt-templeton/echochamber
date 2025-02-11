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
  late final VideoList _videoList;
  late final VideoBufferManager _bufferManager;
  late final VideoRepository _repository;
  late final PageController _pageController;
  GlobalKey<HLSVideoPlayerState> _playerKey = GlobalKey();
  
  bool _isLoading = false;
  bool _hasMoreVideos = true;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    dev.log('HomeScreen initialized', name: 'HomeScreen');
    
    _videoList = VideoList(maxLength: 10);
    _bufferManager = VideoBufferManager();
    _repository = VideoRepository();
    _pageController = PageController();
    
    _initializeVideoFeed();
  }

  Future<void> _initializeVideoFeed() async {
    dev.log('Initializing video feed', name: 'HomeScreen');
    
    if (widget.initialVideoId != null) {
      final video = await _repository.getVideoById(widget.initialVideoId!);
      if (video != null) {
        _videoList.addVideo(video);
        _bufferManager.addToBuffer(video);
      }
    }
    
    await _loadMoreVideos();
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoading || !_hasMoreVideos) {
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final snapshot = await _repository.getNextFeedVideo(
        startAfter: _videoList.length > 0 ? 
          await _repository.getVideoDocumentById(_videoList.videos.last.id) : null
      );
      
      if (snapshot.docs.isEmpty) {
        _hasMoreVideos = false;
        return;
      }

      for (final doc in snapshot.docs) {
        final video = Video.fromFirestore(doc);
        final wasAdded = _videoList.addVideo(video);
        
        // Only buffer the first video initially
        if (wasAdded && _videoList.length == 1) {
          await _bufferManager.addToBuffer(video);
        }
      }
    } catch (e, stackTrace) {
      dev.log('Error loading videos', 
        name: 'HomeScreen', 
        error: e, 
        stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onPageChanged(int index) async {
    if (_isTransitioning) {
      return;
    }
    
    _isTransitioning = true;
    dev.log('========== PAGE CHANGE EVENT ==========', name: 'HomeScreen');
    
    try {
      if (index < 0 || index >= _videoList.length) {
        return;
      }

      final targetVideo = _videoList.videos[index];
      bool moved = false;
      
      if (index > _videoList.currentIndex) {
        moved = _videoList.moveToNext();
      } else if (index < _videoList.currentIndex) {
        moved = _videoList.moveToPrevious();
      }

      if (!moved) return;

      if (mounted) {
        setState(() {});
      }

      // Buffer new video
      await _bufferManager.addToBuffer(targetVideo);
      
      if (_playerKey.currentState != null) {
        await _playerKey.currentState!.switchToVideo(
          targetVideo,
          preloadedController: _bufferManager.getBufferedVideo(targetVideo.id),
        );
      }

      // Load more videos if needed
      if (index >= _videoList.length - 2) {
        await _loadMoreVideos();
      }

    } catch (e, stackTrace) {
      dev.log(
        'Error during video switch',
        name: 'HomeScreen',
        error: e,
        stackTrace: stackTrace
      );
      
      if (mounted) {
        setState(() {
          _playerKey = GlobalKey<HLSVideoPlayerState>();
        });
      }
    } finally {
      _isTransitioning = false;
    }
  }

  void _onBufferProgress(String videoId, double progress) {
    _bufferManager.updateBufferProgress(videoId, progress);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bufferManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              physics: const PageScrollPhysics(),
              itemCount: _videoList.length,
              itemBuilder: (context, index) {
                final video = _videoList.videos[index];
                final isCurrentVideo = index == _videoList.currentIndex;
                
                return SizedBox.expand(
                  child: HLSVideoPlayer(
                    key: isCurrentVideo ? _playerKey : null,
                    video: video,
                    preloadedController: _bufferManager.getBufferedVideo(video.id),
                    autoplay: isCurrentVideo,
                    onBufferProgress: (progress) => _onBufferProgress(video.id, progress),
                  ),
                );
              },
            ),
          ),

          // UI Overlay (Top)
          Positioned(  // Use Positioned instead of SafeArea
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Container(
              height: 56,
              child: Row(  // Use Row instead of Stack for better layout
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
          if (_videoList.currentVideo != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom,  // Account for safe area
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
                              '@${_videoList.currentVideo!.author['name']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                              _videoList.currentVideo!.description,
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
                            icon: const Icon(Icons.favorite_border),
                            color: Colors.white,
                            iconSize: 30,
                            onPressed: () {
                              // TODO: Implement like functionality
                            },
                          ),
                          const Text(
                            '0',
                            style: TextStyle(color: Colors.white),
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
                          const Text(
                            '0',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Loading indicator
          if (_isLoading)
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
    );
  }
} 