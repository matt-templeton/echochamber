import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/video_model.dart';
import '../models/comment_model.dart';
import '../models/audio_track_model.dart';
import 'dart:developer' as dev;

class VideoRepository {
  final FirebaseFirestore _firestore;
  final String _collection = 'videos';
  final String _watchSessionsCollection = 'watch_sessions';
  final String _watchHistoryCollection = 'watch_history';
  static const int _maxHistoryEntries = 100;

  VideoRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    // Ensure titleLower field exists
    // ensureTitleLowerField().then((_) {
    //   dev.log('Finished checking/running migration', name: 'VideoRepository');
    // }).catchError((error) {
    //   dev.log('Error during migration check/run', name: 'VideoRepository', error: error);
    // });
  }

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
          .limit(3);  // Fetch 3 videos at a time

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
  Future<Comment> addComment(String videoId, String userId, String text, {String? parentCommentId}) async {
    final batch = _firestore.batch();
    
    // Get user metadata for caching
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data() as Map<String, dynamic>;
    
    final authorMetadata = {
      'name': userData['name'],
      'profilePictureUrl': userData['profilePictureUrl'],
    };
    
    // Create comment document
    final commentRef = _firestore
        .collection(_collection)
        .doc(videoId)
        .collection('comments')
        .doc();
    
    final now = DateTime.now();
    final comment = Comment(
      id: commentRef.id,
      videoId: videoId,
      userId: userId,
      text: text,
      createdAt: now,
      authorMetadata: authorMetadata,
      parentCommentId: parentCommentId,
    );
    
    // Convert comment to Firestore data and ensure parentCommentId is included
    final commentData = comment.toFirestore();
    if (parentCommentId != null) {
      commentData['parentCommentId'] = parentCommentId;
    }
    
    batch.set(commentRef, commentData);

    // If this is a reply, check if parent comment exists and increment its reply count
    if (parentCommentId != null) {
      final parentRef = _firestore
          .collection(_collection)
          .doc(videoId)
          .collection('comments')
          .doc(parentCommentId);
      
      final parentDoc = await parentRef.get();
      if (!parentDoc.exists) {
        throw Exception('Parent comment not found');
      }
      
      batch.update(parentRef, {
        'repliesCount': FieldValue.increment(1),
      });
    }

    // Increment video's comment count
    final videoRef = _firestore.collection(_collection).doc(videoId);
    batch.update(videoRef, {
      'commentsCount': FieldValue.increment(1),
    });

    await batch.commit();
    return comment;
  }

  // Get comments for a video
  Stream<List<Comment>> getVideoComments(String videoId, {
    String? parentCommentId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_collection)
        .doc(videoId)
        .collection('comments');

    try {
      // Simplified query - just order by createdAt first
      query = query.orderBy('createdAt', descending: true);

      // Then filter client-side for now
      return query.snapshots().map((snapshot) {
        dev.log('Got ${snapshot.docs.length} comments', name: 'VideoRepository');
        return snapshot.docs
          .map((doc) => Comment.fromFirestore(doc))
          .where((comment) => 
            parentCommentId == null 
              ? comment.parentCommentId == null 
              : comment.parentCommentId == parentCommentId)
          .toList();
      }).handleError((error) {
        dev.log('Error in getVideoComments: $error', name: 'VideoRepository', error: error);
        throw error;
      });
    } catch (e) {
      dev.log('Error setting up comments query: $e', name: 'VideoRepository', error: e);
      rethrow;
    }
  }

  // Edit a comment
  Future<Comment> editComment(String videoId, String commentId, String newText) async {
    final commentRef = _firestore
        .collection(_collection)
        .doc(videoId)
        .collection('comments')
        .doc(commentId);
    
    await commentRef.update({
      'text': newText,
      'editedAt': FieldValue.serverTimestamp(),
    });

    final updatedDoc = await commentRef.get();
    return Comment.fromFirestore(updatedDoc);
  }

  // Delete a comment
  Future<void> deleteComment(String videoId, String commentId) async {
    final batch = _firestore.batch();
    
    final commentRef = _firestore
        .collection(_collection)
        .doc(videoId)
        .collection('comments')
        .doc(commentId);
    
    // Get comment data first to check if it's a reply
    final commentDoc = await commentRef.get();
    final commentData = commentDoc.data() as Map<String, dynamic>;
    
    // If this is a reply, decrement parent's reply count
    if (commentData['parentCommentId'] != null) {
      final parentRef = _firestore
          .collection(_collection)
          .doc(videoId)
          .collection('comments')
          .doc(commentData['parentCommentId']);
      
      batch.update(parentRef, {
        'repliesCount': FieldValue.increment(-1),
      });
    }

    // Delete the comment
    batch.delete(commentRef);

    // Decrement video's comment count
    final videoRef = _firestore.collection(_collection).doc(videoId);
    batch.update(videoRef, {
      'commentsCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  // Like a comment
  Future<void> likeComment(String videoId, String commentId, String userId) async {
    final batch = _firestore.batch();
    
    // Add to comment's likes subcollection
    final likeRef = _firestore
        .collection(_collection)
        .doc(videoId)
        .collection('comments')
        .doc(commentId)
        .collection('likes')
        .doc(userId);
    
    batch.set(likeRef, {
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Increment comment's like count
    final commentRef = _firestore
        .collection(_collection)
        .doc(videoId)
        .collection('comments')
        .doc(commentId);
    
    batch.update(commentRef, {
      'likesCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // Unlike a comment
  Future<void> unlikeComment(String videoId, String commentId, String userId) async {
    final batch = _firestore.batch();
    
    // Remove from comment's likes subcollection
    final likeRef = _firestore
        .collection(_collection)
        .doc(videoId)
        .collection('comments')
        .doc(commentId)
        .collection('likes')
        .doc(userId);
    
    batch.delete(likeRef);

    // Decrement comment's like count
    final commentRef = _firestore
        .collection(_collection)
        .doc(videoId)
        .collection('comments')
        .doc(commentId);
    
    batch.update(commentRef, {
      'likesCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  // Check if user has liked a comment
  Future<bool> hasUserLikedComment(String videoId, String commentId, String userId) async {
    final doc = await _firestore
        .collection(_collection)
        .doc(videoId)
        .collection('comments')
        .doc(commentId)
        .collection('likes')
        .doc(userId)
        .get();
    
    return doc.exists;
  }

  // Get replies to a comment
  Stream<List<Comment>> getCommentReplies(String videoId, String commentId, {
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) {
    return getVideoComments(
      videoId,
      parentCommentId: commentId,
      limit: limit,
      startAfter: startAfter,
    );
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
        entryId = '${videoId}_$userId';
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
        // Parse videoId and userId from entryId (format: videoId_userId)
        final parts = entryId.split('_');
        if (parts.length >= 2) {
          final videoId = parts[0];
          final userId = parts[1];
          // Create new watch history entry
          await addToWatchHistory(videoId, userId);
          // Try update again after creation
          final updates = <String, dynamic>{
            'lastUpdated': FieldValue.serverTimestamp(),
          };
          if (watchDuration != null) updates['watchDuration'] = watchDuration;
          if (completed != null) updates['completed'] = completed;
          await entryRef.update(updates);
          return;
        }
      }

      final updates = <String, dynamic>{
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      if (watchDuration != null) updates['watchDuration'] = watchDuration;
      if (completed != null) updates['completed'] = completed;
      
      await entryRef.update(updates);
    } catch (e) {
      // debugPrint('Error updating watch history entry: $e', name: 'VideoRepository');
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

  // Check if migration is needed and run it if necessary
  // Future<void> ensureTitleLowerField() async {
  //   try {
  //     final snapshot = await _firestore.collection(_collection).limit(1).get();
  //     if (snapshot.docs.isEmpty) {
  //       dev.log('No documents found to migrate', name: 'VideoRepository');
  //       return;
  //     }
      
  //     // final sampleDoc = snapshot.docs.first.data();
      
  //   } catch (e) {
  //     dev.log('Error checking migration status', name: 'VideoRepository', error: e);
  //     rethrow;
  //   }
  // }

  // Search videos with filters
  Future<List<Video>> searchVideos({
    String? searchQuery,
    List<String>? genres,
    List<String>? tags,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore.collection(_collection);
    dev.log('Starting search with query: "$searchQuery"', name: 'VideoRepository');

    // Apply genre filter if specified
    if (genres != null && genres.isNotEmpty) {
      dev.log('Applying genre filter: ${genres.first}', name: 'VideoRepository');
      query = query.where('genres', arrayContains: genres.first);
    }

    // Apply tag filter if specified
    if (tags != null && tags.isNotEmpty) {
      dev.log('Applying tag filter: ${tags.first}', name: 'VideoRepository');
      query = query.where('tags', arrayContains: tags.first);
    }

    // Apply search query if specified and not empty
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final searchLower = searchQuery.toLowerCase();
      final end = searchLower.substring(0, searchLower.length - 1) +
                 String.fromCharCode(searchLower.codeUnitAt(searchLower.length - 1) + 1);
      dev.log('Searching titleLower field: >="$searchLower" AND <"$end"', name: 'VideoRepository');
      query = query.where('titleLower', isGreaterThanOrEqualTo: searchLower)
                  .where('titleLower', isLessThan: end);
    } else {
      // For empty queries, sort by uploadedAt
      dev.log('Empty search query, sorting by uploadedAt', name: 'VideoRepository');
      query = query.orderBy('uploadedAt', descending: true);
    }

    // Apply startAfter if provided
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    // Apply limit
    query = query.limit(limit);

    // Execute query
    final snapshot = await query.get();
    dev.log('Query returned ${snapshot.docs.length} results', name: 'VideoRepository');
    
    // Filter results client-side for additional genres/tags
    var results = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      dev.log('Document ${doc.id} - title: "${data['title']}", titleLower: "${data['titleLower']}"', 
        name: 'VideoRepository');
      return Video.fromFirestore(doc);
    }).where((video) {
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
    }).toList();
    
    dev.log('Returning ${results.length} filtered results', name: 'VideoRepository');
    return results;
  }

  // Get a video document by ID
  Future<DocumentSnapshot?> getVideoDocumentById(String videoId) async {
    try {
      return await _firestore.collection(_collection).doc(videoId).get();
    } catch (e) {
      rethrow;
    }
  }

  Future<QuerySnapshot> getAllVideos() async {
    return _firestore
      .collection('videos')
      .orderBy('uploadedAt', descending: true)
      .get();
  }

  // Migration function to add titleLower field to existing videos
  // Future<void> migrateTitleLowerField() async {
  //   final batch = _firestore.batch();
  //   int operationCount = 0;
    
  //   try {
  //     final snapshot = await _firestore.collection(_collection).get();
  //     dev.log('Starting migration with ${snapshot.docs.length} documents', name: 'VideoRepository');
      
  //     for (final doc in snapshot.docs) {
  //       final data = doc.data();
  //       dev.log('Checking document ${doc.id} - title: "${data['title']}", current titleLower: "${data['titleLower']}"', 
  //         name: 'VideoRepository');
        
  //       if (!data.containsKey('titleLower')) {
  //         final newTitleLower = (data['title'] as String).toLowerCase();
  //         dev.log('Adding titleLower: "$newTitleLower" to document ${doc.id}', name: 'VideoRepository');
          
  //         batch.update(doc.reference, {
  //           'titleLower': newTitleLower,
  //         });
  //         operationCount++;
          
  //         // Commit batch when it reaches the limit
  //         if (operationCount >= 500) {
  //           await batch.commit();
  //           dev.log('Committed batch of $operationCount updates', name: 'VideoRepository');
  //           operationCount = 0;
  //         }
  //       }
  //     }
      
  //     // Commit any remaining operations
  //     if (operationCount > 0) {
  //       await batch.commit();
  //       dev.log('Committed final batch of $operationCount updates', name: 'VideoRepository');
  //     }
      
  //     dev.log('Migration completed successfully', name: 'VideoRepository');
  //   } catch (e) {
  //     dev.log('Error migrating titleLower field', name: 'VideoRepository', error: e);
  //     rethrow;
  //   }
  // }

  // Get audio tracks for a video
  Future<List<AudioTrack>> getVideoAudioTracks(String videoId) async {
    try {
      dev.log('Fetching audio tracks for video $videoId', name: 'VideoRepository');
      final querySnapshot = await _firestore
          .collection(_collection)
          .doc(videoId)
          .collection('audioTracks')
          .get();
      
      dev.log('Found ${querySnapshot.docs.length} audio tracks', name: 'VideoRepository');
      return querySnapshot.docs
          .map((doc) => AudioTrack.fromFirestore(doc))
          .toList();
    } catch (e) {
      dev.log('Error getting audio tracks: $e', name: 'VideoRepository', error: e);
      return [];
    }
  }
} 