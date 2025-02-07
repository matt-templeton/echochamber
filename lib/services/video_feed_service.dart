import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/video_model.dart';
import '../repositories/video_repository.dart';

class VideoFeedService {
  final VideoRepository _videoRepository;
  DocumentSnapshot? _lastDocument;

  VideoFeedService({VideoRepository? videoRepository})
      : _videoRepository = videoRepository ?? VideoRepository();

  Future<Video?> getNextVideo() async {
    try {
      final querySnapshot = await _videoRepository.getNextFeedVideo(
        startAfter: _lastDocument,
      );

      if (querySnapshot.docs.isEmpty) {
        // If no more videos after last document, start from beginning
        _lastDocument = null;
        return getNextVideo();
      }

      _lastDocument = querySnapshot.docs.first;
      return Video.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      return null;
    }
  }

  Future<DocumentSnapshot> _getFirstVideo() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('videos')
        .orderBy('uploadedAt', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('No videos found in database');
    }

    return querySnapshot.docs.first;
  }

  // Reset the feed to start from the beginning
  void resetFeed() {
    _lastDocument = null;
  }
} 