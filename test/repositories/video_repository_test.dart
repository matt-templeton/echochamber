// import 'package:flutter_test/flutter_test.dart';
// import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:echochamber/models/video_model.dart';
// import 'package:echochamber/repositories/video_repository.dart';

// Video createTestVideo({
//   String id = 'test-video-id',
//   String userId = 'test-user-id',
//   String title = 'Test Video',
//   String description = 'Test Description',
//   int duration = 120,
//   String? videoUrl,
//   String? hlsBasePath,
//   String? thumbnailUrl,
//   DateTime? uploadedAt,
//   DateTime? lastModified,
//   List<String>? tags,
//   List<String>? genres,
//   List<VideoTimestamp>? timestamps,
//   List<VideoCredit>? credits,
//   Map<String, dynamic>? author,
//   Map<String, dynamic>? copyrightStatus,
//   VideoProcessingStatus? processingStatus,
//   VideoValidationMetadata? validationMetadata,
//   List<VideoSubtitle>? subtitles,
// }) {
//   final now = uploadedAt ?? DateTime.now();
//   return Video(
//     id: id,
//     userId: userId,
//     title: title,
//     description: description,
//     duration: duration,
//     videoUrl: videoUrl ?? 'https://example.com/video.m3u8',
//     hlsBasePath: hlsBasePath ?? 'https://example.com/hls/test-video-id',
//     thumbnailUrl: thumbnailUrl ?? 'https://example.com/thumbnail.jpg',
//     uploadedAt: now,
//     lastModified: lastModified ?? now,
//     tags: tags ?? ['test', 'video', 'example'],
//     genres: genres ?? ['tutorial', 'tech'],
//     timestamps: timestamps ?? [
//       VideoTimestamp(time: 0.0, label: 'Intro'),
//       VideoTimestamp(time: 60.0, label: 'Main Content')
//     ],
//     credits: credits ?? [
//       VideoCredit(
//         userId: 'editor-id',
//         name: 'Test Editor',
//         role: 'Editor',
//         profileUrl: 'https://example.com/editor.jpg'
//       )
//     ],
//     author: author ?? {
//       'id': userId,
//       'name': 'Test Author',
//       'profilePictureUrl': 'https://example.com/profile.jpg',
//     },
//     copyrightStatus: copyrightStatus ?? {
//       'status': 'pending',
//       'owner': 'Test Author',
//       'license': 'Standard',
//     },
//     processingStatus: processingStatus ?? VideoProcessingStatus.completed,
//     validationMetadata: validationMetadata ?? VideoValidationMetadata(
//       width: 1920,
//       height: 1080,
//       duration: 120.0,
//       codec: 'h264',
//       format: 'hls',
//       variants: [
//         VideoQualityVariant(
//           quality: '1080p',
//           bitrate: 5000000,
//           playlistUrl: 'https://example.com/hls/1080p.m3u8'
//         ),
//         VideoQualityVariant(
//           quality: '720p',
//           bitrate: 2800000,
//           playlistUrl: 'https://example.com/hls/720p.m3u8'
//         ),
//         VideoQualityVariant(
//           quality: '480p',
//           bitrate: 1400000,
//           playlistUrl: 'https://example.com/hls/480p.m3u8'
//         )
//       ]
//     ),
//     subtitles: subtitles ?? [
//       VideoSubtitle(
//         timestamp: 0.0,
//         text: 'Hello',
//         language: 'en'
//       )
//     ],
//   );
// }

// void main() {
//   late FakeFirebaseFirestore fakeFirestore;
//   late VideoRepository videoRepository;
//   late DateTime now;
//   late Video testVideo;

//   setUp(() {
//     fakeFirestore = FakeFirebaseFirestore();
//     videoRepository = VideoRepository(firestore: fakeFirestore);
//     now = DateTime.now();
//     testVideo = createTestVideo(uploadedAt: now, lastModified: now);
//   });

//   group('VideoRepository - Basic CRUD Operations', () {
//     test('createVideo - should store all video fields correctly in Firestore', () async {
//       // Act
//       await videoRepository.createVideo(testVideo);

//       // Assert
//       final videoDoc = await fakeFirestore.collection('videos').doc(testVideo.id).get();
//       final data = videoDoc.data()!;
      
//       // Verify document exists
//       expect(videoDoc.exists, true);
      
//       // Verify basic fields
//       expect(data['userId'], testVideo.userId);
//       expect(data['title'], testVideo.title);
//       expect(data['description'], testVideo.description);
//       expect(data['duration'], testVideo.duration);
//       expect(data['videoUrl'], testVideo.videoUrl);
//       expect(data['thumbnailUrl'], testVideo.thumbnailUrl);
      
//       // Verify timestamps (DateTime fields)
//       expect((data['uploadedAt'] as Timestamp).toDate(), testVideo.uploadedAt);
//       expect((data['lastModified'] as Timestamp).toDate(), testVideo.lastModified);
      
//       // Verify arrays
//       expect(List<String>.from(data['tags']), testVideo.tags);
//       expect(List<String>.from(data['genres']), testVideo.genres);
      
//       // Verify nested objects
//       expect(data['author']['id'], testVideo.author['id']);
//       expect(data['author']['name'], testVideo.author['name']);
//       expect(data['author']['profilePictureUrl'], testVideo.author['profilePictureUrl']);
      
//       expect(data['copyrightStatus']['status'], testVideo.copyrightStatus['status']);
//       expect(data['copyrightStatus']['owner'], testVideo.copyrightStatus['owner']);
//       expect(data['copyrightStatus']['license'], testVideo.copyrightStatus['license']);
      
//       // Verify complex nested arrays
//       final timestamps = List<Map<String, dynamic>>.from(data['timestamps']);
//       expect(timestamps[0]['time'], testVideo.timestamps[0].time);
//       expect(timestamps[0]['label'], testVideo.timestamps[0].label);
//       expect(timestamps[1]['time'], testVideo.timestamps[1].time);
//       expect(timestamps[1]['label'], testVideo.timestamps[1].label);
      
