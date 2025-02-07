import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/video_model.dart';

class VideoRepository {
  final FirebaseFirestore _firestore;
  final String _collection = 'videos';

  VideoRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Create a new video document
  Future<void> createVideo(Video video) async {
    final videoDoc = video.toFirestore();
    
    // Ensure HLS-specific fields are present
    assert(video.validationMetadata?.format == 'hls', 'Video format must be HLS');
    assert(video.hlsBasePath != null, 'HLS base path must be provided');
    assert(video.validationMetadata?.variants != null, 'Video variants must be provided');
    
    await _firestore.collection(_collection).doc(video.id).set(videoDoc);
  }

  // Get a video by ID
  Future<Video?> getVideoById(String videoId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(videoId).get();
      return doc.exists ? Video.fromFirestore(doc) : null;
    } catch (e) {
      rethrow;
    }
  }

  // Get videos for a user
  Stream<QuerySnapshot> getUserVideos(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  // Get videos by genre
  Stream<QuerySnapshot> getVideosByGenre(String genre) {
    return _firestore
        .collection(_collection)
        .where('genres', arrayContains: genre)
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  // Get videos by tag
  Stream<QuerySnapshot> getVideosByTag(String tag) {
    return _firestore
        .collection(_collection)
        .where('tags', arrayContains: tag)
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  // Update video metadata
  Future<void> updateVideo(String videoId, Map<String, dynamic> data) async {
    await _firestore.collection(_collection).doc(videoId).update({
      ...data,
      'lastModified': FieldValue.serverTimestamp(),
    });
  }

  // Delete a video
  Future<void> deleteVideo(String videoId) async {
    // Delete the video document
    await _firestore.collection(_collection).doc(videoId).delete();
    
    // Note: This doesn't delete the actual video file from storage
    // That should be handled separately by the video service
  }

  // Increment view count
  Future<void> incrementViewCount(String videoId) async {
    await _firestore.collection(_collection).doc(videoId).update({
      'viewsCount': FieldValue.increment(1),
    });
  }

  // Like a video
  Future<void> likeVideo(String videoId, String userId) async {
    final batch = _firestore.batch();
    
    // Add to video's likes subcollection
    final likeRef = _firestore
        .collection(_collection)
        .doc(videoId)
        .collection('likes')
        .doc(userId);
    
    batch.set(likeRef, {
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Increment likes count
    final videoRef = _firestore.collection(_collection).doc(videoId);
    batch.update(videoRef, {
      'likesCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // Unlike a video
  Future<void> unlikeVideo(String videoId, String userId) async {
    final batch = _firestore.batch();
    
    // Remove from video's likes subcollection
    final likeRef = _firestore
        .collection(_collection)
        .doc(videoId)
        .collection('likes')
        .doc(userId);
    
    batch.delete(likeRef);

    // Decrement likes count
    final videoRef = _firestore.collection(_collection).doc(videoId);
    batch.update(videoRef, {
      'likesCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  // Check if user has liked a video
  Future<bool> hasUserLikedVideo(String videoId, String userId) async {
    final doc = await _firestore
        .collection(_collection)
        .doc(videoId)
        .collection('likes')
        .doc(userId)
        .get();
    
    return doc.exists;
  }

  // Get trending videos
  Stream<QuerySnapshot> getTrendingVideos({int limit = 10}) {
    return _firestore
        .collection(_collection)
        .orderBy('viewsCount', descending: true)
        .limit(limit)
        .snapshots();
  }

  // Get videos for feed
  Stream<QuerySnapshot> getFeedVideos({
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) {
    print('getFeedVideos called with limit: $limit, startAfter: ${startAfter?.id}');
    var query = _firestore
        .collection(_collection)
        .orderBy('uploadedAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots();
  }

  // Get a single video for feed
  Future<QuerySnapshot> getNextFeedVideo({DocumentSnapshot? startAfter}) async {
    try {
      var query = _firestore
          .collection(_collection)
          .orderBy('uploadedAt', descending: true)
          .limit(1);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      return await query.get();
    } catch (e) {
      rethrow;
    }
  }

  // Get user's liked videos
  Stream<QuerySnapshot> getUserLikedVideos(String userId) {
    return _firestore
        .collection(_collection)
        .where('likes.$userId', isEqualTo: true)
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  // Add a comment to a video
  Future<void> addComment(String videoId, String userId, String comment) async {
    final batch = _firestore.batch();
    
    // Add to comments subcollection
    final commentRef = _firestore
        .collection(_collection)
        .doc(videoId)
        .collection('comments')
        .doc();
    
    batch.set(commentRef, {
      'userId': userId,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Increment comments count
    final videoRef = _firestore.collection(_collection).doc(videoId);
    batch.update(videoRef, {
      'commentsCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // Get comments for a video
  Stream<QuerySnapshot> getVideoComments(String videoId) {
    return _firestore
        .collection(_collection)
        .doc(videoId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get video quality variants
  Future<List<VideoQualityVariant>?> getVideoVariants(String videoId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(videoId).get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null || !data.containsKey('validationMetadata')) return null;

      final metadata = VideoValidationMetadata.fromMap(
        data['validationMetadata'] as Map<String, dynamic>
      );
      return metadata.variants;
    } catch (e) {
      print('Error getting video variants: $e');
      return null;
    }
  }

  // Get video URL for specific quality
  Future<String?> getVideoUrlForQuality(String videoId, String quality) async {
    try {
      final variants = await getVideoVariants(videoId);
      if (variants == null) return null;

      final variant = variants.firstWhere(
        (v) => v.quality == quality,
        orElse: () => variants.first,
      );
      return variant.playlistUrl;
    } catch (e) {
      print('Error getting video URL for quality: $e');
      return null;
    }
  }

  // Get best quality URL based on bandwidth
  Future<String?> getAdaptiveVideoUrl(String videoId, int bandwidthBps) async {
    try {
      final variants = await getVideoVariants(videoId);
      if (variants == null || variants.isEmpty) {
        // Fall back to master playlist
        final doc = await _firestore.collection(_collection).doc(videoId).get();
        if (!doc.exists) return null;
        final data = doc.data();
        if (data == null) return null;
        return data['videoUrl'] as String?;
      }

      final variant = variants
          .where((v) => v.bitrate <= bandwidthBps)
          .reduce((a, b) => a.bitrate > b.bitrate ? a : b);
      return variant.playlistUrl;
    } catch (e) {
      print('Error getting adaptive video URL: $e');
      return null;
    }
  }
} 