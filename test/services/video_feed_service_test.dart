import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echochamber/services/video_feed_service.dart';
import 'package:echochamber/repositories/video_repository.dart';
import 'package:echochamber/models/video_model.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'video_feed_service_test.mocks.dart';

// Generate mocks
@GenerateMocks([VideoRepository])
void main() {
  group('VideoFeedService Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockVideoRepository mockVideoRepository;
    late VideoFeedService videoFeedService;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      mockVideoRepository = MockVideoRepository();
      videoFeedService = VideoFeedService(videoRepository: mockVideoRepository);
    });

    test('getNextVideo returns null when no videos exist', () async {
      // Arrange
      final querySnapshot = await fakeFirestore.collection('videos')
          .orderBy('uploadedAt', descending: true)
          .limit(1)
          .get();

      // Act
      final result = await videoFeedService.getNextVideo();

      // Assert
      expect(result, isNull);
      expect(querySnapshot.docs.isEmpty, true);
    });
  });
} 