//       final credits = List<Map<String, dynamic>>.from(data['credits']);
//       expect(credits[0]['userId'], testVideo.credits[0].userId);
//       expect(credits[0]['name'], testVideo.credits[0].name);
//       expect(credits[0]['role'], testVideo.credits[0].role);
//       expect(credits[0]['profileUrl'], testVideo.credits[0].profileUrl);
      
//       final subtitles = List<Map<String, dynamic>>.from(data['subtitles']);
//       expect(subtitles[0]['timestamp'], testVideo.subtitles![0].timestamp);
//       expect(subtitles[0]['text'], testVideo.subtitles![0].text);
//       expect(subtitles[0]['language'], testVideo.subtitles![0].language);
      
//       // Verify enums
//       expect(data['processingStatus'], testVideo.processingStatus.toString().split('.').last);
      
//       // Verify validation metadata
//       final validationMetadata = data['validationMetadata'];
//       expect(validationMetadata['width'], testVideo.validationMetadata?.width);
//       expect(validationMetadata['height'], testVideo.validationMetadata?.height);
//       expect(validationMetadata['duration'], testVideo.validationMetadata?.duration);
//       expect(validationMetadata['codec'], testVideo.validationMetadata?.codec);
//       expect(validationMetadata['format'], testVideo.validationMetadata?.format);
//       expect(validationMetadata['variants'], isNotNull);
//       expect(validationMetadata['variants'], hasLength(3));
//       expect(validationMetadata['variants'][0]['quality'], '1080p');
//       expect(validationMetadata['variants'][0]['bitrate'], 5000000);
//       expect(validationMetadata['variants'][0]['playlistUrl'], 'https://example.com/hls/1080p.m3u8');
      
//       // Verify counters start at 0
//       expect(data['likesCount'], 0);
//       expect(data['commentsCount'], 0);
//       expect(data['viewsCount'], 0);
//       expect(data['sharesCount'], 0);
//     });

//     test('createVideo - should successfully create a video in Firestore', () async {
//       // Act
//       await videoRepository.createVideo(testVideo);

//       // Assert
//       final videoDoc = await fakeFirestore.collection('videos').doc(testVideo.id).get();
//       expect(videoDoc.exists, true);
//       expect(videoDoc.data()?['title'], testVideo.title);
//       expect(videoDoc.data()?['description'], testVideo.description);
//       expect(videoDoc.data()?['duration'], testVideo.duration);
//       expect(videoDoc.data()?['videoUrl'], testVideo.videoUrl);
//       expect(videoDoc.data()?['thumbnailUrl'], testVideo.thumbnailUrl);
//       expect(videoDoc.data()?['author']['name'], testVideo.author['name']);
//       expect(videoDoc.data()?['copyrightStatus']['status'], testVideo.copyrightStatus['status']);
//     });

//     test('getVideoById - should return null for non-existent video', () async {
//       // Act
//       final result = await videoRepository.getVideoById('non-existent-id');

//       // Assert
//       expect(result, isNull);
//     });

//     test('getVideoById - should return video for existing video', () async {
//       // Arrange
//       await videoRepository.createVideo(testVideo);

//       // Act
//       final result = await videoRepository.getVideoById(testVideo.id);

//       // Assert
//       expect(result, isNotNull);
//       expect(result?.id, testVideo.id);
//       expect(result?.title, testVideo.title);
//       expect(result?.description, testVideo.description);
//       expect(result?.duration, testVideo.duration);
//       expect(result?.videoUrl, testVideo.videoUrl);
//       expect(result?.thumbnailUrl, testVideo.thumbnailUrl);
//       expect(result?.author['name'], testVideo.author['name']);
//       expect(result?.copyrightStatus['status'], testVideo.copyrightStatus['status']);
//     });
//   });

//   group('VideoRepository', () {
//     test('createVideo successfully creates a video document', () async {
//       final testVideo = createTestVideo();
      
//       // Act
//       await videoRepository.createVideo(testVideo);

//       // Assert
//       final doc = await fakeFirestore.collection('videos').doc(testVideo.id).get();
//       expect(doc.exists, true);
//       expect(doc.data()!['title'], testVideo.title);
//       expect(doc.data()!['description'], testVideo.description);
//     });

//     test('getVideoById returns correct video', () async {
//       final testVideo = createTestVideo();
      
//       // Arrange
//       await videoRepository.createVideo(testVideo);

//       // Act
//       final video = await videoRepository.getVideoById(testVideo.id);

//       // Assert
//       expect(video, isNotNull);
//       expect(video!.id, testVideo.id);
//       expect(video.title, testVideo.title);
//     });

//     test('updateVideo successfully updates video metadata', () async {
//       // Arrange
//       await videoRepository.createVideo(testVideo);
//       final updates = {
//         'title': 'Updated Title',
//         'description': 'Updated Description',
//       };

//       // Act
//       await videoRepository.updateVideo(testVideo.id, updates);

//       // Assert
//       final doc = await fakeFirestore.collection('videos').doc(testVideo.id).get();
//       expect(doc.data()!['title'], 'Updated Title');
//       expect(doc.data()!['description'], 'Updated Description');
//     });

//     test('deleteVideo successfully deletes video document', () async {
//       // Arrange
//       await videoRepository.createVideo(testVideo);

//       // Act
//       await videoRepository.deleteVideo(testVideo.id);

//       // Assert
//       final doc = await fakeFirestore.collection('videos').doc(testVideo.id).get();
//       expect(doc.exists, false);
//     });

//     test('incrementViewCount increases view count by 1', () async {
//       // Arrange
//       await videoRepository.createVideo(testVideo);

//       // Act
//       await videoRepository.incrementViewCount(testVideo.id);

//       // Assert
//       final doc = await fakeFirestore.collection('videos').doc(testVideo.id).get();
//       expect(doc.data()!['viewsCount'], 1);
//     });

//     test('likeVideo adds like and increments like count', () async {
//       // Arrange
//       await videoRepository.createVideo(testVideo);
//       const userId = 'test_like_user_id';

//       // Act
//       await videoRepository.likeVideo(testVideo.id, userId);

