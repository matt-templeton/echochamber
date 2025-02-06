import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echochamber/models/video_model.dart';

void main() {
  late Map<String, dynamic> testData;
  late DateTime now;

  setUp(() {
    now = DateTime.now();
    testData = {
      'id': 'test-video-id',
      'userId': 'test-user-id',
      'title': 'Test Video',
      'description': 'Test video description',
      'duration': 120,
      'videoUrl': 'https://example.com/video.mp4',
      'thumbnailUrl': 'https://example.com/thumbnail.jpg',
      'uploadedAt': Timestamp.fromDate(now),
      'lastModified': Timestamp.fromDate(now),
      'likesCount': 0,
      'commentsCount': 0,
      'viewsCount': 0,
      'sharesCount': 0,
      'tags': ['test', 'video'],
      'genres': ['music', 'entertainment'],
      'author': {
        'id': 'test-user-id',
        'name': 'Test Author',
        'profilePictureUrl': 'https://example.com/profile.jpg',
      },
      'processingStatus': 'pending',
      'copyrightStatus': {
        'status': 'pending',
        'owner': 'Test Author',
        'license': 'Standard',
      },
    };
  });

  group('Video - Basic Creation and Validation', () {
    test('should create video with required fields and default values', () {
      // Arrange
      final minimalVideo = Video(
        id: 'test-video-id',
        userId: 'test-user-id',
        title: 'Test Video',
        description: 'Test Description',
        duration: 120,
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumbnail.jpg',
        uploadedAt: now,
        lastModified: now,
        author: {
          'id': 'test-user-id',
          'name': 'Test Author',
        },
        copyrightStatus: {
          'status': 'pending',
          'owner': 'Test Author',
        },
      );

      // Assert
      // Required fields should match provided values
      expect(minimalVideo.id, 'test-video-id');
      expect(minimalVideo.userId, 'test-user-id');
      expect(minimalVideo.title, 'Test Video');
      expect(minimalVideo.description, 'Test Description');
      expect(minimalVideo.duration, 120);
      expect(minimalVideo.videoUrl, 'https://example.com/video.mp4');
      expect(minimalVideo.thumbnailUrl, 'https://example.com/thumbnail.jpg');
      expect(minimalVideo.uploadedAt, now);
      expect(minimalVideo.lastModified, now);
      
      // Optional fields should have default values
      expect(minimalVideo.likesCount, 0);
      expect(minimalVideo.commentsCount, 0);
      expect(minimalVideo.viewsCount, 0);
      expect(minimalVideo.sharesCount, 0);
      expect(minimalVideo.tags, isEmpty);
      expect(minimalVideo.genres, isEmpty);
      expect(minimalVideo.timestamps, isEmpty);
      expect(minimalVideo.credits, isEmpty);
      expect(minimalVideo.ageRestricted, false);
      expect(minimalVideo.processingStatus, VideoProcessingStatus.pending);
      expect(minimalVideo.processingError, VideoProcessingError.none);
      expect(minimalVideo.validationMetadata, isNull);
      expect(minimalVideo.validationErrors, isNull);
      expect(minimalVideo.scheduledPublishTime, isNull);
      expect(minimalVideo.duetVideoId, isNull);
      expect(minimalVideo.subtitles, isNull);
    });
  });

  group('Video - Firestore Integration', () {
    test('fromFirestore should correctly create Video from Firestore document', () {
      // Arrange
      final doc = MockDocumentSnapshot(
        id: 'test-video-id',
        data: testData,
      );

      // Act
      final video = Video.fromFirestore(doc);

      // Assert
      expect(video.id, 'test-video-id');
      expect(video.userId, 'test-user-id');
      expect(video.title, 'Test Video');
      expect(video.description, 'Test video description');
      expect(video.duration, 120);
      expect(video.videoUrl, 'https://example.com/video.mp4');
      expect(video.thumbnailUrl, 'https://example.com/thumbnail.jpg');
      expect(video.uploadedAt, now);
      expect(video.lastModified, now);
      expect(video.likesCount, 0);
      expect(video.commentsCount, 0);
      expect(video.viewsCount, 0);
      expect(video.sharesCount, 0);
      expect(video.tags, ['test', 'video']);
      expect(video.genres, ['music', 'entertainment']);
      expect(video.author['id'], 'test-user-id');
      expect(video.author['name'], 'Test Author');
      expect(video.processingStatus, VideoProcessingStatus.pending);
      expect(video.copyrightStatus['status'], 'pending');
    });

    test('toFirestore should correctly convert Video to Firestore document', () {
      // Arrange
      final video = Video(
        id: 'test-video-id',
        userId: 'test-user-id',
        title: 'Test Video',
        description: 'Test Description',
        duration: 120,
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumbnail.jpg',
        uploadedAt: now,
        lastModified: now,
        tags: ['test', 'video'],
        genres: ['music'],
        author: {
          'id': 'test-user-id',
          'name': 'Test Author',
        },
        copyrightStatus: {
          'status': 'pending',
          'owner': 'Test Author',
        },
        processingStatus: VideoProcessingStatus.completed,
        processingError: VideoProcessingError.none,
      );

      // Act
      final firestoreData = video.toFirestore();

      // Assert
      expect(firestoreData['userId'], 'test-user-id');
      expect(firestoreData['title'], 'Test Video');
      expect(firestoreData['description'], 'Test Description');
      expect(firestoreData['duration'], 120);
      expect(firestoreData['videoUrl'], 'https://example.com/video.mp4');
      expect(firestoreData['thumbnailUrl'], 'https://example.com/thumbnail.jpg');
      expect(firestoreData['uploadedAt'], isA<Timestamp>());
      expect(firestoreData['lastModified'], isA<Timestamp>());
      expect(firestoreData['tags'], ['test', 'video']);
      expect(firestoreData['genres'], ['music']);
      expect(firestoreData['author']['id'], 'test-user-id');
      expect(firestoreData['author']['name'], 'Test Author');
      expect(firestoreData['processingStatus'], 'completed');
      expect(firestoreData['copyrightStatus']['status'], 'pending');
      
      // Optional fields should be omitted if null
      expect(firestoreData.containsKey('scheduledPublishTime'), false);
      expect(firestoreData.containsKey('duetVideoId'), false);
      expect(firestoreData.containsKey('subtitles'), false);
      expect(firestoreData.containsKey('validationMetadata'), false);
      expect(firestoreData.containsKey('validationErrors'), false);
    });
  });

  group('Video - Processing Status Management', () {
    test('should handle all processing status values from Firestore', () {
      // Test each possible processing status
      for (final status in VideoProcessingStatus.values) {
        // Arrange
        final statusData = {...testData, 'processingStatus': status.toString().split('.').last};
        final doc = MockDocumentSnapshot(id: 'test-video-id', data: statusData);

        // Act
        final video = Video.fromFirestore(doc);

        // Assert
        expect(
          video.processingStatus, 
          status,
          reason: 'Failed to convert status ${status.toString().split('.').last}'
        );
      }
    });

    test('should handle all processing error values from Firestore', () {
      // Test each possible processing error
      for (final error in VideoProcessingError.values) {
        // Arrange
        final errorData = {...testData, 'processingError': error.toString().split('.').last};
        final doc = MockDocumentSnapshot(id: 'test-video-id', data: errorData);

        // Act
        final video = Video.fromFirestore(doc);

        // Assert
        expect(
          video.processingError, 
          error,
          reason: 'Failed to convert error ${error.toString().split('.').last}'
        );
      }
    });

    test('should handle status transitions through copyWith', () {
      // Arrange
      final initialVideo = Video(
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

      // Act & Assert
      // Test typical processing flow
      final validatingVideo = initialVideo.copyWith(
        processingStatus: VideoProcessingStatus.validating
      );
      expect(validatingVideo.processingStatus, VideoProcessingStatus.validating);

      final transcodingVideo = validatingVideo.copyWith(
        processingStatus: VideoProcessingStatus.transcoding
      );
      expect(transcodingVideo.processingStatus, VideoProcessingStatus.transcoding);

      final failedVideo = transcodingVideo.copyWith(
        processingStatus: VideoProcessingStatus.failed,
        processingError: VideoProcessingError.processing_failed
      );
      expect(failedVideo.processingStatus, VideoProcessingStatus.failed);
      expect(failedVideo.processingError, VideoProcessingError.processing_failed);
    });
  });

  group('Video - Metadata Management', () {
    test('should correctly handle validation metadata from Firestore', () {
      // Arrange
      final metadataData = {
        ...testData,
        'validationMetadata': {
          'width': 1920,
          'height': 1080,
          'duration': 180.5,
          'codec': 'h264',
          'format': 'mp4',
          'bitrate': 5000000,
        },
      };
      final doc = MockDocumentSnapshot(id: 'test-video-id', data: metadataData);

      // Act
      final video = Video.fromFirestore(doc);

      // Assert
      expect(video.validationMetadata, isNotNull);
      expect(video.validationMetadata?.width, 1920);
      expect(video.validationMetadata?.height, 1080);
      expect(video.validationMetadata?.duration, 180.5);
      expect(video.validationMetadata?.codec, 'h264');
      expect(video.validationMetadata?.format, 'mp4');
      expect(video.validationMetadata?.bitrate, 5000000);
    });

    test('should correctly convert validation metadata to Firestore', () {
      // Arrange
      final metadata = VideoValidationMetadata(
        width: 1920,
        height: 1080,
        duration: 180.5,
        codec: 'h264',
        format: 'mp4',
        bitrate: 5000000,
      );
      
      final video = Video(
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
        validationMetadata: metadata,
      );

      // Act
      final firestoreData = video.toFirestore();

      // Assert
      expect(firestoreData['validationMetadata'], isNotNull);
      expect(firestoreData['validationMetadata']['width'], 1920);
      expect(firestoreData['validationMetadata']['height'], 1080);
      expect(firestoreData['validationMetadata']['duration'], 180.5);
      expect(firestoreData['validationMetadata']['codec'], 'h264');
      expect(firestoreData['validationMetadata']['format'], 'mp4');
      expect(firestoreData['validationMetadata']['bitrate'], 5000000);
    });

    test('should handle partial validation metadata', () {
      // Arrange
      final metadataData = {
        ...testData,
        'validationMetadata': {
          'width': 1920,
          'height': 1080,
          // Omitting other fields to test partial data
        },
      };
      final doc = MockDocumentSnapshot(id: 'test-video-id', data: metadataData);

      // Act
      final video = Video.fromFirestore(doc);

      // Assert
      expect(video.validationMetadata, isNotNull);
      expect(video.validationMetadata?.width, 1920);
      expect(video.validationMetadata?.height, 1080);
      expect(video.validationMetadata?.duration, isNull);
      expect(video.validationMetadata?.codec, isNull);
      expect(video.validationMetadata?.format, isNull);
      expect(video.validationMetadata?.bitrate, isNull);
    });

    test('should handle social metadata updates', () {
      // Arrange
      final initialVideo = Video(
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

      // Act
      final updatedVideo = initialVideo.copyWith(
        likesCount: 10,
        commentsCount: 5,
        viewsCount: 100,
        sharesCount: 3,
      );

      // Assert
      expect(updatedVideo.likesCount, 10);
      expect(updatedVideo.commentsCount, 5);
      expect(updatedVideo.viewsCount, 100);
      expect(updatedVideo.sharesCount, 3);
      
      // Original video should be unchanged
      expect(initialVideo.likesCount, 0);
      expect(initialVideo.commentsCount, 0);
      expect(initialVideo.viewsCount, 0);
      expect(initialVideo.sharesCount, 0);
    });
  });

  group('Video - Associated Content', () {
    test('should handle video timestamps from Firestore', () {
      // Arrange
      final timestampData = {
        ...testData,
        'timestamps': [
          {'time': 30.5, 'label': 'Introduction'},
          {'time': 120.0, 'label': 'Main Topic'},
          {'time': 180.5, 'label': 'Conclusion'},
        ],
      };
      final doc = MockDocumentSnapshot(id: 'test-video-id', data: timestampData);

      // Act
      final video = Video.fromFirestore(doc);

      // Assert
      expect(video.timestamps, hasLength(3));
      expect(video.timestamps[0].time, 30.5);
      expect(video.timestamps[0].label, 'Introduction');
      expect(video.timestamps[1].time, 120.0);
      expect(video.timestamps[1].label, 'Main Topic');
      expect(video.timestamps[2].time, 180.5);
      expect(video.timestamps[2].label, 'Conclusion');
    });

    test('should handle video credits from Firestore', () {
      // Arrange
      final creditData = {
        ...testData,
        'credits': [
          {
            'userId': 'user1',
            'name': 'John Doe',
            'role': 'Director',
            'profileUrl': 'https://example.com/john.jpg',
          },
          {
            'userId': 'user2',
            'name': 'Jane Smith',
            'role': 'Editor',
          },
        ],
      };
      final doc = MockDocumentSnapshot(id: 'test-video-id', data: creditData);

      // Act
      final video = Video.fromFirestore(doc);

      // Assert
      expect(video.credits, hasLength(2));
      
      // Check first credit with all fields
      expect(video.credits[0].userId, 'user1');
      expect(video.credits[0].name, 'John Doe');
      expect(video.credits[0].role, 'Director');
      expect(video.credits[0].profileUrl, 'https://example.com/john.jpg');
      
      // Check second credit with optional field omitted
      expect(video.credits[1].userId, 'user2');
      expect(video.credits[1].name, 'Jane Smith');
      expect(video.credits[1].role, 'Editor');
      expect(video.credits[1].profileUrl, isNull);
    });

    test('should handle video subtitles from Firestore', () {
      // Arrange
      final subtitleData = {
        ...testData,
        'subtitles': [
          {
            'timestamp': 0.0,
            'text': 'Hello, welcome to the video',
            'language': 'en',
          },
          {
            'timestamp': 5.5,
            'text': 'Hola, bienvenidos al video',
            'language': 'es',
          },
        ],
      };
      final doc = MockDocumentSnapshot(id: 'test-video-id', data: subtitleData);

      // Act
      final video = Video.fromFirestore(doc);

      // Assert
      expect(video.subtitles, hasLength(2));
      expect(video.subtitles![0].timestamp, 0.0);
      expect(video.subtitles![0].text, 'Hello, welcome to the video');
      expect(video.subtitles![0].language, 'en');
      expect(video.subtitles![1].timestamp, 5.5);
      expect(video.subtitles![1].text, 'Hola, bienvenidos al video');
      expect(video.subtitles![1].language, 'es');
    });

    test('should correctly convert associated content to Firestore', () {
      // Arrange
      final video = Video(
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
        timestamps: [
          VideoTimestamp(time: 30.5, label: 'Introduction'),
          VideoTimestamp(time: 120.0, label: 'Main Topic'),
        ],
        credits: [
          VideoCredit(
            userId: 'user1',
            name: 'John Doe',
            role: 'Director',
            profileUrl: 'https://example.com/john.jpg',
          ),
        ],
        subtitles: [
          VideoSubtitle(
            timestamp: 0.0,
            text: 'Hello',
            language: 'en',
          ),
        ],
      );

      // Act
      final firestoreData = video.toFirestore();

      // Assert
      // Check timestamps
      expect(firestoreData['timestamps'], hasLength(2));
      expect(firestoreData['timestamps'][0]['time'], 30.5);
      expect(firestoreData['timestamps'][0]['label'], 'Introduction');
      
      // Check credits
      expect(firestoreData['credits'], hasLength(1));
      expect(firestoreData['credits'][0]['userId'], 'user1');
      expect(firestoreData['credits'][0]['name'], 'John Doe');
      expect(firestoreData['credits'][0]['role'], 'Director');
      expect(firestoreData['credits'][0]['profileUrl'], 'https://example.com/john.jpg');
      
      // Check subtitles
      expect(firestoreData['subtitles'], hasLength(1));
      expect(firestoreData['subtitles'][0]['timestamp'], 0.0);
      expect(firestoreData['subtitles'][0]['text'], 'Hello');
      expect(firestoreData['subtitles'][0]['language'], 'en');
    });
  });

  group('Video - State Immutability', () {
    test('should maintain immutability of primitive fields when using copyWith', () {
      // Arrange
      final originalVideo = Video(
        id: 'test-video-id',
        userId: 'test-user-id',
        title: 'Original Title',
        description: 'Original Description',
        duration: 120,
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumbnail.jpg',
        uploadedAt: now,
        lastModified: now,
        author: {'id': 'test-user-id', 'name': 'Test Author'},
        copyrightStatus: {'status': 'pending', 'owner': 'Test Author'},
      );

      // Act
      final updatedVideo = originalVideo.copyWith(
        title: 'Updated Title',
        description: 'Updated Description',
        duration: 180,
      );

      // Assert
      // Original video should remain unchanged
      expect(originalVideo.title, 'Original Title');
      expect(originalVideo.description, 'Original Description');
      expect(originalVideo.duration, 120);

      // Updated video should have new values
      expect(updatedVideo.title, 'Updated Title');
      expect(updatedVideo.description, 'Updated Description');
      expect(updatedVideo.duration, 180);

      // Other fields should remain the same
      expect(updatedVideo.id, originalVideo.id);
      expect(updatedVideo.userId, originalVideo.userId);
      expect(updatedVideo.videoUrl, originalVideo.videoUrl);
    });

    test('should maintain independence of list fields when using copyWith', () {
      // Arrange
      final originalVideo = Video(
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
        tags: ['original', 'tags'],
        genres: ['original', 'genres'],
      );

      // Act
      final updatedVideo = originalVideo.copyWith(
        tags: ['updated', 'tags'],
        genres: ['updated', 'genres'],
      );

      // Assert
      // Original video should maintain original lists
      expect(originalVideo.tags, ['original', 'tags']);
      expect(originalVideo.genres, ['original', 'genres']);

      // Updated video should have new lists
      expect(updatedVideo.tags, ['updated', 'tags']);
      expect(updatedVideo.genres, ['updated', 'genres']);

      // Lists should be independent
      final newTags = List<String>.from(updatedVideo.tags)..add('new tag');
      final newGenres = List<String>.from(updatedVideo.genres)..add('new genre');

      expect(originalVideo.tags, ['original', 'tags']);
      expect(originalVideo.genres, ['original', 'genres']);
      expect(updatedVideo.tags, ['updated', 'tags']);
      expect(updatedVideo.genres, ['updated', 'genres']);
    });

    test('should maintain immutability of nested objects when using copyWith', () {
      // Arrange
      final originalVideo = Video(
        id: 'test-video-id',
        userId: 'test-user-id',
        title: 'Test Video',
        description: 'Test Description',
        duration: 120,
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumbnail.jpg',
        uploadedAt: now,
        lastModified: now,
        author: {'id': 'test-user-id', 'name': 'Original Author'},
        copyrightStatus: {'status': 'pending', 'owner': 'Original Owner'},
        validationMetadata: VideoValidationMetadata(
          width: 1920,
          height: 1080,
          duration: 120.0,
        ),
      );

      // Act
      final updatedVideo = originalVideo.copyWith(
        author: {'id': 'test-user-id', 'name': 'Updated Author'},
        copyrightStatus: {'status': 'approved', 'owner': 'Updated Owner'},
        validationMetadata: VideoValidationMetadata(
          width: 3840,
          height: 2160,
          duration: 180.0,
        ),
      );

      // Assert
      // Original video should maintain original nested objects
      expect(originalVideo.author['name'], 'Original Author');
      expect(originalVideo.copyrightStatus['owner'], 'Original Owner');
      expect(originalVideo.validationMetadata?.width, 1920);
      expect(originalVideo.validationMetadata?.height, 1080);

      // Updated video should have new nested objects
      expect(updatedVideo.author['name'], 'Updated Author');
      expect(updatedVideo.copyrightStatus['owner'], 'Updated Owner');
      expect(updatedVideo.validationMetadata?.width, 3840);
      expect(updatedVideo.validationMetadata?.height, 2160);
    });

    test('should maintain independence of complex nested lists when using copyWith', () {
      // Arrange
      final originalVideo = Video(
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
        timestamps: [
          VideoTimestamp(time: 0.0, label: 'Start'),
          VideoTimestamp(time: 60.0, label: 'Middle'),
        ],
        credits: [
          VideoCredit(userId: 'user1', name: 'Original Credit', role: 'Director'),
        ],
        subtitles: [
          VideoSubtitle(timestamp: 0.0, text: 'Original Text', language: 'en'),
        ],
      );

      // Act
      final updatedVideo = originalVideo.copyWith(
        timestamps: [
          VideoTimestamp(time: 0.0, label: 'New Start'),
          VideoTimestamp(time: 30.0, label: 'New Middle'),
        ],
        credits: [
          VideoCredit(userId: 'user2', name: 'New Credit', role: 'Editor'),
        ],
        subtitles: [
          VideoSubtitle(timestamp: 0.0, text: 'New Text', language: 'es'),
        ],
      );

      // Assert
      // Original video should maintain original nested lists
      expect(originalVideo.timestamps[0].label, 'Start');
      expect(originalVideo.credits[0].name, 'Original Credit');
      expect(originalVideo.subtitles![0].text, 'Original Text');

      // Updated video should have new nested lists
      expect(updatedVideo.timestamps[0].label, 'New Start');
      expect(updatedVideo.credits[0].name, 'New Credit');
      expect(updatedVideo.subtitles![0].text, 'New Text');

      // Create new lists to verify independence
      final newTimestamps = List<VideoTimestamp>.from(originalVideo.timestamps);
      final newCredits = List<VideoCredit>.from(originalVideo.credits);
      final newSubtitles = List<VideoSubtitle>.from(originalVideo.subtitles!);

      newTimestamps[0] = VideoTimestamp(time: 0.0, label: 'Modified');
      newCredits[0] = VideoCredit(userId: 'user3', name: 'Modified', role: 'Actor');
      newSubtitles[0] = VideoSubtitle(timestamp: 0.0, text: 'Modified', language: 'fr');

      // Original and updated videos should remain unchanged
      expect(originalVideo.timestamps[0].label, 'Start');
      expect(originalVideo.credits[0].name, 'Original Credit');
      expect(originalVideo.subtitles![0].text, 'Original Text');
      expect(updatedVideo.timestamps[0].label, 'New Start');
      expect(updatedVideo.credits[0].name, 'New Credit');
      expect(updatedVideo.subtitles![0].text, 'New Text');
    });
  });

  group('Video - Nested Object Handling', () {
    test('should properly construct nested objects with type safety', () {
      // Testing VideoTimestamp
      final timestamp = VideoTimestamp(time: 10.5, label: 'Test Label');
      expect(timestamp.time, isA<double>());
      expect(timestamp.label, isA<String>());
      expect(timestamp.time, 10.5);
      expect(timestamp.label, 'Test Label');

      // Testing VideoCredit
      final credit = VideoCredit(
        userId: 'test-user',
        name: 'Test Name',
        role: 'Test Role',
        profileUrl: 'https://example.com/profile.jpg',
      );
      expect(credit.userId, isA<String>());
      expect(credit.name, isA<String>());
      expect(credit.role, isA<String>());
      expect(credit.profileUrl, isA<String>());

      // Testing VideoSubtitle
      final subtitle = VideoSubtitle(
        timestamp: 5.0,
        text: 'Test Text',
        language: 'en',
      );
      expect(subtitle.timestamp, isA<double>());
      expect(subtitle.text, isA<String>());
      expect(subtitle.language, isA<String>());
    });

    test('should properly convert nested objects to/from maps', () {
      // Testing VideoTimestamp conversion
      final timestampMap = {'time': 10.5, 'label': 'Test Label'};
      final timestamp = VideoTimestamp.fromMap(timestampMap);
      final convertedTimestampMap = timestamp.toMap();
      expect(convertedTimestampMap, timestampMap);

      // Testing VideoCredit conversion
      final creditMap = {
        'userId': 'test-user',
        'name': 'Test Name',
        'role': 'Test Role',
        'profileUrl': 'https://example.com/profile.jpg',
      };
      final credit = VideoCredit.fromMap(creditMap);
      final convertedCreditMap = credit.toMap();
      expect(convertedCreditMap, creditMap);

      // Testing VideoSubtitle conversion
      final subtitleMap = {
        'timestamp': 5.0,
        'text': 'Test Text',
        'language': 'en',
      };
      final subtitle = VideoSubtitle.fromMap(subtitleMap);
      final convertedSubtitleMap = subtitle.toMap();
      expect(convertedSubtitleMap, subtitleMap);
    });

    test('should handle missing optional fields in nested objects', () {
      // Testing VideoCredit with missing optional field
      final creditMap = {
        'userId': 'test-user',
        'name': 'Test Name',
        'role': 'Test Role',
        // profileUrl is omitted
      };
      final credit = VideoCredit.fromMap(creditMap);
      expect(credit.profileUrl, isNull);
      
      final convertedCreditMap = credit.toMap();
      expect(convertedCreditMap.containsKey('profileUrl'), false);
    });

    test('should maintain type safety when handling collections of nested objects', () {
      final video = Video(
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
        timestamps: [
          VideoTimestamp(time: 0.0, label: 'Start'),
          VideoTimestamp(time: 60.0, label: 'Middle'),
        ],
        credits: [
          VideoCredit(userId: 'user1', name: 'Credit 1', role: 'Role 1'),
          VideoCredit(userId: 'user2', name: 'Credit 2', role: 'Role 2'),
        ],
        subtitles: [
          VideoSubtitle(timestamp: 0.0, text: 'Text 1', language: 'en'),
          VideoSubtitle(timestamp: 5.0, text: 'Text 2', language: 'es'),
        ],
      );

      // Verify collections contain correct types
      expect(video.timestamps, everyElement(isA<VideoTimestamp>()));
      expect(video.credits, everyElement(isA<VideoCredit>()));
      expect(video.subtitles, everyElement(isA<VideoSubtitle>()));

      // Verify collection elements maintain their type safety
      expect(video.timestamps.every((t) => t.time is double), true);
      expect(video.credits.every((c) => c.userId is String), true);
      expect(video.subtitles!.every((s) => s.timestamp is double), true);
    });
  });
}

// Mock class for DocumentSnapshot, following the pattern from user_model_test.dart
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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
} 