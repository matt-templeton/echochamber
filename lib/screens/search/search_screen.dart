import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/search/search_filters_sheet.dart';
import '../../repositories/video_repository.dart';
import '../../models/video_model.dart';
import '../../screens/home/home_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final VideoRepository _repository = VideoRepository();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  
  List<String>? _selectedGenres;
  List<String>? _selectedTags;
  List<Video> _videos = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _loadInitialVideos();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreVideos();
    }
  }

  Future<void> _loadInitialVideos() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final snapshot = await _repository.getTrendingVideos(limit: 20).first;
      if (mounted) {
        setState(() {
          _videos = snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
          if (snapshot.docs.isNotEmpty) {
            _lastDocument = snapshot.docs.last;
          }
          _hasMore = snapshot.docs.length == 20;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load videos: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final query = _searchController.text.isEmpty
          ? await _repository.getTrendingVideos(limit: 20).first
          : await _repository.searchVideos(
              searchQuery: _searchController.text,
              genres: _selectedGenres,
              tags: _selectedTags,
              limit: 20,
              startAfter: _lastDocument,
            );

      if (mounted) {
        setState(() {
          if (query is QuerySnapshot) {
            final newVideos = query.docs.map((doc) => Video.fromFirestore(doc)).toList();
            _videos.addAll(newVideos);
            if (query.docs.isNotEmpty) {
              _lastDocument = query.docs.last;
            }
            _hasMore = query.docs.length == 20;
          } else if (query is List<Video>) {
            _videos.addAll(query);
            _hasMore = query.length == 20;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load more videos: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showFiltersSheet() async {
    final result = await showModalBottomSheet<Map<String, List<String>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SearchFiltersSheet(),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedGenres = result['genres'];
        _selectedTags = result['tags'];
      });
      _performSearch();
    }
  }

  Future<void> _performSearch() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _videos.clear();
      _lastDocument = null;
    });

    try {
      if (_searchController.text.isEmpty && _selectedGenres == null && _selectedTags == null) {
        await _loadInitialVideos();
        return;
      }

      final results = await _repository.searchVideos(
        searchQuery: _searchController.text,
        genres: _selectedGenres,
        tags: _selectedTags,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _videos = results;
          _isLoading = false;
          _hasMore = results.length == 20;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e.toString().contains('FAILED_PRECONDITION')) {
            _error = 'Search index is being created. Please try again in a few minutes.';
          } else {
            _error = 'Failed to perform search: ${e.toString()}';
          }
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search videos...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedGenres != null || _selectedTags != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${(_selectedGenres?.length ?? 0) + (_selectedTags?.length ?? 0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.filter_list),
                            onPressed: _showFiltersSheet,
                          ),
                        ],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _searchController.text.isEmpty ? _loadInitialVideos : _performSearch,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_videos.isEmpty && _isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_videos.isEmpty) {
      return const Center(
        child: Text('No videos found'),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _videos.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _videos.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final video = _videos[index];
        return InkWell(
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => HomeScreen(
                  initialVideoId: video.id,
                ),
              ),
            );
          },
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: video.thumbnailUrl != null
                      ? Image.network(
                          video.thumbnailUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.grey[700],
                          child: const Center(
                            child: Icon(Icons.video_library, size: 40),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${video.author['name']}',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 