//       // Assert
//       final videoDoc = await fakeFirestore.collection('videos').doc(testVideo.id).get();
//       final likeDoc = await fakeFirestore
//           .collection('videos')
//           .doc(testVideo.id)
//           .collection('likes')
//           .doc(userId)
//           .get();

//       expect(videoDoc.data()!['likesCount'], 1);
//       expect(likeDoc.exists, true);
//       expect(likeDoc.data()!['userId'], userId);
//     });

//     test('unlikeVideo removes like and decrements like count', () async {
//       // Arrange
//       await videoRepository.createVideo(testVideo);
//       const userId = 'test_like_user_id';
//       await videoRepository.likeVideo(testVideo.id, userId);

//       // Act
//       await videoRepository.unlikeVideo(testVideo.id, userId);

//       // Assert
//       final videoDoc = await fakeFirestore.collection('videos').doc(testVideo.id).get();
//       final likeDoc = await fakeFirestore
//           .collection('videos')
//           .doc(testVideo.id)
//           .collection('likes')
//           .doc(userId)
//           .get();

//       expect(videoDoc.data()!['likesCount'], 0);
//       expect(likeDoc.exists, false);
//     });

//     test('hasUserLikedVideo returns correct like status', () async {
//       // Arrange
//       await videoRepository.createVideo(testVideo);
//       const userId = 'test_like_user_id';
//       await videoRepository.likeVideo(testVideo.id, userId);

//       // Act
//       final hasLiked = await videoRepository.hasUserLikedVideo(testVideo.id, userId);
//       final hasNotLiked = await videoRepository.hasUserLikedVideo(testVideo.id, 'other_user_id');

//       // Assert
//       expect(hasLiked, true);
//       expect(hasNotLiked, false);
//     });

//     test('addComment adds comment and increments comment count', () async {
//       // Arrange
//       await videoRepository.createVideo(testVideo);
//       const userId = 'test_comment_user_id';
//       const comment = 'Test comment';

//       // Act
//       await videoRepository.addComment(testVideo.id, userId, comment);

//       // Assert
//       final videoDoc = await fakeFirestore.collection('videos').doc(testVideo.id).get();
//       final comments = await fakeFirestore
//           .collection('videos')
//           .doc(testVideo.id)
//           .collection('comments')
//           .get();

//       expect(videoDoc.data()!['commentsCount'], 1);
//       expect(comments.docs.length, 1);
//       expect(comments.docs.first.data()['comment'], comment);
//       expect(comments.docs.first.data()['userId'], userId);
//     });

//     test('getUserVideos returns correct stream of user videos', () async {
//       // Arrange
//       await videoRepository.createVideo(testVideo);
//       await videoRepository.createVideo(testVideo.copyWith(
//         id: 'test_video_id_2',
//         title: 'Second Test Video',
//       ));

//       // Act
//       final stream = videoRepository.getUserVideos(testVideo.userId);

//       // Assert
//       expect(
//         stream,
//         emits(isA<QuerySnapshot>().having(
//           (snapshot) => snapshot.docs.length,
//           'number of videos',
//           2,
//         )),
//       );
//     });

//     test('getVideosByGenre returns correct stream of videos', () async {
//       // Arrange
//       final videoWithGenre = testVideo.copyWith(
//         genres: ['rock', 'jazz'],
//       );
//       await videoRepository.createVideo(videoWithGenre);

//       // Act
//       final stream = videoRepository.getVideosByGenre('rock');

//       // Assert
//       expect(
//         stream,
//         emits(isA<QuerySnapshot>().having(
//           (snapshot) => snapshot.docs.length,
//           'number of videos',
//           1,
//         )),
//       );
//     });

//     test('getVideosByTag returns correct stream of videos', () async {
//       // Arrange
//       final videoWithTag = testVideo.copyWith(
//         tags: ['guitar', 'solo'],
//       );
//       await videoRepository.createVideo(videoWithTag);

//       // Act
//       final stream = videoRepository.getVideosByTag('guitar');

//       // Assert
//       expect(
//         stream,
//         emits(isA<QuerySnapshot>().having(
//           (snapshot) => snapshot.docs.length,
//           'number of videos',
//           1,
//         )),
//       );
//     });
//   });

//   group('VideoRepository - Video Retrieval', () {
//     test('getVideoById - should return null for non-existent video', () async {
//       // Act
//       final result = await videoRepository.getVideoById('non-existent-id');

//       // Assert
//       expect(result, isNull);
//     });

//     test('getVideoById - should return complete video data for existing video', () async {
//       // Arrange
//       await videoRepository.createVideo(testVideo);

//       // Act
//       final result = await videoRepository.getVideoById(testVideo.id);

//       // Assert
//       expect(result, isNotNull);
      
//       // Verify basic fields
//       expect(result?.id, testVideo.id);
//       expect(result?.userId, testVideo.userId);
//       expect(result?.title, testVideo.title);
//       expect(result?.description, testVideo.description);
//       expect(result?.duration, testVideo.duration);
//       expect(result?.videoUrl, testVideo.videoUrl);
//       expect(result?.thumbnailUrl, testVideo.thumbnailUrl);
      
//       // Verify DateTime fields
//       expect(result?.uploadedAt, testVideo.uploadedAt);
//       expect(result?.lastModified, testVideo.lastModified);
      
//       // Verify arrays
//       expect(result?.tags, testVideo.tags);
//       expect(result?.genres, testVideo.genres);
      
//       // Verify nested objects
//       expect(result?.author['id'], testVideo.author['id']);
//       expect(result?.author['name'], testVideo.author['name']);
//       expect(result?.author['profilePictureUrl'], testVideo.author['profilePictureUrl']);
      
//       // Verify complex nested arrays
//       expect(result?.timestamps.length, testVideo.timestamps.length);
//       expect(result?.timestamps[0].time, testVideo.timestamps[0].time);
//       expect(result?.timestamps[0].label, testVideo.timestamps[0].label);
      
