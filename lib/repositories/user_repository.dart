import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'dart:developer' as dev;

class UserRepository {
  final FirebaseFirestore _firestore;
  final String _collection = 'users';

  UserRepository({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Get a user by ID
  Future<User?> getUserById(String userId) async {
    try {
      dev.log('Fetching user data for ID: $userId', name: 'UserRepository');
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (!doc.exists) {
        dev.log('No user document found for ID: $userId', name: 'UserRepository');
        return null;
      }
      dev.log('Successfully fetched user data for ID: $userId', name: 'UserRepository');
      return User.fromFirestore(doc);
    } catch (e, stackTrace) {
      dev.log(
        'Error fetching user data',
        name: 'UserRepository',
        error: e,
        stackTrace: stackTrace
      );
      rethrow;
    }
  }

  // Create a new user
  Future<void> createUser(User user) async {
    await _firestore.collection(_collection).doc(user.id).set(user.toFirestore());
  }

  // Update user data
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _firestore.collection(_collection).doc(userId).update(data);
  }

  // Update user's last active timestamp
  Future<void> updateLastActive(String userId) async {
    await _firestore.collection(_collection).doc(userId).update({
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  // Follow a user
  Future<void> followUser(String userId, String targetUserId) async {
    final batch = _firestore.batch();
    
    // Add to following subcollection
    final followingRef = _firestore
        .collection(_collection)
        .doc(userId)
        .collection('following')
        .doc(targetUserId);
    
    batch.set(followingRef, {
      'followingId': targetUserId,
      'followedAt': FieldValue.serverTimestamp(),
    });

    // Add to followers subcollection
    final followerRef = _firestore
        .collection(_collection)
        .doc(targetUserId)
        .collection('followers')
        .doc(userId);
    
    batch.set(followerRef, {
      'followerId': userId,
      'followedAt': FieldValue.serverTimestamp(),
    });

    // Update counts
    final userRef = _firestore.collection(_collection).doc(userId);
    batch.update(userRef, {
      'followingCount': FieldValue.increment(1),
    });

    final targetRef = _firestore.collection(_collection).doc(targetUserId);
    batch.update(targetRef, {
      'followersCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // Unfollow a user
  Future<void> unfollowUser(String userId, String targetUserId) async {
    final batch = _firestore.batch();
    
    // Remove from following subcollection
    final followingRef = _firestore
        .collection(_collection)
        .doc(userId)
        .collection('following')
        .doc(targetUserId);
    
    batch.delete(followingRef);

    // Remove from followers subcollection
    final followerRef = _firestore
        .collection(_collection)
        .doc(targetUserId)
        .collection('followers')
        .doc(userId);
    
    batch.delete(followerRef);

    // Update counts
    final userRef = _firestore.collection(_collection).doc(userId);
    batch.update(userRef, {
      'followingCount': FieldValue.increment(-1),
    });

    final targetRef = _firestore.collection(_collection).doc(targetUserId);
    batch.update(targetRef, {
      'followersCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  // Get user's followers
  Stream<QuerySnapshot> getUserFollowers(String userId) {
    return _firestore
        .collection(_collection)
        .doc(userId)
        .collection('followers')
        .orderBy('followedAt', descending: true)
        .snapshots();
  }

  // Get user's following
  Stream<QuerySnapshot> getUserFollowing(String userId) {
    return _firestore
        .collection(_collection)
        .doc(userId)
        .collection('following')
        .orderBy('followedAt', descending: true)
        .snapshots();
  }

  // Update user's onboarding progress
  Future<void> updateOnboardingProgress(String userId, String step, bool completed) async {
    await _firestore.collection(_collection).doc(userId).update({
      'onboardingProgress.$step': completed,
    });
  }

  // Update user's stats
  Future<void> updateUserStats(String userId, Map<String, int> stats) async {
    await _firestore.collection(_collection).doc(userId).update({
      'stats': stats,
    });
  }

  // Add a recent video to user's profile
  Future<void> addRecentVideo(String userId, Map<String, dynamic> videoData) async {
    final userRef = _firestore.collection(_collection).doc(userId);
    
    // Get current recent videos
    final doc = await userRef.get();
    final userData = doc.data() as Map<String, dynamic>;
    final recentVideos = (userData['recentVideos'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    // Add new video at the beginning
    recentVideos.insert(0, videoData);

    // Keep only the most recent 5 videos
    if (recentVideos.length > 5) {
      recentVideos.removeRange(5, recentVideos.length);
    }

    // Update the document
    await userRef.update({
      'recentVideos': recentVideos,
    });
  }
} 