import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echochamber/services/video_feed_service.dart';
import 'package:echochamber/repositories/video_repository.dart';
import 'package:echochamber/models/video_model.dart';
import 'package:echochamber/providers/video_feed_provider.dart';

import 'video_feed_service_test.mocks.dart';

// Generate mocks
@GenerateMocks(
  [VideoRepository],
  customMocks: [
    MockSpec<QuerySnapshot<Map<String, dynamic>>>(as: #MockFirestoreQuerySnapshot),
    MockSpec<QueryDocumentSnapshot<Map<String, dynamic>>>(as: #MockFirestoreDocumentSnapshot),
  ],
)
void main() {
  group('VideoFeedService Tests', () {
    late MockVideoRepository mockRepository;
    late VideoFeedService videoFeedService;
    final now = DateTime.now();

    setUp(() {
      mockRepository = MockVideoRepository();
      videoFeedService = VideoFeedService(repository: mockRepository);
    });

    test('getNextVideo returns null when no videos exist', () async {
      // Arrange
      final mockQuerySnapshot = MockFirestoreQuerySnapshot();
      when(mockQuerySnapshot.docs).thenReturn([]);
      when(mockRepository.getNextFeedVideo(startAfter: null))
          .thenAnswer((_) async => mockQuerySnapshot);

      // Act
      final result = await videoFeedService.getNextVideo();

      // Assert
      expect(result, isNull);
      verify(mockRepository.getNextFeedVideo(startAfter: null)).called(1);
    });

    test('getNextVideo returns first video when available', () async {
      // Arrange
      final testVideo = Video(
        id: 'test_id',
        userId: 'test_user',
        title: 'Test Video',
        description: 'Test Description',
        duration: 30,
        videoUrl: 'https://example.com/video.m3u8',
        uploadedAt: now,
        lastModified: now,
        author: {'id': 'test_user', 'name': 'Test User'},
        copyrightStatus: {'type': 'original', 'owner': 'Test User'},
      );

      final mockDoc = MockFirestoreDocumentSnapshot();
      when(mockDoc.data()).thenReturn(testVideo.toFirestore());
      when(mockDoc.id).thenReturn(testVideo.id);

      final mockQuerySnapshot = MockFirestoreQuerySnapshot();
      when(mockQuerySnapshot.docs).thenReturn([mockDoc]);
      when(mockRepository.getNextFeedVideo(startAfter: null))
          .thenAnswer((_) async => mockQuerySnapshot);

      // Act
      final result = await videoFeedService.getNextVideo();

      // Assert
      expect(result, isNotNull);
      expect(result?.id, equals(testVideo.id));
      expect(result?.title, equals(testVideo.title));
      verify(mockRepository.getNextFeedVideo(startAfter: null)).called(1);
    });

    test('getNextVideo uses lastDocument for pagination', () async {
      // Arrange
      final testVideo1 = Video(
        id: 'test_id_1',
        userId: 'test_user',
        title: 'Test Video 1',
        description: 'Test Description 1',
        duration: 30,
        videoUrl: 'https://example.com/video1.m3u8',
        uploadedAt: now,
        lastModified: now,
        author: {'id': 'test_user', 'name': 'Test User'},
        copyrightStatus: {'type': 'original', 'owner': 'Test User'},
      );

      final testVideo2 = Video(
        id: 'test_id_2',
        userId: 'test_user',
        title: 'Test Video 2',
        description: 'Test Description 2',
        duration: 30,
        videoUrl: 'https://example.com/video2.m3u8',
        uploadedAt: now.add(Duration(hours: 1)),
        lastModified: now.add(Duration(hours: 1)),
        author: {'id': 'test_user', 'name': 'Test User'},
        copyrightStatus: {'type': 'original', 'owner': 'Test User'},
      );

      final mockDoc1 = MockFirestoreDocumentSnapshot();
      when(mockDoc1.data()).thenReturn(testVideo1.toFirestore());
      when(mockDoc1.id).thenReturn(testVideo1.id);

      final mockDoc2 = MockFirestoreDocumentSnapshot();
      when(mockDoc2.data()).thenReturn(testVideo2.toFirestore());
      when(mockDoc2.id).thenReturn(testVideo2.id);

      final mockQuerySnapshot1 = MockFirestoreQuerySnapshot();
      when(mockQuerySnapshot1.docs).thenReturn([mockDoc1]);
      when(mockRepository.getNextFeedVideo(startAfter: null))
          .thenAnswer((_) async => mockQuerySnapshot1);

      final mockQuerySnapshot2 = MockFirestoreQuerySnapshot();
      when(mockQuerySnapshot2.docs).thenReturn([mockDoc2]);
      when(mockRepository.getNextFeedVideo(startAfter: mockDoc1))
          .thenAnswer((_) async => mockQuerySnapshot2);

      // Act & Assert - First video
      final result1 = await videoFeedService.getNextVideo();
      expect(result1?.id, equals(testVideo1.id));
      verify(mockRepository.getNextFeedVideo(startAfter: null)).called(1);

      // Act & Assert - Second video
      final result2 = await videoFeedService.getNextVideo();
      expect(result2?.id, equals(testVideo2.id));
      verify(mockRepository.getNextFeedVideo(startAfter: mockDoc1)).called(1);
    });

    test('resetFeed clears last document', () async {
      // Arrange
      final testVideo = Video(
        id: 'test_id',
        userId: 'test_user',
        title: 'Test Video',
        description: 'Test Description',
        duration: 30,
        videoUrl: 'https://example.com/video.m3u8',
        uploadedAt: now,
        lastModified: now,
        author: {'id': 'test_user', 'name': 'Test User'},
        copyrightStatus: {'type': 'original', 'owner': 'Test User'},
      );

      final mockDoc = MockFirestoreDocumentSnapshot();
      when(mockDoc.data()).thenReturn(testVideo.toFirestore());
      when(mockDoc.id).thenReturn(testVideo.id);

      final mockQuerySnapshot = MockFirestoreQuerySnapshot();
      when(mockQuerySnapshot.docs).thenReturn([mockDoc]);
      when(mockRepository.getNextFeedVideo(startAfter: null))
          .thenAnswer((_) async => mockQuerySnapshot);

      // Get first video to set lastDocument
      await videoFeedService.getNextVideo();
      clearInteractions(mockRepository);

      // Act
      videoFeedService.resetFeed();

      // Get next video after reset
      await videoFeedService.getNextVideo();

      // Assert - Should query without startAfter
      verify(mockRepository.getNextFeedVideo(startAfter: null)).called(1);
    });

    test('getNextVideo handles repository errors', () async {
      // Arrange
      when(mockRepository.getNextFeedVideo(startAfter: null))
          .thenThrow(Exception('Network error'));

      // Act & Assert
      expect(() => videoFeedService.getNextVideo(), throwsException);
    });
  });

  group('VideoFeedProvider Watch Session Tests', () {
    late MockVideoRepository mockRepository;
    late VideoFeedProvider provider;
    late Video testVideo;
    final now = DateTime.now();

    setUp(() {
      mockRepository = MockVideoRepository();
      provider = VideoFeedProvider(
        videoRepository: mockRepository,
        feedService: VideoFeedService(repository: mockRepository),
      );
      testVideo = Video(
        id: 'test-video-id',
        userId: 'test-user-id',
        title: 'Test Video',
        description: 'Test Description',
        duration: 120,
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumbnail.jpg',
        uploadedAt: now,
        lastModified: now,
        author: {'id': 'test-user-id', 'name': 'Test Author'},
        copyrightStatus: {'status': 'pending', 'owner': 'Test Author'},
      );
    });

    test('startWatchSession creates new session through repository', () async {
      // Arrange
      final mockSession = WatchSession(
        id: 'test-session-id',
        videoId: testVideo.id,
        userId: 'test-viewer-id',
        startTime: now,
      );
      when(mockRepository.startWatchSession(testVideo.id, 'test-viewer-id'))
          .thenAnswer((_) async => mockSession);

      // Set current video
      final mockQuerySnapshot = MockFirestoreQuerySnapshot();
      final mockDoc = MockFirestoreDocumentSnapshot();
      when(mockDoc.data()).thenReturn(testVideo.toFirestore());
      when(mockDoc.id).thenReturn(testVideo.id);
      when(mockQuerySnapshot.docs).thenReturn([mockDoc]);
      when(mockRepository.getNextFeedVideo(startAfter: null))
          .thenAnswer((_) async => mockQuerySnapshot);
      await provider.loadNextVideo();

      // Act
      // await provider.startWatchSession('test-viewer-id');

      // Assert
      verify(mockRepository.startWatchSession(testVideo.id, 'test-viewer-id')).called(1);
      expect(provider.currentSession, equals(mockSession));
    });

    test('updateWatchPosition updates session through repository', () async {
      // Arrange
      final mockSession = WatchSession(
        id: 'test-session-id',
        videoId: testVideo.id,
        userId: 'test-viewer-id',
        startTime: now,
      );
      when(mockRepository.startWatchSession(testVideo.id, 'test-viewer-id'))
          .thenAnswer((_) async => mockSession);
      when(mockRepository.updateWatchSession(
        mockSession.id,
        position: 30,
      )).thenAnswer((_) async {});

      // Set current video and start session
      final mockQuerySnapshot = MockFirestoreQuerySnapshot();
      final mockDoc = MockFirestoreDocumentSnapshot();
      when(mockDoc.data()).thenReturn(testVideo.toFirestore());
      when(mockDoc.id).thenReturn(testVideo.id);
      when(mockQuerySnapshot.docs).thenReturn([mockDoc]);
      when(mockRepository.getNextFeedVideo(startAfter: null))
          .thenAnswer((_) async => mockQuerySnapshot);
      await provider.loadNextVideo();
      // await provider.startWatchSession('test-viewer-id');

      // Act
      // await provider.updateWatchPosition(30);

      // Assert
      verify(mockRepository.updateWatchSession(
        mockSession.id,
        position: 30,
      )).called(1);
    });

    test('endCurrentSession ends session through repository', () async {
      // Arrange
      final mockSession = WatchSession(
        id: 'test-session-id',
        videoId: testVideo.id,
        userId: 'test-viewer-id',
        startTime: now,
      );
      when(mockRepository.startWatchSession(testVideo.id, 'test-viewer-id'))
          .thenAnswer((_) async => mockSession);
      when(mockRepository.endWatchSession(mockSession.id, testVideo.id))
          .thenAnswer((_) async {});

      // Set current video and start session
      final mockQuerySnapshot = MockFirestoreQuerySnapshot();
      final mockDoc = MockFirestoreDocumentSnapshot();
      when(mockDoc.data()).thenReturn(testVideo.toFirestore());
      when(mockDoc.id).thenReturn(testVideo.id);
      when(mockQuerySnapshot.docs).thenReturn([mockDoc]);
      when(mockRepository.getNextFeedVideo(startAfter: null))
          .thenAnswer((_) async => mockQuerySnapshot);
      await provider.loadNextVideo();
      // await provider.startWatchSession('test-viewer-id');

      // // Act
      // await provider.endCurrentSession();

      // Assert
      verify(mockRepository.endWatchSession(mockSession.id, testVideo.id)).called(1);
      expect(provider.currentSession, isNull);
    });
  });
} 