//       expect(result?.credits.length, testVideo.credits.length);
//       expect(result?.credits[0].userId, testVideo.credits[0].userId);
//       expect(result?.credits[0].name, testVideo.credits[0].name);
      
//       expect(result?.subtitles?.length, testVideo.subtitles?.length);
//       expect(result?.subtitles?[0].text, testVideo.subtitles?[0].text);
//       expect(result?.subtitles?[0].language, testVideo.subtitles?[0].language);
      
//       // Verify enums and metadata
//       expect(result?.processingStatus, testVideo.processingStatus);
//       expect(result?.validationMetadata?.width, testVideo.validationMetadata?.width);
//       expect(result?.validationMetadata?.height, testVideo.validationMetadata?.height);
//     });

//     test('getVideoById - should handle deleted video gracefully', () async {
//       // Arrange
//       await videoRepository.createVideo(testVideo);
//       await videoRepository.deleteVideo(testVideo.id);

//       // Act
//       final result = await videoRepository.getVideoById(testVideo.id);

//       // Assert
//       expect(result, isNull);
//     });

//     test('getVideoById - should handle malformed document data gracefully', () async {
//       // Arrange - Create a malformed document directly in Firestore
//       await fakeFirestore.collection('videos').doc('malformed-video').set({
//         'userId': 'test-user-id',
//         'title': 'Test Video',
//         // Missing required fields
//         'uploadedAt': Timestamp.fromDate(now),
//         'lastModified': Timestamp.fromDate(now),
//       });

//       // Act & Assert
//       expect(
//         () => videoRepository.getVideoById('malformed-video'),
//         throwsA(isA<TypeError>()), // or whatever exception your fromFirestore method throws
//       );
//     });

//     test('getVideoById - should handle all optional fields being null', () async {
//       // Arrange
//       final minimalVideo = Video(
//         id: 'minimal-video',
//         userId: 'test-user-id',
//         title: 'Minimal Video',
//         description: 'Minimal Description',
//         duration: 60,
//         videoUrl: 'https://example.com/master.m3u8',
//         hlsBasePath: 'videos/minimal-video',
//         thumbnailUrl: 'https://example.com/minimal.jpg',
//         uploadedAt: now,
//         lastModified: now,
//         author: {
//           'id': 'test-user-id',
//           'name': 'Test Author',
//         },
//         copyrightStatus: {
//           'status': 'pending',
//           'owner': 'Test Author',
//         },
//         validationMetadata: VideoValidationMetadata(
//           width: 1920,
//           height: 1080,
//           duration: 60.0,
//           codec: 'h264',
//           format: 'hls',
//           variants: [
//             VideoQualityVariant(
//               quality: '1080p',
//               bitrate: 5000000,
//               playlistUrl: 'https://example.com/hls/1080p.m3u8'
//             )
//           ]
//         ),
//       );
//       await videoRepository.createVideo(minimalVideo);

//       // Act
//       final result = await videoRepository.getVideoById(minimalVideo.id);

//       // Assert
//       expect(result, isNotNull);
//       expect(result?.tags, isEmpty);
//       expect(result?.genres, isEmpty);
//       expect(result?.timestamps, isEmpty);
//       expect(result?.credits, isEmpty);
//       expect(result?.subtitles, isNull);
//       expect(result?.validationErrors, isNull);
//       expect(result?.scheduledPublishTime, isNull);
//       expect(result?.duetVideoId, isNull);
      
//       // Verify required HLS fields are present
//       expect(result?.validationMetadata?.format, 'hls');
//       expect(result?.validationMetadata?.variants, isNotNull);
//       expect(result?.validationMetadata?.variants?.length, 1);
//       expect(result?.hlsBasePath, isNotNull);
//     });
//   });

//   group('VideoRepository - Watch Session Tests', () {
//     test('startWatchSession creates session and increments view count', () async {
//       final testVideo = createTestVideo();
      
//       // Arrange
//       await videoRepository.createVideo(testVideo);

//       // Act
//       final session = await videoRepository.startWatchSession(testVideo.id, 'test-user-id');

//       // Assert
//       expect(session, isNotNull);
//       expect(session.videoId, testVideo.id);
//       expect(session.userId, 'test-user-id');
//       expect(session.startTime, isNotNull);
//       expect(session.endTime, isNull);
//       expect(session.watchDuration, 0);
//       expect(session.lastPosition, 0);
//       expect(session.completedViewing, false);
//     });

//     test('startWatchSession creates new session for same user watching same video', () async {
//       final testVideo = createTestVideo();
      
//       // Arrange
//       await videoRepository.createVideo(testVideo);
//       await videoRepository.startWatchSession(testVideo.id, 'test-user-id');

//       // Act
//       final session = await videoRepository.startWatchSession(testVideo.id, 'test-user-id');

//       // Assert
//       expect(session, isNotNull);
//       expect(session.videoId, testVideo.id);
//       expect(session.userId, 'test-user-id');
//       expect(session.startTime, isNotNull);
//       expect(session.endTime, isNull);
//       expect(session.watchDuration, 0);
//       expect(session.lastPosition, 0);
//       expect(session.completedViewing, false);
//     });

//     test('getLastWatchSession returns most recent session for user and video', () async {
//       final testVideo = createTestVideo();
      
//       // Arrange
//       await videoRepository.createVideo(testVideo);
//       final firstSession = await videoRepository.startWatchSession(testVideo.id, 'test-user-id');
//       await Future.delayed(Duration(milliseconds: 100));
//       final secondSession = await videoRepository.startWatchSession(testVideo.id, 'test-user-id');

//       // Act
//       final lastSession = await videoRepository.getLastWatchSession(testVideo.id, 'test-user-id');

//       // Assert
//       expect(lastSession, isNotNull);
//       expect(lastSession!.id, secondSession.id);
//       expect(lastSession.startTime.isAfter(firstSession.startTime), true);
//     });

//     test('endWatchSession records end time and updates video stats', () async {
//       final testVideo = createTestVideo();
      
//       // Arrange
//       await videoRepository.createVideo(testVideo);
//       final session = await videoRepository.startWatchSession(testVideo.id, 'test-user-id');
//       await videoRepository.updateWatchSession(session.id, watchDuration: 100, lastPosition: 100);

