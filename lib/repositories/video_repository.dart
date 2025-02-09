import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/video_model.dart';

class VideoRepository {
  final FirebaseFirestore _firestore;
  final String _collection = 'videos';
  final String _watchSessionsCollection = 'watch_sessions';
  final String _watchHistoryCollection = 'watch_history';
  static const int _maxHistoryEntries = 100;

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
      if (!doc.exists) {
        return null;
      }

      final data = doc.data();
      if (data == null || !data.containsKey('validationMetadata')) {
        return null;
      }

      final metadata = VideoValidationMetadata.fromMap(
        data['validationMetadata'] as Map<String, dynamic>
      );
      return metadata.variants;
    } catch (e) {
      return null;
    }
  }

  // Get video URL for specific quality
  Future<String?> getVideoUrlForQuality(String videoId, String quality) async {
    try {
      final variants = await getVideoVariants(videoId);
      if (variants == null) {
        return null;
      }

      final variant = variants.firstWhere(
        (v) => v.quality == quality,
        orElse: () => variants.first,
      );
      return variant.playlistUrl;
    } catch (e) {
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
      return null;
    }
  }

  // Watch Session Methods
  Future<WatchSession> startWatchSession(String videoId, String userId) async {
    final batch = _firestore.batch();
    
    try {
      // Create new watch session with a known ID based on videoId and userId
      final sessionId = '${videoId}_${userId}_${DateTime.now().millisecondsSinceEpoch}';
      final sessionRef = _firestore.collection(_watchSessionsCollection).doc(sessionId);
      final session = WatchSession(
        id: sessionId,
        videoId: videoId,
        userId: userId,
        startTime: DateTime.now(),
      );
      
      batch.set(sessionRef, session.toFirestore());

      // Update video's view count
      final videoRef = _firestore.collection(_collection).doc(videoId);
      batch.update(videoRef, {
        'viewsCount': FieldValue.increment(1),
        'lastWatchedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return session;
    } catch (e) {
      print('Error in startWatchSession: $e');
      rethrow;
    }
  }

  Future<void> updateWatchSession(String sessionId, {
    int? position,
    int? duration,
    bool? completed,
  }) async {
    final sessionRef = _firestore.collection(_watchSessionsCollection).doc(sessionId);
    final updates = <String, dynamic>{};
    
    if (position != null) updates['lastPosition'] = position;
    if (duration != null) updates['watchDuration'] = duration;
    if (completed != null) updates['completedViewing'] = completed;
    
    await sessionRef.update(updates);
  }

  Future<void> endWatchSession(String sessionId, String videoId) async {
    final batch = _firestore.batch();
    final now = DateTime.now();
    
    // Get current session
    final sessionRef = _firestore.collection(_watchSessionsCollection).doc(sessionId);
    final sessionDoc = await sessionRef.get();
    final session = WatchSession.fromFirestore(sessionDoc);
    
    // Calculate watch duration
    final watchDuration = now.difference(session.startTime).inSeconds;
    
    // Update session
    batch.update(sessionRef, {
      'endTime': Timestamp.fromDate(now),
      'watchDuration': watchDuration,
    });

    // Update video stats
    final videoRef = _firestore.collection(_collection).doc(videoId);
    batch.update(videoRef, {
      'totalWatchDuration': FieldValue.increment(watchDuration),
      if (session.completedViewing) 'watchCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  Future<WatchSession?> getLastWatchSession(String videoId, String userId) async {
    final querySnapshot = await _firestore
        .collection(_watchSessionsCollection)
        .where('videoId', isEqualTo: videoId)
        .where('userId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;
    return WatchSession.fromFirestore(querySnapshot.docs.first);
  }

  Stream<QuerySnapshot> getWatchHistory(String userId, {int limit = 50}) {
    return _firestore
        .collection(_watchSessionsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .limit(limit)
        .snapshots();
  }

  // Watch History Methods
  Future<String> addToWatchHistory(String videoId, String userId) async {
    final video = await getVideoById(videoId);
    if (video == null) return '';

    final batch = _firestore.batch();
    
    try {
      // Check for existing entry
      final existingEntryQuery = await _firestore
          .collection(_watchHistoryCollection)
          .where('videoId', isEqualTo: videoId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      final now = DateTime.now();
      final videoMetadata = VideoMetadata.fromVideo(video);

      String entryId;
      if (existingEntryQuery.docs.isEmpty) {
        // Create new entry with a known ID based on videoId and userId
        entryId = '${videoId}_${userId}';
        final entryRef = _firestore.collection(_watchHistoryCollection).doc(entryId);
        final entry = WatchHistoryEntry(
          id: entryId,
          videoId: videoId,
          userId: userId,
          watchedAt: now,
          watchDuration: 0,
          videoMetadata: videoMetadata,
        );
        
        batch.set(entryRef, entry.toFirestore());
      } else {
        // Update existing entry
        final entryRef = existingEntryQuery.docs.first.reference;
        entryId = existingEntryQuery.docs.first.id;
        batch.update(entryRef, {
          'watchedAt': Timestamp.fromDate(now),
          'videoMetadata': videoMetadata.toMap(),
        });
      }

      await batch.commit();
      await _cleanupOldEntries(userId);
      return entryId;
    } catch (e) {
      print('Error in addToWatchHistory: $e');
      rethrow;
    }
  }

  Future<void> updateWatchHistoryEntry(String entryId, {
    int? watchDuration,
    bool? completed,
  }) async {
    try {
      final entryRef = _firestore.collection(_watchHistoryCollection).doc(entryId);
      
      // First check if the document exists
      final docSnapshot = await entryRef.get();
      if (!docSnapshot.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Watch history entry not found'
        );
      }

      final updates = <String, dynamic>{
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      if (watchDuration != null) updates['watchDuration'] = watchDuration;
      if (completed != null) updates['completed'] = completed;
      
      await entryRef.update(updates);
    } catch (e) {
      print('Error in updateWatchHistoryEntry: $e');
      rethrow;
    }
  }

  Future<void> deleteWatchHistoryEntry(String entryId) async {
    await _firestore
        .collection(_watchHistoryCollection)
        .doc(entryId)
        .delete();
  }

  Future<void> clearWatchHistory(String userId) async {
    // Get all entries for the user
    final entries = await _firestore
        .collection(_watchHistoryCollection)
        .where('userId', isEqualTo: userId)
        .get();

    // Delete in batches of 500 (Firestore batch limit)
    final batches = <WriteBatch>[];
    var currentBatch = _firestore.batch();
    var operationCount = 0;

    for (final doc in entries.docs) {
      if (operationCount >= 500) {
        batches.add(currentBatch);
        currentBatch = _firestore.batch();
        operationCount = 0;
      }
      currentBatch.delete(doc.reference);
      operationCount++;
    }

    if (operationCount > 0) {
      batches.add(currentBatch);
    }

    // Commit all batches
    for (final batch in batches) {
      await batch.commit();
    }
  }

  Stream<QuerySnapshot> streamWatchHistory(String userId, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    var query = _firestore
        .collection(_watchHistoryCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('watchedAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots();
  }

  Future<void> _cleanupOldEntries(String userId) async {
    final entries = await _firestore
        .collection(_watchHistoryCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('watchedAt', descending: true)
        .get();

    if (entries.docs.length > _maxHistoryEntries) {
      final batch = _firestore.batch();
      for (var i = _maxHistoryEntries; i < entries.docs.length; i++) {
        batch.delete(entries.docs[i].reference);
      }
      await batch.commit();
    }
  }

  // Get all unique genres
  Future<List<String>> getAllGenres() async {
    final snapshot = await _firestore.collection(_collection).get();
    final Set<String> genres = {};
    
    for (final doc in snapshot.docs) {
      final video = Video.fromFirestore(doc);
      genres.addAll(video.genres);
    }
    
    return genres.toList()..sort();
  }

  // Get all unique tags
  Future<List<String>> getAllTags() async {
    final snapshot = await _firestore.collection(_collection).get();
    final Set<String> tags = {};
    
    for (final doc in snapshot.docs) {
      final video = Video.fromFirestore(doc);
      tags.addAll(video.tags);
    }
    
    return tags.toList()..sort();
  }

  // Search videos with filters
  Future<List<Video>> searchVideos({
    String? searchQuery,
    List<String>? genres,
    List<String>? tags,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore.collection(_collection);

    // Apply genre filter if specified
    if (genres != null && genres.isNotEmpty) {
      // Use the first genre for the query (Firestore limitation)
      query = query.where('genres', arrayContains: genres.first);
    }

    // Apply tag filter if specified
    if (tags != null && tags.isNotEmpty) {
      // Use the first tag for the query (Firestore limitation)
      query = query.where('tags', arrayContains: tags.first);
    }

    // Apply search query if specified
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.where('title', isGreaterThanOrEqualTo: searchQuery)
                  .where('title', isLessThan: searchQuery + 'z');
    }

    // Apply pagination
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    // Apply limit and order
    query = query.orderBy('uploadedAt', descending: true).limit(limit);

    // Execute query
    final snapshot = await query.get();
    
    // Filter results client-side for additional genres/tags
    return snapshot.docs.map((doc) => Video.fromFirestore(doc))
        .where((video) {
          // Check if video matches all selected genres
          if (genres != null && genres.isNotEmpty) {
            if (!genres.every((g) => video.genres.contains(g))) {
              return false;
            }
          }
          // Check if video matches all selected tags
          if (tags != null && tags.isNotEmpty) {
            if (!tags.every((t) => video.tags.contains(t))) {
              return false;
            }
          }
          return true;
        })
        .toList();
  }
} 