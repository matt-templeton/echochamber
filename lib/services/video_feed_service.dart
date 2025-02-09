import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/video_model.dart';
import '../repositories/video_repository.dart';

class VideoFeedService {
  final VideoRepository _repository;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreVideos = true;

  VideoFeedService({VideoRepository? repository})
      : _repository = repository ?? VideoRepository();

  Future<Video?> getNextVideo() async {
    try {
      if (!_hasMoreVideos && _lastDocument != null) {
        _lastDocument = null;
      }

      final querySnapshot = await _repository.getNextFeedVideo(
        startAfter: _lastDocument,
      );

      if (querySnapshot.docs.isEmpty) {
        _hasMoreVideos = false;
        _lastDocument = null;
        return null;
      }

      _lastDocument = querySnapshot.docs.last;
      _hasMoreVideos = true;

      final video = Video.fromFirestore(querySnapshot.docs.first);
      return video;
    } catch (e) {
      rethrow;
    }
  }

  // Future<Video?> _getFirstVideo() async {
  //   try {
  //     final querySnapshot = await _repository.getNextFeedVideo();

  //     if (querySnapshot.docs.isEmpty) {
  //       return null;
  //     }

  //     _lastDocument = querySnapshot.docs.last;
  //     _hasMoreVideos = true;
  //     return Video.fromFirestore(querySnapshot.docs.first);
  //   } catch (e) {
  //     rethrow;
  //   }
  // }

  void resetFeed() {
    _lastDocument = null;
    _hasMoreVideos = true;
  }
} 