//       // Act
//       await videoRepository.endWatchSession(session.id);

//       // Assert
//       final updatedSession = await videoRepository.getWatchSession(session.id);
//       expect(updatedSession, isNotNull);
//       expect(updatedSession!.endTime, isNotNull);
//       expect(updatedSession.watchDuration, 100);
//       expect(updatedSession.lastPosition, 100);
//     });

//     test('endWatchSession handles completed viewing correctly', () async {
//       final testVideo = createTestVideo();
      
//       // Arrange
//       await videoRepository.createVideo(testVideo);
//       final session = await videoRepository.startWatchSession(testVideo.id, 'test-user-id');
//       await videoRepository.updateWatchSession(session.id, watchDuration: 110, lastPosition: 110);

//       // Act
//       await videoRepository.endWatchSession(session.id);

//       // Assert
//       final updatedSession = await videoRepository.getWatchSession(session.id);
//       expect(updatedSession, isNotNull);
//       expect(updatedSession!.completedViewing, true);
//     });

//     test('endWatchSession updates last position correctly', () async {
//       final testVideo = createTestVideo();
      
//       // Arrange
//       await videoRepository.createVideo(testVideo);
//       final session = await videoRepository.startWatchSession(testVideo.id, 'test-user-id');
//       await videoRepository.updateWatchSession(session.id, watchDuration: 50, lastPosition: 60);

//       // Act
//       await videoRepository.endWatchSession(session.id);

//       // Assert
//       final updatedSession = await videoRepository.getWatchSession(session.id);
//       expect(updatedSession, isNotNull);
//       expect(updatedSession!.lastPosition, 60);
//     });

//     test('updateWatchSession tracks watch duration correctly', () async {
//       final testVideo = createTestVideo();
      
//       // Arrange
//       await videoRepository.createVideo(testVideo);
//       final session = await videoRepository.startWatchSession(testVideo.id, 'test-user-id');

//       // Act
//       await videoRepository.updateWatchSession(session.id, watchDuration: 30, lastPosition: 30);
//       await videoRepository.updateWatchSession(session.id, watchDuration: 60, lastPosition: 60);

//       // Assert
//       final updatedSession = await videoRepository.getWatchSession(session.id);
//       expect(updatedSession, isNotNull);
//       expect(updatedSession!.watchDuration, 60);
//       expect(updatedSession.lastPosition, 60);
//     });

//     test('updateWatchSession marks session as completed when >90% watched', () async {
//       final testVideo = createTestVideo();
      
//       // Arrange
//       await videoRepository.createVideo(testVideo);
//       final session = await videoRepository.startWatchSession(testVideo.id, 'test-user-id');

//       // Act
//       await videoRepository.updateWatchSession(session.id, watchDuration: 110, lastPosition: 110);

//       // Assert
//       final updatedSession = await videoRepository.getWatchSession(session.id);
//       expect(updatedSession, isNotNull);
//       expect(updatedSession!.watchDuration, 110);
//       expect(updatedSession.completedViewing, true);
//     });

//     test('updateWatchSession accumulates watch duration across updates', () async {
//       final testVideo = createTestVideo();
      
//       // Arrange
//       await videoRepository.createVideo(testVideo);
//       final session = await videoRepository.startWatchSession(testVideo.id, 'test-user-id');

//       // Act
//       await videoRepository.updateWatchSession(session.id, watchDuration: 30, lastPosition: 30);
//       await videoRepository.updateWatchSession(session.id, watchDuration: 60, lastPosition: 60);
//       await videoRepository.updateWatchSession(session.id, watchDuration: 90, lastPosition: 90);

//       // Assert
//       final updatedSession = await videoRepository.getWatchSession(session.id);
//       expect(updatedSession, isNotNull);
//       expect(updatedSession!.watchDuration, 90);
//       expect(updatedSession.lastPosition, 90);
//     });

//     test('endWatchSession updates total watch duration in video metadata', () async {
//       final testVideo = createTestVideo();
      
//       // Arrange
//       await videoRepository.createVideo(testVideo);
//       final session = await videoRepository.startWatchSession(testVideo.id, 'test-user-id');
//       await videoRepository.updateWatchSession(session.id, watchDuration: 100, lastPosition: 100);

//       // Act
//       final sessionDoc = await fakeFirestore
//           .collection('watch_sessions')
//           .doc(session.id)
//           .get();
      
//       // Assert
//       expect(sessionDoc.data()!['lastPosition'], 45);
//       expect(sessionDoc.data()!['watchDuration'], 30); // Duration unchanged by position updates
//     });

//     test('video metadata updates correctly with watch analytics', () async {
//       // Arrange
//       final testVideo = Video(
//         id: 'test-video-id',
//         userId: 'test-user-id',
//         title: 'Test Video',
//         description: 'Test Description',
//         duration: 100,
//         videoUrl: 'https://example.com/video.mp4',
//         thumbnailUrl: 'https://example.com/thumbnail.jpg',
//         uploadedAt: now,
//         lastModified: now,
//         author: {'id': 'test-user-id', 'name': 'Test Author'},
//         copyrightStatus: {'status': 'pending', 'owner': 'Test Author'},
//         validationMetadata: VideoValidationMetadata(
//           width: 1920,
//           height: 1080,
//           duration: 120.0,
//           codec: 'h264',
//           format: 'hls',
//           variants: [
//             VideoQualityVariant(
//               quality: '1080p',
//               bitrate: 5000000,
//               playlistUrl: 'https://example.com/hls/1080p.m3u8'
//             )
//           ]
//         ),
//       );
//       await videoRepository.createVideo(testVideo);

//       // Create multiple sessions with different watch patterns
//       final sessions = [
//         // Completed view
//         {
//           'duration': 95,
//           'completed': true,
//           'position': 95,
//         },
//         // Partial view
//         {
//           'duration': 45,
//           'completed': false,
//           'position': 45,
//         },
//         // Another completed view
//         {
//           'duration': 100,
//           'completed': true,
//           'position': 100,
//         },
//       ];

