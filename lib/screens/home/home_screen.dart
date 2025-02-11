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
  static const int _maxBufferedVideos = 3;
  
  late final VideoList _videoList;
  late final VideoBufferManager _bufferManager;
  late final VideoRepository _repository;
  late final PageController _pageController;
  GlobalKey<HLSVideoPlayerState> _playerKey = GlobalKey();
  final Set<String> _nextVideoFetchedFor = {};
  
  bool _isLoading = false;
  bool _hasMoreVideos = true;
  bool _isTransitioning = false;  // Add transition lock

  @override
  void initState() {
    super.initState();
    dev.log('HomeScreen initialized', name: 'HomeScreen');
    
    _videoList = VideoList(maxLength: 10);  // Keep 10 videos in list max
    _bufferManager = VideoBufferManager(maxBufferedVideos: _maxBufferedVideos);
    _repository = VideoRepository();
    _pageController = PageController();
    
    // Listen for video added events
    _videoList.addListener(_handleVideoListChanged);
    
    _initializeVideoFeed();
  }

  void _handleVideoListChanged() {
    final currentVideo = _videoList.currentVideo;
    if (currentVideo == null) return;

    dev.log('VideoList changed - videos in list: ${_videoList.videos.map((v) => v.id).join(", ")}', name: 'HomeScreen');
    dev.log('Current video index: ${_videoList.currentIndex}', name: 'HomeScreen');

    // Get the index of the current video
    final index = _videoList.videos.indexOf(currentVideo);
    
    // Determine buffer priority based on position
    BufferPriority priority;
    if (index == _videoList.currentIndex) {
      priority = BufferPriority.high;  // Current video gets high priority
    } else if (index == _videoList.currentIndex + 1) {
      priority = BufferPriority.medium;  // Next video gets medium priority
    } else {
      priority = BufferPriority.low;  // Future videos get low priority
    }

    // Add to buffer manager with appropriate priority
    _bufferManager.addToBuffer(currentVideo, priority);
    
    dev.log('Video added to buffer: ${currentVideo.id} with priority: $priority', name: 'HomeScreen');
  }

  Future<void> _initializeVideoFeed() async {
    dev.log('Initializing video feed', name: 'HomeScreen');
    
    if (widget.initialVideoId != null) {
      // Load specific video if ID provided
      final video = await _repository.getVideoById(widget.initialVideoId!);
      if (video != null) {
        _videoList.addVideo(video);
        _bufferManager.addToBuffer(video, BufferPriority.high);
      }
    }
    
    // Load initial set of videos
    await _loadMoreVideos();
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoading || !_hasMoreVideos) {
      dev.log('Skipping _loadMoreVideos: isLoading=$_isLoading, hasMoreVideos=$_hasMoreVideos', name: 'HomeScreen');
      return;
    }
    
    setState(() => _isLoading = true);
    dev.log('Starting to load more videos...', name: 'HomeScreen');
    
    try {
      final snapshot = await _repository.getNextFeedVideo(
        startAfter: _videoList.length > 0 ? 
          await _repository.getVideoDocumentById(_videoList.videos.last.id) : null
      );
      
      if (snapshot.docs.isEmpty) {
        dev.log('No more videos available from repository', name: 'HomeScreen');
        _hasMoreVideos = false;
        return;
      }

      dev.log('Received ${snapshot.docs.length} videos from repository', name: 'HomeScreen');

      for (final doc in snapshot.docs) {
        final video = Video.fromFirestore(doc);
        dev.log('Processing video from repository: ${video.id}', name: 'HomeScreen');
        final wasAdded = _videoList.addVideo(video);
        dev.log('Attempt to add video ${video.id} to list: ${wasAdded ? "SUCCESS" : "FAILED"}', name: 'HomeScreen');
        
        if (wasAdded) {
          final currentIndex = _videoList.currentIndex;
          if (_videoList.length <= _maxBufferedVideos || 
              _videoList.videos.indexOf(video) <= currentIndex + 2) {
            dev.log('Adding video ${video.id} to buffer with priority: ${_videoList.length == 1 ? "HIGH" : "MEDIUM"}', name: 'HomeScreen');
            _bufferManager.addToBuffer(
              video,
              _videoList.length == 1 ? BufferPriority.high : BufferPriority.medium
            );
          }
        }
      }
    } catch (e, stackTrace) {
      dev.log('Error loading videos', name: 'HomeScreen', error: e, stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onPageChanged(int index) async {
    // Prevent concurrent transitions
    if (_isTransitioning) {
      dev.log('Page change blocked - transition already in progress', name: 'HomeScreen');
      return;
    }
    
    _isTransitioning = true;
    dev.log('========== PAGE CHANGE EVENT ==========', name: 'HomeScreen');
    dev.log('PageView detected swipe to index: $index from previous index: ${_videoList.currentIndex}', name: 'HomeScreen');
    
    try {
      if (index < 0 || index >= _videoList.length) {
        dev.log('Invalid index: $index, ignoring page change', name: 'HomeScreen');
        return;
      }

      final targetVideo = _videoList.videos[index];
      dev.log('Target video for switch: ${targetVideo.id}', name: 'HomeScreen');
      
      // Update current index in video list
      bool moved = false;
      if (index > _videoList.currentIndex) {
        dev.log('Swiped FORWARD to next video', name: 'HomeScreen');
        moved = _videoList.moveToNext();
      } else if (index < _videoList.currentIndex) {
        dev.log('Swiped BACKWARD to previous video', name: 'HomeScreen');
        moved = _videoList.moveToPrevious();
      }

      if (!moved) {
        dev.log('Failed to move to target index: $index', name: 'HomeScreen');
        return;
      }

      // Force UI update for video info
      if (mounted) {
        setState(() {});
      }

      // Check buffer state
      final bufferedController = _bufferManager.getBufferedVideo(targetVideo.id);
      dev.log('Buffer state for ${targetVideo.id}: ${bufferedController != null ? "FOUND in buffer" : "NOT in buffer"}', name: 'HomeScreen');
      
      // Ensure we have a valid player key
      if (_playerKey.currentState == null) {
        dev.log('Player key state is null, rebuilding player', name: 'HomeScreen');
        setState(() {
          _playerKey = GlobalKey<HLSVideoPlayerState>();
        });
        return;
      }

      // Switch video with a timeout
      await Future.any([
        _playerKey.currentState!.switchToVideo(
          targetVideo,
          preloadedController: bufferedController,
        ),
        Future.delayed(const Duration(seconds: 5), () {
          throw TimeoutException('Video switch timed out');
        }),
      ]);
      
      dev.log('Video switch completed successfully', name: 'HomeScreen');

      // Ensure video starts playing
      if (_playerKey.currentState != null) {
        await _playerKey.currentState!.ensurePlayback();
      }

      // Background tasks
      Future.microtask(() async {
        // Load more videos if needed
        if (index >= _videoList.length - 2) {
          dev.log('Near end of list, triggering load of more videos...', name: 'HomeScreen');
          await _loadMoreVideos();
        }

        // Buffer management
        if (index < _videoList.length - 1) {
          final nextVideo = _videoList.videos[index + 1];
          dev.log('Checking next video buffer state: ${nextVideo.id}', name: 'HomeScreen');
          if (!_bufferManager.hasBufferedVideo(nextVideo.id)) {
            dev.log('Next video not in buffer, adding to buffer: ${nextVideo.id}', name: 'HomeScreen');
            await _bufferManager.addToBuffer(nextVideo, BufferPriority.medium);
          }
        }
      });

    } catch (e, stackTrace) {
      dev.log(
        'Error during video switch',
        name: 'HomeScreen',
        error: e,
        stackTrace: stackTrace
      );
      
      // Recovery attempt
      if (mounted) {
        setState(() {
          _playerKey = GlobalKey<HLSVideoPlayerState>();
        });
      }
    } finally {
      _isTransitioning = false;
      dev.log('========== PAGE CHANGE COMPLETE ==========', name: 'HomeScreen');
    }
  }

  void _onBufferProgress(String videoId, double progress) {
    // Update buffer progress in buffer manager
    _bufferManager.updateBufferProgress(videoId, progress);
    
    // When a video reaches 25% buffered, fetch and add next video
    // Only trigger fetch if we haven't already fetched for this video
    if (!_nextVideoFetchedFor.contains(videoId)) {
      final currentIndex = _videoList.videos.indexWhere((v) => v.id == videoId);
      if (currentIndex >= 0 && currentIndex == _videoList.currentIndex) {
        if (progress >= 0.25) {
          dev.log('Video $videoId buffer at ${(progress * 100).toStringAsFixed(1)}% - triggering next video fetch', name: 'HomeScreen');
          _nextVideoFetchedFor.add(videoId);  // Mark as fetched
          _loadNextVideoIntoList();
        } else {
          dev.log('Video $videoId buffer at ${(progress * 100).toStringAsFixed(1)}% - waiting for 25% to trigger fetch', name: 'HomeScreen');
        }
      }
    }

    // Log buffer progress for debugging
    dev.log('Buffer progress for video $videoId: ${(progress * 100).toStringAsFixed(1)}%', name: 'HomeScreen');
  }

  Future<void> _loadNextVideoIntoList() async {
    dev.log('Starting _loadNextVideoIntoList', name: 'HomeScreen');
    if (_isLoading) {
      dev.log('Skipping _loadNextVideoIntoList: already loading', name: 'HomeScreen');
      return;
    }
    
    try {
      dev.log('Fetching next video from repository', name: 'HomeScreen');
      final snapshot = await _repository.getNextFeedVideo(
        startAfter: _videoList.length > 0 ? 
          await _repository.getVideoDocumentById(_videoList.videos.last.id) : null
      );
      
      if (snapshot.docs.isNotEmpty) {
        final video = Video.fromFirestore(snapshot.docs.first);
        dev.log('Adding video ${video.id} to list', name: 'HomeScreen');
        final added = _videoList.addVideo(video);  // This will fire VideoAdded event
        dev.log('Video added successfully: $added', name: 'HomeScreen');
      } else {
        dev.log('No more videos available from repository', name: 'HomeScreen');
      }
    } catch (e, stackTrace) {
      dev.log(
        'Error loading next video at buffer threshold', 
        name: 'HomeScreen', 
        error: e, 
        stackTrace: stackTrace
      );
    }
  }

  @override
  void dispose() {
    _videoList.removeListener(_handleVideoListChanged);
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
                
                return Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: HLSVideoPlayer(
                      key: isCurrentVideo ? _playerKey : null,
                      video: video,
                      preloadedController: _bufferManager.getBufferedVideo(video.id),
                      autoplay: isCurrentVideo,
                      onBufferProgress: (progress) => _onBufferProgress(video.id, progress),
                    ),
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