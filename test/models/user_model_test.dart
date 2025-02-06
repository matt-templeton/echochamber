import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echochamber/models/user_model.dart';

void main() {
  late Map<String, dynamic> testData;
  late DateTime now;

  setUp(() {
    now = DateTime.now();
    testData = {
      'name': 'Test User',
      'email': 'test@example.com',
      'profilePictureUrl': 'https://example.com/photo.jpg',
      'bio': 'Test bio',
      'socialMediaLinks': {
        'twitter': 'https://twitter.com/testuser',
        'instagram': 'https://instagram.com/testuser'
      },
      'createdAt': Timestamp.fromDate(now),
      'lastActive': Timestamp.fromDate(now),
      'timezone': 'UTC',
      'followersCount': 100,
      'followingCount': 50,
      'onboardingProgress': {
        'profile_complete': true,
        'preferences_set': false
      },
      'monetization': {
        'enabled': true,
        'plan': 'premium'
      },
      'stats': {
        'views': 1000,
        'likes': 500
      },
      'recentVideos': [
        {
          'id': 'video1',
          'title': 'Test Video'
        }
      ],
      'privacySettings': {
        'profileVisible': true
      },
      'notificationSettings': {
        'emailEnabled': true
      }
    };
  });

  group('User.fromFirestore', () {
    test('should correctly create User from complete Firestore document', () {
      // Arrange
      final doc = MockDocumentSnapshot(
        id: 'test-user-id',
        data: testData,
      );

      // Act
      final user = User.fromFirestore(doc);

      // Assert
      expect(user.id, 'test-user-id');
      expect(user.name, 'Test User');
      expect(user.email, 'test@example.com');
      expect(user.profilePictureUrl, 'https://example.com/photo.jpg');
      expect(user.bio, 'Test bio');
      expect(user.socialMediaLinks?['twitter'], 'https://twitter.com/testuser');
      expect(user.createdAt, now);
      expect(user.lastActive, now);
      expect(user.timezone, 'UTC');
      expect(user.followersCount, 100);
      expect(user.followingCount, 50);
      expect(user.onboardingProgress?['profile_complete'], true);
      expect(user.monetization?['enabled'], true);
      expect(user.stats?['views'], 1000);
      expect(user.recentVideos?.first['id'], 'video1');
      expect(user.privacySettings?['profileVisible'], true);
      expect(user.notificationSettings?['emailEnabled'], true);
    });

    test('should handle missing optional fields', () {
      // Arrange
      final minimalData = {
        'name': 'Test User',
        'email': 'test@example.com',
        'createdAt': Timestamp.fromDate(now),
        'lastActive': Timestamp.fromDate(now),
      };
      final doc = MockDocumentSnapshot(
        id: 'test-user-id',
        data: minimalData,
      );

      // Act
      final user = User.fromFirestore(doc);

      // Assert
      expect(user.id, 'test-user-id');
      expect(user.name, 'Test User');
      expect(user.email, 'test@example.com');
      expect(user.profilePictureUrl, null);
      expect(user.bio, null);
      expect(user.socialMediaLinks, null);
      expect(user.timezone, null);
      expect(user.followersCount, 0);
      expect(user.followingCount, 0);
      expect(user.onboardingProgress, null);
      expect(user.monetization, null);
      expect(user.stats, null);
      expect(user.recentVideos, null);
      expect(user.privacySettings, null);
      expect(user.notificationSettings, null);
    });
  });

  group('User.toFirestore', () {
    test('should correctly convert User to Firestore data with all fields', () {
      // Arrange
      final user = User(
        id: 'test-user-id',
        name: 'Test User',
        email: 'test@example.com',
        profilePictureUrl: 'https://example.com/photo.jpg',
        bio: 'Test bio',
        socialMediaLinks: {
          'twitter': 'https://twitter.com/testuser',
          'instagram': 'https://instagram.com/testuser'
        },
        createdAt: now,
        lastActive: now,
        timezone: 'UTC',
        followersCount: 100,
        followingCount: 50,
        onboardingProgress: {
          'profile_complete': true,
          'preferences_set': false
        },
        monetization: {
          'enabled': true,
          'plan': 'premium'
        },
        stats: {
          'views': 1000,
          'likes': 500
        },
        recentVideos: [
          {
            'id': 'video1',
            'title': 'Test Video'
          }
        ],
        privacySettings: {
          'profileVisible': true
        },
        notificationSettings: {
          'emailEnabled': true
        },
      );

      // Act
      final firestoreData = user.toFirestore();

      // Assert
      expect(firestoreData['name'], 'Test User');
      expect(firestoreData['email'], 'test@example.com');
      expect(firestoreData['profilePictureUrl'], 'https://example.com/photo.jpg');
      expect(firestoreData['bio'], 'Test bio');
      expect(firestoreData['socialMediaLinks']['twitter'], 'https://twitter.com/testuser');
      expect(firestoreData['createdAt'], isA<Timestamp>());
      expect(firestoreData['lastActive'], isA<Timestamp>());
      expect(firestoreData['timezone'], 'UTC');
      expect(firestoreData['followersCount'], 100);
      expect(firestoreData['followingCount'], 50);
      expect(firestoreData['onboardingProgress']['profile_complete'], true);
      expect(firestoreData['monetization']['enabled'], true);
      expect(firestoreData['stats']['views'], 1000);
      expect(firestoreData['recentVideos'][0]['id'], 'video1');
      expect(firestoreData['privacySettings']['profileVisible'], true);
      expect(firestoreData['notificationSettings']['emailEnabled'], true);
    });

    test('should omit null fields when converting to Firestore data', () {
      // Arrange
      final user = User(
        id: 'test-user-id',
        name: 'Test User',
        email: 'test@example.com',
        createdAt: now,
        lastActive: now,
      );

      // Act
      final firestoreData = user.toFirestore();

      // Assert
      expect(firestoreData.containsKey('profilePictureUrl'), false);
      expect(firestoreData.containsKey('bio'), false);
      expect(firestoreData.containsKey('socialMediaLinks'), false);
      expect(firestoreData.containsKey('timezone'), false);
      expect(firestoreData['followersCount'], 0);
      expect(firestoreData['followingCount'], 0);
      expect(firestoreData.containsKey('onboardingProgress'), false);
      expect(firestoreData.containsKey('monetization'), false);
      expect(firestoreData.containsKey('stats'), false);
      expect(firestoreData.containsKey('recentVideos'), false);
      expect(firestoreData.containsKey('privacySettings'), false);
      expect(firestoreData.containsKey('notificationSettings'), false);
    });
  });

  group('User.copyWith', () {
    test('should create a new instance with updated fields', () {
      // Arrange
      final originalUser = User(
        id: 'test-user-id',
        name: 'Test User',
        email: 'test@example.com',
        createdAt: now,
        lastActive: now,
      );

      // Act
      final updatedUser = originalUser.copyWith(
        name: 'Updated Name',
        bio: 'New bio',
        followersCount: 10,
      );

      // Assert
      expect(updatedUser.id, originalUser.id);
      expect(updatedUser.name, 'Updated Name');
      expect(updatedUser.email, originalUser.email);
      expect(updatedUser.bio, 'New bio');
      expect(updatedUser.followersCount, 10);
      expect(updatedUser.createdAt, originalUser.createdAt);
      expect(updatedUser.lastActive, originalUser.lastActive);
    });

    test('should not modify original instance', () {
      // Arrange
      final originalUser = User(
        id: 'test-user-id',
        name: 'Test User',
        email: 'test@example.com',
        createdAt: now,
        lastActive: now,
      );

      // Act
      final _ = originalUser.copyWith(
        name: 'Updated Name',
        bio: 'New bio',
      );

      // Assert
      expect(originalUser.name, 'Test User');
      expect(originalUser.bio, null);
    });

    test('should handle null values correctly', () {
      // Arrange
      final originalUser = User(
        id: 'test-user-id',
        name: 'Test User',
        email: 'test@example.com',
        bio: 'Original bio',
        createdAt: now,
        lastActive: now,
      );

      // Act
      final updatedUser = originalUser.copyWith(
        bio: null,
      );

      // Assert
      expect(updatedUser.bio, null);
    });
  });

  group('Type conversion and validation', () {
    test('should handle Timestamp conversion correctly', () {
      // Arrange
      final timestamp = Timestamp.fromDate(now);
      final data = {
        ...testData,
        'createdAt': timestamp,
        'lastActive': timestamp,
      };
      final doc = MockDocumentSnapshot(
        id: 'test-user-id',
        data: data,
      );

      // Act
      final user = User.fromFirestore(doc);

      // Assert
      expect(user.createdAt, timestamp.toDate());
      expect(user.lastActive, timestamp.toDate());
    });

    test('should handle Map type conversion correctly', () {
      // Arrange
      final doc = MockDocumentSnapshot(
        id: 'test-user-id',
        data: testData,
      );

      // Act
      final user = User.fromFirestore(doc);

      // Assert
      expect(user.socialMediaLinks, isA<Map<String, String>>());
      expect(user.stats, isA<Map<String, int>>());
      expect(user.onboardingProgress, isA<Map<String, bool>>());
      expect(user.monetization, isA<Map<String, dynamic>>());
    });
  });
}

// Mock class for DocumentSnapshot
class MockDocumentSnapshot implements DocumentSnapshot {
  final String id;
  final Map<String, dynamic> _data;

  MockDocumentSnapshot({
    required this.id,
    required Map<String, dynamic> data,
  }) : _data = data;

  @override
  Map<String, dynamic> data() => _data;

  @override
  bool exists = true;

  // Add other required implementations as needed
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
} 