//       for (final sessionData in sessions) {
//         final session = await videoRepository.startWatchSession(
//           testVideo.id,
//           'test-viewer-id',
//         );
//         await videoRepository.updateWatchSession(
//           session.id,
//           duration: sessionData['duration'] as int,
//           completed: sessionData['completed'] as bool,
//           position: sessionData['position'] as int,
//         );
//         await videoRepository.endWatchSession(session.id, testVideo.id);
//       }

//       // Act
//       final videoDoc = await fakeFirestore
//           .collection('videos')
//           .doc(testVideo.id)
//           .get();
      
//       final data = videoDoc.data()!;

//       // Assert
//       expect(data['watchCount'], 2); // Only completed views count
//       expect(data['totalWatchDuration'], 240); // Sum of all watch durations
//       expect(data['lastWatchedAt'], isNotNull);
//       expect((data['lastWatchedAt'] as Timestamp).toDate().isAfter(now), true);
//     });

//     test('video analytics update atomically in batch operations', () async {
//       // Arrange
//       final testVideo = Video(
//         id: 'test-video-id',
//         userId: 'test-user-id',
//         title: 'Test Video',
//         description: 'Test Description',
//         duration: 100,
//         videoUrl: 'https://example.com/video.mp4',
//         thumbnailUrl: 'https://example.com/thumbnail.jpg',
//         uploadedAt: now,
//         lastModified: now,
//         author: {'id': 'test-user-id', 'name': 'Test Author'},
//         copyrightStatus: {'status': 'pending', 'owner': 'Test Author'},
//         validationMetadata: VideoValidationMetadata(
//           width: 1920,
//           height: 1080,
//           duration: 120.0,
//           codec: 'h264',
//           format: 'hls',
//           variants: [
//             VideoQualityVariant(
//               quality: '1080p',
//               bitrate: 5000000,
//               playlistUrl: 'https://example.com/hls/1080p.m3u8'
//             )
//           ]
//         ),
//       );
//       await videoRepository.createVideo(testVideo);

//       // Create multiple concurrent sessions
//       final sessions = await Future.wait([
//         videoRepository.startWatchSession(testVideo.id, 'user1'),
//         videoRepository.startWatchSession(testVideo.id, 'user2'),
//         videoRepository.startWatchSession(testVideo.id, 'user3'),
//       ]);

//       // Update all sessions concurrently
//       await Future.wait(sessions.map((session) => 
//         videoRepository.updateWatchSession(
//           session.id,
//           duration: 95,
//           completed: true,
//           position: 95,
//         )
//       ));

//       // End all sessions concurrently
//       await Future.wait(sessions.map((session) =>
//         videoRepository.endWatchSession(session.id, testVideo.id)
//       ));

//       // Act
//       final videoDoc = await fakeFirestore
//           .collection('videos')
//           .doc(testVideo.id)
//           .get();
      
//       final data = videoDoc.data()!;

//       // Assert
//       expect(data['watchCount'], 3); // All sessions were completed
//       expect(data['totalWatchDuration'], 285); // 95 * 3
//       expect(data['viewsCount'], 3); // Each session counts as a view
//     });

//     test('video analytics handle concurrent updates correctly', () async {
//       // Arrange
//       final testVideo = Video(
//         id: 'test-video-id',
//         userId: 'test-user-id',
//         title: 'Test Video',
//         description: 'Test Description',
//         duration: 100,
//         videoUrl: 'https://example.com/video.mp4',
//         thumbnailUrl: 'https://example.com/thumbnail.jpg',
//         uploadedAt: now,
//         lastModified: now,
//         author: {'id': 'test-user-id', 'name': 'Test Author'},
//         copyrightStatus: {'status': 'pending', 'owner': 'Test Author'},
//         validationMetadata: VideoValidationMetadata(
//           width: 1920,
//           height: 1080,
//           duration: 120.0,
//           codec: 'h264',
//           format: 'hls',
//           variants: [
//             VideoQualityVariant(
//               quality: '1080p',
//               bitrate: 5000000,
//               playlistUrl: 'https://example.com/hls/1080p.m3u8'
//             )
//           ]
//         ),
//       );
//       await videoRepository.createVideo(testVideo);

//       // Create and update multiple sessions with overlapping updates
//       final futures = <Future>[];
//       for (var i = 0; i < 5; i++) {
//         futures.addAll([
//           () async {
//             final session = await videoRepository.startWatchSession(testVideo.id, 'user$i');
//             await videoRepository.updateWatchSession(
//               session.id,
//               duration: 90,
//               completed: true,
//               position: 90,
//             );
//             await videoRepository.endWatchSession(session.id, testVideo.id);
//           }(),
//         ]);
//       }

//       // Act
//       await Future.wait(futures);

//       // Assert
//       final videoDoc = await fakeFirestore
//           .collection('videos')
//           .doc(testVideo.id)
//           .get();
      
//       final data = videoDoc.data()!;

//       expect(data['watchCount'], 5); // All sessions were completed
//       expect(data['totalWatchDuration'], 450); // 90 * 5
//       expect(data['viewsCount'], 5); // Each session counts as a view
//     });

//     test('handles multiple watch sessions for same video by same user', () async {
//       // Arrange
//       final testVideo = Video(
//         id: 'test-video-id',
//         userId: 'test-user-id',
//         title: 'Test Video',
//         description: 'Test Description',
//         duration: 100,
//         videoUrl: 'https://example.com/video.mp4',
//         thumbnailUrl: 'https://example.com/thumbnail.jpg',
//         uploadedAt: now,
//         lastModified: now,
//         author: {'id': 'test-user-id', 'name': 'Test Author'},
//         copyrightStatus: {'status': 'pending', 'owner': 'Test Author'},
//         validationMetadata: VideoValidationMetadata(
//           width: 1920,
//           height: 1080,
//           duration: 120.0,
//           codec: 'h264',
//           format: 'hls',
//           variants: [
//             VideoQualityVariant(
//               quality: '1080p',
//               bitrate: 5000000,
//               playlistUrl: 'https://example.com/hls/1080p.m3u8'
//             )
//           ]
//         ),
//       );
//       await videoRepository.createVideo(testVideo);

