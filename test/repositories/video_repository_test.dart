import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echochamber/models/video_model.dart';
import 'package:echochamber/repositories/video_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late VideoRepository videoRepository;
  late DateTime now;
  late Video testVideo;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    videoRepository = VideoRepository(firestore: fakeFirestore);
    now = DateTime.now();
    
    testVideo = Video(
      id: 'test-video-id',
      userId: 'test-user-id',
      title: 'Test Video',
      description: 'Test Description',
      duration: 120,
      videoUrl: 'https://example.com/master.m3u8',
      hlsBasePath: 'videos/test-video-id',
      thumbnailUrl: 'https://example.com/thumbnail.jpg',
      uploadedAt: now,
      lastModified: now,
      tags: ['tag1', 'tag2'],
      genres: ['genre1', 'genre2'],
      timestamps: [
        VideoTimestamp(time: 0.0, label: 'Intro'),
        VideoTimestamp(time: 60.0, label: 'Middle')
      ],
      credits: [
        VideoCredit(
          userId: 'credit-user-1',
          name: 'Credit Person',
          role: 'Director',
          profileUrl: 'https://example.com/credit.jpg'
        )
      ],
      author: {
        'id': 'test-user-id',
        'name': 'Test Author',
        'profilePictureUrl': 'https://example.com/profile.jpg',
      },
      copyrightStatus: {
        'status': 'pending',
        'owner': 'Test Author',
        'license': 'Standard',
      },
      processingStatus: VideoProcessingStatus.completed,
      validationMetadata: VideoValidationMetadata(
        width: 1920,
        height: 1080,
        duration: 120.0,
        codec: 'h264',
        format: 'hls',
        variants: [
          VideoQualityVariant(
            quality: '1080p',
            bitrate: 5000000,
            playlistUrl: 'https://example.com/hls/1080p.m3u8'
          ),
          VideoQualityVariant(
            quality: '720p',
            bitrate: 2800000,
            playlistUrl: 'https://example.com/hls/720p.m3u8'
          ),
          VideoQualityVariant(
            quality: '480p',
            bitrate: 1400000,
            playlistUrl: 'https://example.com/hls/480p.m3u8'
          )
        ]
      ),
      subtitles: [
        VideoSubtitle(
          timestamp: 0.0,
          text: 'Hello',
          language: 'en'
        )
      ],
    );
  });

  group('VideoRepository - Basic CRUD Operations', () {
    test('createVideo - should store all video fields correctly in Firestore', () async {
      // Act
      await videoRepository.createVideo(testVideo);

      // Assert
      final videoDoc = await fakeFirestore.collection('videos').doc(testVideo.id).get();
      final data = videoDoc.data()!;
      
      // Verify document exists
      expect(videoDoc.exists, true);
      
      // Verify basic fields
      expect(data['userId'], testVideo.userId);
      expect(data['title'], testVideo.title);
      expect(data['description'], testVideo.description);
      expect(data['duration'], testVideo.duration);
      expect(data['videoUrl'], testVideo.videoUrl);
      expect(data['thumbnailUrl'], testVideo.thumbnailUrl);
      
      // Verify timestamps (DateTime fields)
      expect((data['uploadedAt'] as Timestamp).toDate(), testVideo.uploadedAt);
      expect((data['lastModified'] as Timestamp).toDate(), testVideo.lastModified);
      
      // Verify arrays
      expect(List<String>.from(data['tags']), testVideo.tags);
      expect(List<String>.from(data['genres']), testVideo.genres);
      
      // Verify nested objects
      expect(data['author']['id'], testVideo.author['id']);
      expect(data['author']['name'], testVideo.author['name']);
      expect(data['author']['profilePictureUrl'], testVideo.author['profilePictureUrl']);
      
      expect(data['copyrightStatus']['status'], testVideo.copyrightStatus['status']);
      expect(data['copyrightStatus']['owner'], testVideo.copyrightStatus['owner']);
      expect(data['copyrightStatus']['license'], testVideo.copyrightStatus['license']);
      
      // Verify complex nested arrays
      final timestamps = List<Map<String, dynamic>>.from(data['timestamps']);
      expect(timestamps[0]['time'], testVideo.timestamps[0].time);
      expect(timestamps[0]['label'], testVideo.timestamps[0].label);
      expect(timestamps[1]['time'], testVideo.timestamps[1].time);
      expect(timestamps[1]['label'], testVideo.timestamps[1].label);
      
      final credits = List<Map<String, dynamic>>.from(data['credits']);
      expect(credits[0]['userId'], testVideo.credits[0].userId);
      expect(credits[0]['name'], testVideo.credits[0].name);
      expect(credits[0]['role'], testVideo.credits[0].role);
      expect(credits[0]['profileUrl'], testVideo.credits[0].profileUrl);
      
      final subtitles = List<Map<String, dynamic>>.from(data['subtitles']);
      expect(subtitles[0]['timestamp'], testVideo.subtitles![0].timestamp);
      expect(subtitles[0]['text'], testVideo.subtitles![0].text);
      expect(subtitles[0]['language'], testVideo.subtitles![0].language);
      
      // Verify enums
      expect(data['processingStatus'], testVideo.processingStatus.toString().split('.').last);
      
      // Verify validation metadata
      final validationMetadata = data['validationMetadata'];
      expect(validationMetadata['width'], testVideo.validationMetadata?.width);
      expect(validationMetadata['height'], testVideo.validationMetadata?.height);
      expect(validationMetadata['duration'], testVideo.validationMetadata?.duration);
      expect(validationMetadata['codec'], testVideo.validationMetadata?.codec);
      expect(validationMetadata['format'], testVideo.validationMetadata?.format);
      expect(validationMetadata['variants'], isNotNull);
      expect(validationMetadata['variants'], hasLength(3));
      expect(validationMetadata['variants'][0]['quality'], '1080p');
      expect(validationMetadata['variants'][0]['bitrate'], 5000000);
      expect(validationMetadata['variants'][0]['playlistUrl'], 'https://example.com/hls/1080p.m3u8');
      
      // Verify counters start at 0
      expect(data['likesCount'], 0);
      expect(data['commentsCount'], 0);
      expect(data['viewsCount'], 0);
      expect(data['sharesCount'], 0);
    });

    test('createVideo - should successfully create a video in Firestore', () async {
      // Act
      await videoRepository.createVideo(testVideo);

      // Assert
      final videoDoc = await fakeFirestore.collection('videos').doc(testVideo.id).get();
      expect(videoDoc.exists, true);
      expect(videoDoc.data()?['title'], testVideo.title);
      expect(videoDoc.data()?['description'], testVideo.description);
      expect(videoDoc.data()?['duration'], testVideo.duration);
      expect(videoDoc.data()?['videoUrl'], testVideo.videoUrl);
      expect(videoDoc.data()?['thumbnailUrl'], testVideo.thumbnailUrl);
      expect(videoDoc.data()?['author']['name'], testVideo.author['name']);
      expect(videoDoc.data()?['copyrightStatus']['status'], testVideo.copyrightStatus['status']);
    });

    test('getVideoById - should return null for non-existent video', () async {
      // Act
      final result = await videoRepository.getVideoById('non-existent-id');

      // Assert
      expect(result, isNull);
    });

    test('getVideoById - should return video for existing video', () async {
      // Arrange
      await videoRepository.createVideo(testVideo);

      // Act
      final result = await videoRepository.getVideoById(testVideo.id);

      // Assert
      expect(result, isNotNull);
      expect(result?.id, testVideo.id);
      expect(result?.title, testVideo.title);
      expect(result?.description, testVideo.description);
      expect(result?.duration, testVideo.duration);
      expect(result?.videoUrl, testVideo.videoUrl);
      expect(result?.thumbnailUrl, testVideo.thumbnailUrl);
      expect(result?.author['name'], testVideo.author['name']);
      expect(result?.copyrightStatus['status'], testVideo.copyrightStatus['status']);
    });
  });

  group('VideoRepository', () {
    final testVideo = Video(
      id: 'test_video_id',
      userId: 'test_user_id',
      title: 'Test Video',
      description: 'Test Description',
      duration: 120,
      videoUrl: 'https://example.com/master.m3u8',
      hlsBasePath: 'videos/test_video_id',
      thumbnailUrl: 'https://example.com/thumbnail.jpg',
      uploadedAt: DateTime.now(),
      lastModified: DateTime.now(),
      author: {
        'id': 'test_user_id',
        'name': 'Test User',
        'profilePictureUrl': 'https://example.com/profile.jpg',
      },
      copyrightStatus: {
        'status': 'cleared',
        'owner': 'Test User',
        'license': 'CC BY',
      },
      validationMetadata: VideoValidationMetadata(
        width: 1920,
        height: 1080,
        duration: 120.0,
        codec: 'h264',
        format: 'hls',
        variants: [
          VideoQualityVariant(
            quality: '1080p',
            bitrate: 5000000,
            playlistUrl: 'https://example.com/hls/1080p.m3u8'
          )
        ]
      ),
    );

    test('createVideo successfully creates a video document', () async {
      // Act
      await videoRepository.createVideo(testVideo);

      // Assert
      final doc = await fakeFirestore.collection('videos').doc(testVideo.id).get();
      expect(doc.exists, true);
      expect(doc.data()!['title'], testVideo.title);
      expect(doc.data()!['description'], testVideo.description);
    });

    test('getVideoById returns correct video', () async {
      // Arrange
      await videoRepository.createVideo(testVideo);

      // Act
      final video = await videoRepository.getVideoById(testVideo.id);

      // Assert
      expect(video, isNotNull);
      expect(video!.id, testVideo.id);
      expect(video.title, testVideo.title);
      expect(video.description, testVideo.description);
    });

    test('updateVideo successfully updates video metadata', () async {
      // Arrange
      await videoRepository.createVideo(testVideo);
      final updates = {
        'title': 'Updated Title',
        'description': 'Updated Description',
      };

      // Act
      await videoRepository.updateVideo(testVideo.id, updates);

      // Assert
      final doc = await fakeFirestore.collection('videos').doc(testVideo.id).get();
      expect(doc.data()!['title'], 'Updated Title');
      expect(doc.data()!['description'], 'Updated Description');
    });

    test('deleteVideo successfully deletes video document', () async {
      // Arrange
      await videoRepository.createVideo(testVideo);

      // Act
      await videoRepository.deleteVideo(testVideo.id);

      // Assert
      final doc = await fakeFirestore.collection('videos').doc(testVideo.id).get();
      expect(doc.exists, false);
    });

    test('incrementViewCount increases view count by 1', () async {
      // Arrange
      await videoRepository.createVideo(testVideo);

      // Act
      await videoRepository.incrementViewCount(testVideo.id);

      // Assert
      final doc = await fakeFirestore.collection('videos').doc(testVideo.id).get();
      expect(doc.data()!['viewsCount'], 1);
    });

    test('likeVideo adds like and increments like count', () async {
      // Arrange
      await videoRepository.createVideo(testVideo);
      const userId = 'test_like_user_id';

      // Act
      await videoRepository.likeVideo(testVideo.id, userId);

      // Assert
      final videoDoc = await fakeFirestore.collection('videos').doc(testVideo.id).get();
      final likeDoc = await fakeFirestore
          .collection('videos')
          .doc(testVideo.id)
          .collection('likes')
          .doc(userId)
          .get();

      expect(videoDoc.data()!['likesCount'], 1);
      expect(likeDoc.exists, true);
      expect(likeDoc.data()!['userId'], userId);
    });

    test('unlikeVideo removes like and decrements like count', () async {
      // Arrange
      await videoRepository.createVideo(testVideo);
      const userId = 'test_like_user_id';
      await videoRepository.likeVideo(testVideo.id, userId);

      // Act
      await videoRepository.unlikeVideo(testVideo.id, userId);

      // Assert
      final videoDoc = await fakeFirestore.collection('videos').doc(testVideo.id).get();
      final likeDoc = await fakeFirestore
          .collection('videos')
          .doc(testVideo.id)
          .collection('likes')
          .doc(userId)
          .get();

      expect(videoDoc.data()!['likesCount'], 0);
      expect(likeDoc.exists, false);
    });

    test('hasUserLikedVideo returns correct like status', () async {
      // Arrange
      await videoRepository.createVideo(testVideo);
      const userId = 'test_like_user_id';
      await videoRepository.likeVideo(testVideo.id, userId);

      // Act
      final hasLiked = await videoRepository.hasUserLikedVideo(testVideo.id, userId);
      final hasNotLiked = await videoRepository.hasUserLikedVideo(testVideo.id, 'other_user_id');

      // Assert
      expect(hasLiked, true);
      expect(hasNotLiked, false);
    });

    test('addComment adds comment and increments comment count', () async {
      // Arrange
      await videoRepository.createVideo(testVideo);
      const userId = 'test_comment_user_id';
      const comment = 'Test comment';

      // Act
      await videoRepository.addComment(testVideo.id, userId, comment);

      // Assert
      final videoDoc = await fakeFirestore.collection('videos').doc(testVideo.id).get();
      final comments = await fakeFirestore
          .collection('videos')
          .doc(testVideo.id)
          .collection('comments')
          .get();

      expect(videoDoc.data()!['commentsCount'], 1);
      expect(comments.docs.length, 1);
      expect(comments.docs.first.data()['comment'], comment);
      expect(comments.docs.first.data()['userId'], userId);
    });

    test('getUserVideos returns correct stream of user videos', () async {
      // Arrange
      await videoRepository.createVideo(testVideo);
      await videoRepository.createVideo(testVideo.copyWith(
        id: 'test_video_id_2',
        title: 'Second Test Video',
      ));

      // Act
      final stream = videoRepository.getUserVideos(testVideo.userId);

      // Assert
      expect(
        stream,
        emits(isA<QuerySnapshot>().having(
          (snapshot) => snapshot.docs.length,
          'number of videos',
          2,
        )),
      );
    });

    test('getVideosByGenre returns correct stream of videos', () async {
      // Arrange
      final videoWithGenre = testVideo.copyWith(
        genres: ['rock', 'jazz'],
      );
      await videoRepository.createVideo(videoWithGenre);

      // Act
      final stream = videoRepository.getVideosByGenre('rock');

      // Assert
      expect(
        stream,
        emits(isA<QuerySnapshot>().having(
          (snapshot) => snapshot.docs.length,
          'number of videos',
          1,
        )),
      );
    });

    test('getVideosByTag returns correct stream of videos', () async {
      // Arrange
      final videoWithTag = testVideo.copyWith(
        tags: ['guitar', 'solo'],
      );
      await videoRepository.createVideo(videoWithTag);

      // Act
      final stream = videoRepository.getVideosByTag('guitar');

      // Assert
      expect(
        stream,
        emits(isA<QuerySnapshot>().having(
          (snapshot) => snapshot.docs.length,
          'number of videos',
          1,
        )),
      );
    });
  });

  group('VideoRepository - Video Retrieval', () {
    test('getVideoById - should return null for non-existent video', () async {
      // Act
      final result = await videoRepository.getVideoById('non-existent-id');

      // Assert
      expect(result, isNull);
    });

    test('getVideoById - should return complete video data for existing video', () async {
      // Arrange
      await videoRepository.createVideo(testVideo);

      // Act
      final result = await videoRepository.getVideoById(testVideo.id);

      // Assert
      expect(result, isNotNull);
      
      // Verify basic fields
      expect(result?.id, testVideo.id);
      expect(result?.userId, testVideo.userId);
      expect(result?.title, testVideo.title);
      expect(result?.description, testVideo.description);
      expect(result?.duration, testVideo.duration);
      expect(result?.videoUrl, testVideo.videoUrl);
      expect(result?.thumbnailUrl, testVideo.thumbnailUrl);
      
      // Verify DateTime fields
      expect(result?.uploadedAt, testVideo.uploadedAt);
      expect(result?.lastModified, testVideo.lastModified);
      
      // Verify arrays
      expect(result?.tags, testVideo.tags);
      expect(result?.genres, testVideo.genres);
      
      // Verify nested objects
      expect(result?.author['id'], testVideo.author['id']);
      expect(result?.author['name'], testVideo.author['name']);
      expect(result?.author['profilePictureUrl'], testVideo.author['profilePictureUrl']);
      
      // Verify complex nested arrays
      expect(result?.timestamps.length, testVideo.timestamps.length);
      expect(result?.timestamps[0].time, testVideo.timestamps[0].time);
      expect(result?.timestamps[0].label, testVideo.timestamps[0].label);
      
      expect(result?.credits.length, testVideo.credits.length);
      expect(result?.credits[0].userId, testVideo.credits[0].userId);
      expect(result?.credits[0].name, testVideo.credits[0].name);
      
      expect(result?.subtitles?.length, testVideo.subtitles?.length);
      expect(result?.subtitles?[0].text, testVideo.subtitles?[0].text);
      expect(result?.subtitles?[0].language, testVideo.subtitles?[0].language);
      
      // Verify enums and metadata
      expect(result?.processingStatus, testVideo.processingStatus);
      expect(result?.validationMetadata?.width, testVideo.validationMetadata?.width);
      expect(result?.validationMetadata?.height, testVideo.validationMetadata?.height);
    });

    test('getVideoById - should handle deleted video gracefully', () async {
      // Arrange
      await videoRepository.createVideo(testVideo);
      await videoRepository.deleteVideo(testVideo.id);

      // Act
      final result = await videoRepository.getVideoById(testVideo.id);

      // Assert
      expect(result, isNull);
    });

    test('getVideoById - should handle malformed document data gracefully', () async {
      // Arrange - Create a malformed document directly in Firestore
      await fakeFirestore.collection('videos').doc('malformed-video').set({
        'userId': 'test-user-id',
        'title': 'Test Video',
        // Missing required fields
        'uploadedAt': Timestamp.fromDate(now),
        'lastModified': Timestamp.fromDate(now),
      });

      // Act & Assert
      expect(
        () => videoRepository.getVideoById('malformed-video'),
        throwsA(isA<TypeError>()), // or whatever exception your fromFirestore method throws
      );
    });

    test('getVideoById - should handle all optional fields being null', () async {
      // Arrange
      final minimalVideo = Video(
        id: 'minimal-video',
        userId: 'test-user-id',
        title: 'Minimal Video',
        description: 'Minimal Description',
        duration: 60,
        videoUrl: 'https://example.com/master.m3u8',
        hlsBasePath: 'videos/minimal-video',
        thumbnailUrl: 'https://example.com/minimal.jpg',
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
        validationMetadata: VideoValidationMetadata(
          width: 1920,
          height: 1080,
          duration: 60.0,
          codec: 'h264',
          format: 'hls',
          variants: [
            VideoQualityVariant(
              quality: '1080p',
              bitrate: 5000000,
              playlistUrl: 'https://example.com/hls/1080p.m3u8'
            )
          ]
        ),
      );
      await videoRepository.createVideo(minimalVideo);

      // Act
      final result = await videoRepository.getVideoById(minimalVideo.id);

      // Assert
      expect(result, isNotNull);
      expect(result?.tags, isEmpty);
      expect(result?.genres, isEmpty);
      expect(result?.timestamps, isEmpty);
      expect(result?.credits, isEmpty);
      expect(result?.subtitles, isNull);
      expect(result?.validationErrors, isNull);
      expect(result?.scheduledPublishTime, isNull);
      expect(result?.duetVideoId, isNull);
      
      // Verify required HLS fields are present
      expect(result?.validationMetadata?.format, 'hls');
      expect(result?.validationMetadata?.variants, isNotNull);
      expect(result?.validationMetadata?.variants?.length, 1);
      expect(result?.hlsBasePath, isNotNull);
    });
  });
} 