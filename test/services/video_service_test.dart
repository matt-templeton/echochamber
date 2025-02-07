import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:echochamber/services/video_service.dart';
import 'package:echochamber/services/video_validation_service.dart';
import 'package:echochamber/repositories/video_repository.dart';
import 'package:echochamber/models/video_model.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as auth_mocks;

import 'video_service_test.mocks.dart';

@GenerateMocks([
  FirebaseStorage,
  VideoRepository,
  VideoValidationService,
  Reference,
  UploadTask,
  TaskSnapshot,
])
void main() {
  late MockFirebaseStorage mockStorage;
  late auth_mocks.MockFirebaseAuth mockAuth;
  late auth_mocks.MockUser mockUser;
  late MockVideoRepository mockVideoRepository;
  late MockVideoValidationService mockValidationService;
  late VideoService videoService;
  late DateTime now;
  late File testVideoFile;
  late MockReference mockStorageRef;
  late MockUploadTask mockUploadTask;
  late MockTaskSnapshot mockTaskSnapshot;
  late StreamController<TaskSnapshot> uploadStreamController;
  late StreamController<TaskSnapshot> snapshotStreamController;

  setUp(() {
    // Create a mock user
    mockUser = auth_mocks.MockUser(
      uid: 'test-user-id',
      email: 'test@example.com',
      displayName: 'Test User',
      photoURL: 'https://example.com/photo.jpg'
    );
    
    // Initialize mock auth with signed in user
    mockAuth = auth_mocks.MockFirebaseAuth(signedIn: true, mockUser: mockUser);
    
    mockStorage = MockFirebaseStorage();
    mockVideoRepository = MockVideoRepository();
    mockValidationService = MockVideoValidationService();
    mockStorageRef = MockReference();
    mockUploadTask = MockUploadTask();
    mockTaskSnapshot = MockTaskSnapshot();
    uploadStreamController = StreamController<TaskSnapshot>.broadcast();
    snapshotStreamController = StreamController<TaskSnapshot>.broadcast();
    now = DateTime.now();
    testVideoFile = File(path.join('test', 'fixtures', 'test.mp4'));

    // Setup storage mocks
    when(mockStorage.ref()).thenAnswer((_) => mockStorageRef);
    when(mockStorageRef.child(any)).thenAnswer((_) => mockStorageRef);
    when(mockStorageRef.putFile(any, any)).thenAnswer((_) => mockUploadTask);
    when(mockTaskSnapshot.ref).thenAnswer((_) => mockStorageRef);
    when(mockStorageRef.getDownloadURL())
        .thenAnswer((_) => Future.value('https://example.com/video.mp4'));
    when(mockTaskSnapshot.bytesTransferred).thenAnswer((_) => 50);
    when(mockTaskSnapshot.totalBytes).thenAnswer((_) => 100);
    when(mockUploadTask.snapshot).thenAnswer((_) => mockTaskSnapshot);

    // Setup upload task mocks with coordinated streams
    when(mockUploadTask.snapshotEvents).thenAnswer((_) => snapshotStreamController.stream);
    when(mockUploadTask.asStream()).thenAnswer((_) => uploadStreamController.stream);

    // Setup validation result
    final validationResult = VideoValidationResult(
      isValid: true,
      metadata: VideoValidationMetadata(
        width: 1920,
        height: 1080,
        duration: 120.0,
        codec: 'h264',
        format: 'mp4',
        bitrate: 5000000,
      ),
    );
    when(mockValidationService.validateVideo(any))
        .thenAnswer((_) => Future.value(validationResult));

    // Setup video repository mocks
    when(mockVideoRepository.createVideo(any))
        .thenAnswer((_) => Future.value());
    when(mockVideoRepository.updateVideo(any, any))
        .thenAnswer((_) => Future.value());

    videoService = VideoService(
      storage: mockStorage,
      auth: mockAuth,
      videoRepository: mockVideoRepository,
      validationService: mockValidationService,
    );
  });

  tearDown(() {
    uploadStreamController.close();
    snapshotStreamController.close();
  });

  group('VideoService - Authentication Checks', () {
    test('uploadVideo should throw when user is not authenticated', () async {
      // Arrange - Create a new auth instance with no signed in user
      mockAuth = auth_mocks.MockFirebaseAuth(signedIn: false);
      videoService = VideoService(
        storage: mockStorage,
        auth: mockAuth,
        videoRepository: mockVideoRepository,
        validationService: mockValidationService,
      );

      // Act & Assert
      expect(
        () => videoService.uploadVideo(
          videoFile: File('dummy.mp4'),
          title: 'Test Video',
          description: 'Test Description',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('User must be authenticated'),
        )),
      );

      // Verify no interactions with dependencies
      verifyNever(mockVideoRepository.createVideo(any));
      verifyNever(mockStorage.ref());
      verifyNever(mockValidationService.validateVideo(any));
    });
  });

  group('VideoService - Upload Process', () {
    test('uploadVideo should successfully upload and process video', () async {
      // Act
      final uploadFuture = videoService.uploadVideo(
        videoFile: testVideoFile,
        title: 'Test Video',
        description: 'Test Description',
        tags: ['test'],
        genres: ['music'],
      );

      // Simulate upload completion
      uploadStreamController.add(mockTaskSnapshot);
      await uploadStreamController.close();

      final video = await uploadFuture;

      // Assert
      // Verify validation was performed
      verify(mockValidationService.validateVideo(testVideoFile.path)).called(1);

      // Verify initial video document was created
      verify(mockVideoRepository.createVideo(any)).called(1);

      // Verify storage operations
      verify(mockStorage.ref()).called(1);
      verify(mockStorageRef.child(any)).called(1);
      verify(mockStorageRef.putFile(testVideoFile, any)).called(1);
      verify(mockStorageRef.getDownloadURL()).called(1);

      // Verify video document was updated with final data
      verify(mockVideoRepository.updateVideo(any, any)).called(1);

      // Verify returned video object
      expect(video.title, 'Test Video');
      expect(video.description, 'Test Description');
      expect(video.videoUrl, 'https://example.com/video.mp4');
      expect(video.tags, ['test']);
      expect(video.genres, ['music']);
      expect(video.validationMetadata?.width, 1920);
      expect(video.validationMetadata?.height, 1080);
      expect(video.validationMetadata?.duration, 120.0);
      expect(video.processingStatus, VideoProcessingStatus.pending);
    });

    test('uploadVideo should handle validation failure correctly', () async {
      // Arrange
      when(mockValidationService.validateVideo(any)).thenAnswer((_) => Future.value(VideoValidationResult(
        isValid: false,
        errors: ['Invalid format', 'Resolution too high'],
      )));

      // Act & Assert
      await expectLater(
        videoService.uploadVideo(
          videoFile: testVideoFile,
          title: 'Test Video',
          description: 'Test Description',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Video validation failed: Invalid format, Resolution too high'),
        )),
      );

      // Verify validation error was recorded
      verify(mockVideoRepository.updateVideo(any, argThat(
        predicate<Map<String, dynamic>>((map) =>
          map['processingStatus'] == VideoProcessingStatus.failed.toString().split('.').last &&
          map['processingError'] == VideoProcessingError.invalid_format.toString().split('.').last &&
          (map['validationErrors'] as List).contains('Invalid format')
        )
      ))).called(1);

      // Verify no storage operations were performed
      verifyNever(mockStorage.ref());
      verifyNever(mockStorageRef.putFile(any, any));
    });

    // test('uploadVideo should track upload progress correctly', () async {
    //   // Arrange
    //   final progressUpdates = <double>[];
    //   final progressCompleter = Completer<void>();

    //   // Act
    //   final uploadFuture = videoService.uploadVideo(
    //     videoFile: testVideoFile,
    //     title: 'Test Video',
    //     description: 'Test Description',
    //     onProgress: (progress) {
    //       progressUpdates.add(progress);
    //       if (!progressCompleter.isCompleted) {
    //         progressCompleter.complete();
    //       }
    //     },
    //   );

    //   // Simulate upload progress via snapshot events
    //   snapshotStreamController.add(mockTaskSnapshot);
      
    //   // Wait for progress callback to be processed
    //   await progressCompleter.future;
      
    //   // Complete the upload
    //   uploadStreamController.add(mockTaskSnapshot);
    //   await uploadStreamController.close();
    //   await snapshotStreamController.close();
    //   await uploadFuture;

    //   // Assert
    //   expect(progressUpdates, isNotEmpty);
    //   expect(progressUpdates.first, 0.5); // 50/100 = 0.5
    // });
  });
} 