//       // Create multiple watch sessions
//       final watchSessions = <WatchSession>[];
//       for (var i = 0; i < 3; i++) {
//         final session = await videoRepository.startWatchSession(
//           testVideo.id,
//           'test-viewer-id',
//         );
//         await videoRepository.updateWatchSession(
//           session.id,
//           duration: 95,
//           completed: true,
//           position: 95,
//         );
//         await videoRepository.endWatchSession(session.id, testVideo.id);
//         watchSessions.add(session);
//         await Future.delayed(const Duration(milliseconds: 100)); // Ensure different timestamps
//       }

//       // Act
//       final history = await videoRepository.getWatchHistory('test-viewer-id').first;
//       final videoDoc = await fakeFirestore
//           .collection('videos')
//           .doc(testVideo.id)
//           .get();

//       // Assert
//       expect(history.docs.length, 3); // All sessions are recorded
//       expect(videoDoc.data()!['watchCount'], 3); // Each completed view counts
//       expect(videoDoc.data()!['totalWatchDuration'], 285); // 95 * 3
//     });

//     test('handles interrupted watch sessions correctly', () async {
//       // Arrange
//       final testVideo = Video(
//         id: 'test-video-id',
//         userId: 'test-user-id',
//         title: 'Test Video',
//         description: 'Test Description',
//         duration: 100,
//         videoUrl: 'https://example.com/video.mp4',
//         thumbnailUrl: 'https://example.com/thumbnail.jpg',
//         uploadedAt: now,
//         lastModified: now,
//         author: {'id': 'test-user-id', 'name': 'Test Author'},
//         copyrightStatus: {'status': 'pending', 'owner': 'Test Author'},
//         validationMetadata: VideoValidationMetadata(
//           width: 1920,
//           height: 1080,
//           duration: 120.0,
//           codec: 'h264',
//           format: 'hls',
//           variants: [
//             VideoQualityVariant(
//               quality: '1080p',
//               bitrate: 5000000,
//               playlistUrl: 'https://example.com/hls/1080p.m3u8'
//             )
//           ]
//         ),
//       );
//       await videoRepository.createVideo(testVideo);

//       // First session - interrupted at 30%
//       final session1 = await videoRepository.startWatchSession(
//         testVideo.id,
//         'test-viewer-id',
//       );
//       await videoRepository.updateWatchSession(
//         session1.id,
//         duration: 30,
//         position: 30,
//       );
//       await videoRepository.endWatchSession(session1.id, testVideo.id);

//       // Second session - complete the video
//       final session2 = await videoRepository.startWatchSession(
//         testVideo.id,
//         'test-viewer-id',
//       );
//       await videoRepository.updateWatchSession(
//         session2.id,
//         duration: 95,
//         completed: true,
//         position: 95,
//       );
//       await videoRepository.endWatchSession(session2.id, testVideo.id);

//       // Act
//       final history = await videoRepository.getWatchHistory('test-viewer-id').first;
//       final videoDoc = await fakeFirestore
//           .collection('videos')
//           .doc(testVideo.id)
//           .get();

//       // Assert
//       expect(history.docs.length, 2); // Both sessions recorded
//       expect(videoDoc.data()!['watchCount'], 1); // Only completed view counts
//       expect(videoDoc.data()!['totalWatchDuration'], 125); // 30 + 95
//     });

//     test('handles resuming from previous position', () async {
//       // Arrange
//       final testVideo = Video(
//         id: 'test-video-id',
//         userId: 'test-user-id',
//         title: 'Test Video',
//         description: 'Test Description',
//         duration: 100,
//         videoUrl: 'https://example.com/video.mp4',
//         thumbnailUrl: 'https://example.com/thumbnail.jpg',
//         uploadedAt: now,
//         lastModified: now,
//         author: {'id': 'test-user-id', 'name': 'Test Author'},
//         copyrightStatus: {'status': 'pending', 'owner': 'Test Author'},
//         validationMetadata: VideoValidationMetadata(
//           width: 1920,
//           height: 1080,
//           duration: 120.0,
//           codec: 'h264',
//           format: 'hls',
//           variants: [
//             VideoQualityVariant(
//               quality: '1080p',
//               bitrate: 5000000,
//               playlistUrl: 'https://example.com/hls/1080p.m3u8'
//             )
//           ]
//         ),
//       );
//       await videoRepository.createVideo(testVideo);

//       // First session - watch halfway
//       final session1 = await videoRepository.startWatchSession(
//         testVideo.id,
//         'test-viewer-id',
//       );
//       await videoRepository.updateWatchSession(
//         session1.id,
//         duration: 50,
//         position: 50,
//       );
//       await videoRepository.endWatchSession(session1.id, testVideo.id);

//       // Get last position
//       final lastSession = await videoRepository.getLastWatchSession(
//         testVideo.id,
//         'test-viewer-id',
//       );

//       // Second session - resume and complete
//       final session2 = await videoRepository.startWatchSession(
//         testVideo.id,
//         'test-viewer-id',
//       );
//       await videoRepository.updateWatchSession(
//         session2.id,
//         duration: 50, // Watch remaining half
//         completed: true,
//         position: 100, // End at full duration
//       );
//       await videoRepository.endWatchSession(session2.id, testVideo.id);

//       // Assert
//       expect(lastSession?.lastPosition, 50); // First session position saved
      
//       final videoDoc = await fakeFirestore
//           .collection('videos')
//           .doc(testVideo.id)
//           .get();
      
//       expect(videoDoc.data()!['watchCount'], 1); // Counts as one complete view
//       expect(videoDoc.data()!['totalWatchDuration'], 100); // Total duration watched
//     });

