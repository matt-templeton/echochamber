import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echochamber/models/video_model.dart';
import 'package:echochamber/repositories/video_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late VideoRepository videoRepository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    videoRepository = VideoRepository(firestore: fakeFirestore);
  });

  group('VideoRepository', () {
    final testVideo = Video(
      id: 'test_video_id',
      userId: 'test_user_id',
      title: 'Test Video',
      description: 'Test Description',
      duration: 120,
      videoUrl: 'https://example.com/video.mp4',
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
} 