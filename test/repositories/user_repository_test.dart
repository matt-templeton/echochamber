import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:echochamber/repositories/user_repository.dart';
import 'package:echochamber/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late UserRepository userRepository;
  late User testUser;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    userRepository = UserRepository(firestore: fakeFirestore);
    testUser = User(
      id: 'test-user-id',
      name: 'Test User',
      email: 'test@example.com',
      createdAt: DateTime.now(),
      lastActive: DateTime.now(),
      followersCount: 0,
      followingCount: 0,
    );
  });

  group('UserRepository - Basic CRUD Operations', () {
    test('createUser - should successfully create a user in Firestore', () async {
      // Act
      await userRepository.createUser(testUser);

      // Assert
      final userDoc = await fakeFirestore.collection('users').doc(testUser.id).get();
      expect(userDoc.exists, true);
      expect(userDoc.data()?['name'], testUser.name);
      expect(userDoc.data()?['email'], testUser.email);
    });

    test('getUserById - should return null for non-existent user', () async {
      // Act
      final result = await userRepository.getUserById('non-existent-id');

      // Assert
      expect(result, isNull);
    });

    test('getUserById - should return user for existing user', () async {
      // Arrange
      await userRepository.createUser(testUser);

      // Act
      final result = await userRepository.getUserById(testUser.id);

      // Assert
      expect(result, isNotNull);
      expect(result?.id, testUser.id);
      expect(result?.name, testUser.name);
      expect(result?.email, testUser.email);
    });

    test('updateUser - should successfully update user data', () async {
      // Arrange
      await userRepository.createUser(testUser);
      final updates = {
        'name': 'Updated Name',
        'bio': 'New bio'
      };

      // Act
      await userRepository.updateUser(testUser.id, updates);

      // Assert
      final userDoc = await fakeFirestore.collection('users').doc(testUser.id).get();
      expect(userDoc.data()?['name'], 'Updated Name');
      expect(userDoc.data()?['bio'], 'New bio');
    });

    test('updateLastActive - should update lastActive timestamp', () async {
      // Arrange
      await userRepository.createUser(testUser);

      // Act
      await userRepository.updateLastActive(testUser.id);

      // Assert
      final userDoc = await fakeFirestore.collection('users').doc(testUser.id).get();
      expect(userDoc.data()?['lastActive'], isA<Timestamp>());
    });
  });

  group('UserRepository - Follow Operations', () {
    late User targetUser;

    setUp(() {
      targetUser = User(
        id: 'target-user-id',
        name: 'Target User',
        email: 'target@example.com',
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
        followersCount: 0,
        followingCount: 0,
      );
    });

    test('followUser - should create correct following/follower relationships', () async {
      // Arrange
      await userRepository.createUser(testUser);
      await userRepository.createUser(targetUser);

      // Act
      await userRepository.followUser(testUser.id, targetUser.id);

      // Assert
      // Check following relationship
      final followingDoc = await fakeFirestore
          .collection('users')
          .doc(testUser.id)
          .collection('following')
          .doc(targetUser.id)
          .get();
      expect(followingDoc.exists, true);
      expect(followingDoc.data()?['followingId'], targetUser.id);

      // Check follower relationship
      final followerDoc = await fakeFirestore
          .collection('users')
          .doc(targetUser.id)
          .collection('followers')
          .doc(testUser.id)
          .get();
      expect(followerDoc.exists, true);
      expect(followerDoc.data()?['followerId'], testUser.id);

      // Check counts
      final testUserDoc = await fakeFirestore.collection('users').doc(testUser.id).get();
      final targetUserDoc = await fakeFirestore.collection('users').doc(targetUser.id).get();
      expect(testUserDoc.data()?['followingCount'], 1);
      expect(targetUserDoc.data()?['followersCount'], 1);
    });

    test('unfollowUser - should remove following/follower relationships', () async {
      // Arrange
      await userRepository.createUser(testUser);
      await userRepository.createUser(targetUser);
      await userRepository.followUser(testUser.id, targetUser.id);

      // Act
      await userRepository.unfollowUser(testUser.id, targetUser.id);

      // Assert
      // Check following relationship removed
      final followingDoc = await fakeFirestore
          .collection('users')
          .doc(testUser.id)
          .collection('following')
          .doc(targetUser.id)
          .get();
      expect(followingDoc.exists, false);

      // Check follower relationship removed
      final followerDoc = await fakeFirestore
          .collection('users')
          .doc(targetUser.id)
          .collection('followers')
          .doc(testUser.id)
          .get();
      expect(followerDoc.exists, false);

      // Check counts
      final testUserDoc = await fakeFirestore.collection('users').doc(testUser.id).get();
      final targetUserDoc = await fakeFirestore.collection('users').doc(targetUser.id).get();
      expect(testUserDoc.data()?['followingCount'], 0);
      expect(targetUserDoc.data()?['followersCount'], 0);
    });

    test('getUserFollowers - should return stream of followers', () async {
      // Arrange
      await userRepository.createUser(testUser);
      await userRepository.createUser(targetUser);
      await userRepository.followUser(targetUser.id, testUser.id); // targetUser follows testUser

      // Act & Assert
      expect(
        userRepository.getUserFollowers(testUser.id),
        emits(isA<QuerySnapshot>().having(
          (snapshot) => snapshot.docs.length,
          'has one follower',
          1,
        )),
      );
    });

    test('getUserFollowing - should return stream of following', () async {
      // Arrange
      await userRepository.createUser(testUser);
      await userRepository.createUser(targetUser);
      await userRepository.followUser(testUser.id, targetUser.id); // testUser follows targetUser

      // Act & Assert
      expect(
        userRepository.getUserFollowing(testUser.id),
        emits(isA<QuerySnapshot>().having(
          (snapshot) => snapshot.docs.length,
          'is following one user',
          1,
        )),
      );
    });
  });

  group('UserRepository - User Settings & Stats', () {
    test('updateOnboardingProgress - should update specific onboarding step', () async {
      // Arrange
      await userRepository.createUser(testUser);

      // Act
      await userRepository.updateOnboardingProgress(testUser.id, 'profile_complete', true);

      // Assert
      final userDoc = await fakeFirestore.collection('users').doc(testUser.id).get();
      expect(userDoc.data()?['onboardingProgress']['profile_complete'], true);
    });

    test('updateUserStats - should update user statistics', () async {
      // Arrange
      await userRepository.createUser(testUser);
      final stats = {'views': 100, 'likes': 50};

      // Act
      await userRepository.updateUserStats(testUser.id, stats);

      // Assert
      final userDoc = await fakeFirestore.collection('users').doc(testUser.id).get();
      expect(userDoc.data()?['stats'], stats);
    });

    test('addRecentVideo - should add video and maintain max 5 videos', () async {
      // Arrange
      await userRepository.createUser(testUser);
      final videoData = {'id': 'video1', 'title': 'Test Video'};

      // Act
      await userRepository.addRecentVideo(testUser.id, videoData);

      // Assert
      final userDoc = await fakeFirestore.collection('users').doc(testUser.id).get();
      final recentVideos = userDoc.data()?['recentVideos'] as List?;
      expect(recentVideos, isNotNull);
      expect(recentVideos?.length, 1);
      expect(recentVideos?.first['id'], 'video1');
    });

    test('addRecentVideo - should maintain only 5 most recent videos', () async {
      // Arrange
      await userRepository.createUser(testUser);
      
      // Add 6 videos
      for (var i = 1; i <= 6; i++) {
        await userRepository.addRecentVideo(
          testUser.id,
          {'id': 'video$i', 'title': 'Test Video $i'},
        );
      }

      // Assert
      final userDoc = await fakeFirestore.collection('users').doc(testUser.id).get();
      final recentVideos = userDoc.data()?['recentVideos'] as List;
      expect(recentVideos.length, 5);
      // Most recent should be first
      expect(recentVideos.first['id'], 'video6');
      // Oldest video (video1) should be removed
      expect(recentVideos.any((v) => v['id'] == 'video1'), false);
    });
  });
}