//     test('tracks video completion based on watch percentage', () async {
//       // Arrange
//       final testVideo = Video(
//         id: 'test-video-id',
//         userId: 'test-user-id',
//         title: 'Test Video',
//         description: 'Test Description',
//         duration: 100, // Use 100 for easy percentage calculation
//         videoUrl: 'https://example.com/video.mp4',
//         thumbnailUrl: 'https://example.com/thumbnail.jpg',
//         uploadedAt: now,
//         lastModified: now,
//         author: {'id': 'test-user-id', 'name': 'Test Author'},
//         copyrightStatus: {'status': 'pending', 'owner': 'Test Author'},
//         validationMetadata: VideoValidationMetadata(
//           width: 1920,
//           height: 1080,
//           duration: 120.0,
//           codec: 'h264',
//           format: 'hls',
//           variants: [
//             VideoQualityVariant(
//               quality: '1080p',
//               bitrate: 5000000,
//               playlistUrl: 'https://example.com/hls/1080p.m3u8'
//             )
//           ]
//         ),
//       );
//       await videoRepository.createVideo(testVideo);

//       // Create sessions with different watch percentages
//       final watchPercentages = [85, 90, 95];
//       final sessions = <WatchSession>[];

//       for (final percentage in watchPercentages) {
//         final session = await videoRepository.startWatchSession(
//           testVideo.id,
//           'test-viewer-id',
//         );
//         await videoRepository.updateWatchSession(
//           session.id,
//           duration: percentage,
//           position: percentage,
//           completed: percentage >= 90,
//         );
//         await videoRepository.endWatchSession(session.id, testVideo.id);
//         sessions.add(session);
//       }

//       // Act
//       final sessionDocs = await Future.wait(
//         sessions.map((s) => fakeFirestore
//             .collection('watch_sessions')
//             .doc(s.id)
//             .get()
//         )
//       );

//       // Assert
//       expect(sessionDocs[0].data()!['completedViewing'], false); // 85%
//       expect(sessionDocs[1].data()!['completedViewing'], true); // 90%
//       expect(sessionDocs[2].data()!['completedViewing'], true); // 95%

//       final videoDoc = await fakeFirestore
//           .collection('videos')
//           .doc(testVideo.id)
//           .get();
      
//       expect(videoDoc.data()!['watchCount'], 2); // Only 90%+ views count
//     });

//     test('completion status affects watch count correctly', () async {
//       // Arrange
//       final testVideo = Video(
//         id: 'test-video-id',
//         userId: 'test-user-id',
//         title: 'Test Video',
//         description: 'Test Description',
//         duration: 100,
//         videoUrl: 'https://example.com/video.mp4',
//         thumbnailUrl: 'https://example.com/thumbnail.jpg',
//         uploadedAt: now,
//         lastModified: now,
//         author: {'id': 'test-user-id', 'name': 'Test Author'},
//         copyrightStatus: {'status': 'pending', 'owner': 'Test Author'},
//         validationMetadata: VideoValidationMetadata(
//           width: 1920,
//           height: 1080,
//           duration: 120.0,
//           codec: 'h264',
//           format: 'hls',
//           variants: [
//             VideoQualityVariant(
//               quality: '1080p',
//               bitrate: 5000000,
//               playlistUrl: 'https://example.com/hls/1080p.m3u8'
//             )
//           ]
//         ),
//       );
//       await videoRepository.createVideo(testVideo);

//       // Create various watch scenarios
//       final watchScenarios = [
//         {'duration': 95, 'completed': true}, // Completed
//         {'duration': 45, 'completed': false}, // Not completed
//         {'duration': 91, 'completed': true}, // Completed
//         {'duration': 89, 'completed': false}, // Not completed
//         {'duration': 100, 'completed': true}, // Completed
//       ];

//       for (final scenario in watchScenarios) {
//         final session = await videoRepository.startWatchSession(
//           testVideo.id,
//           'test-viewer-id',
//         );
//         await videoRepository.updateWatchSession(
//           session.id,
//           duration: scenario['duration'] as int,
//           completed: scenario['completed'] as bool,
//         );
//         await videoRepository.endWatchSession(session.id, testVideo.id);
//       }

//       // Act
//       final videoDoc = await fakeFirestore
//           .collection('videos')
//           .doc(testVideo.id)
//           .get();
      
//       // Assert
//       expect(videoDoc.data()!['watchCount'], 3); // Only completed views count
//       expect(videoDoc.data()!['totalWatchDuration'], 420); // Sum of all durations
//     });

//     test('completion status persists after session ends', () async {
//       // Arrange
//       final testVideo = Video(
//         id: 'test-video-id',
//         userId: 'test-user-id',
//         title: 'Test Video',
//         description: 'Test Description',
//         duration: 100,
//         videoUrl: 'https://example.com/video.mp4',
//         thumbnailUrl: 'https://example.com/thumbnail.jpg',
//         uploadedAt: now,
//         lastModified: now,
//         author: {'id': 'test-user-id', 'name': 'Test Author'},
//         copyrightStatus: {'status': 'pending', 'owner': 'Test Author'},
//         validationMetadata: VideoValidationMetadata(
//           width: 1920,
//           height: 1080,
//           duration: 120.0,
//           codec: 'h264',
//           format: 'hls',
//           variants: [
//             VideoQualityVariant(
//               quality: '1080p',
//               bitrate: 5000000,
//               playlistUrl: 'https://example.com/hls/1080p.m3u8'
//             )
//           ]
//         ),
//       );
//       await videoRepository.createVideo(testVideo);

//       // Create a completed session
//       final session = await videoRepository.startWatchSession(
//         testVideo.id,
//         'test-viewer-id',
//       );
//       await videoRepository.updateWatchSession(
//         session.id,
//         duration: 95,
//         completed: true,
//       );
//       await videoRepository.endWatchSession(session.id, testVideo.id);

//       // Act
//       final sessionDoc = await fakeFirestore
//           .collection('watch_sessions')
//           .doc(session.id)
//           .get();
      
//       final lastSession = await videoRepository.getLastWatchSession(
//         testVideo.id,
//         'test-viewer-id',
//       );

//       // Assert
//       expect(sessionDoc.data()!['completedViewing'], true);
//       expect(lastSession?.completedViewing, true);
//     });
//   });
// } 