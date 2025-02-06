import 'dart:io';
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

// Generate mock classes
@GenerateMocks([
  FirebaseStorage,
  FirebaseAuth,
  Reference,
  User,
  UploadTask,
  TaskSnapshot,
  VideoRepository,
  VideoValidationService,
])
import 'video_service_test.mocks.dart';

void main() {
  late MockFirebaseStorage mockStorage;
  late MockFirebaseAuth mockAuth;
  late MockReference mockStorageRef;
  late MockUser mockUser;
  late MockUploadTask mockUploadTask;
  late MockTaskSnapshot mockSnapshot;
  late MockVideoRepository mockVideoRepository;
  late MockVideoValidationService mockValidationService;
  late VideoService videoService;
  late File mockVideoFile;

  setUp(() {
    mockStorage = MockFirebaseStorage();
    mockAuth = MockFirebaseAuth();
    mockStorageRef = MockReference();
    mockUser = MockUser();
    mockUploadTask = MockUploadTask();
    mockSnapshot = MockTaskSnapshot();
    mockVideoRepository = MockVideoRepository();
    mockValidationService = MockVideoValidationService();
    
    videoService = VideoService(
      storage: mockStorage,
      auth: mockAuth,
      videoRepository: mockVideoRepository,
      validationService: mockValidationService,
    );

    // Create a mock video file
    mockVideoFile = File('test_video.mp4');

    // Set up common mock behaviors
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test_user_id');
    when(mockUser.displayName).thenReturn('Test User');
    when(mockUser.photoURL).thenReturn('https://example.com/photo.jpg');
    when(mockStorage.ref()).thenReturn(mockStorageRef);
    when(mockStorageRef.child(any)).thenReturn(mockStorageRef);
    when(mockSnapshot.ref).thenReturn(mockStorageRef);
  });

  group('uploadVideo', () {
    test('successfully uploads valid video', () async {
      // Arrange
      const expectedUrl = 'https://example.com/video.mp4';
      final validationResult = VideoValidationResult(
        isValid: true,
        metadata: VideoValidationMetadata(
          duration: 120,
          width: 1920,
          height: 1080,
          codec: 'h264',
          format: 'mp4',
          bitrate: 2500000,
        ),
      );
      
      when(mockVideoFile.length()).thenAnswer((_) async => 1024 * 1024); // 1MB
      when(mockValidationService.validateVideo(any))
          .thenAnswer((_) async => validationResult);
      when(mockStorageRef.putFile(any, any)).thenReturn(mockUploadTask);
      when(mockUploadTask.snapshotEvents)
          .thenAnswer((_) => Stream.fromIterable([mockSnapshot]));
      when(mockUploadTask).thenAnswer((_) async => mockSnapshot);
      when(mockStorageRef.getDownloadURL()).thenAnswer((_) async => expectedUrl);

      // Act
      final video = await videoService.uploadVideo(
        videoFile: mockVideoFile,
        title: 'Test Video',
        description: 'Test Description',
      );

      // Assert
      expect(video.videoUrl, equals(expectedUrl));
      expect(video.duration, equals(120));
      expect(video.processingStatus, equals(VideoProcessingStatus.pending));
      verify(mockVideoRepository.createVideo(any)).called(1);
      verify(mockVideoRepository.updateVideo(any, any)).called(1);
    });

    test('handles validation failure', () async {
      // Arrange
      when(mockVideoFile.length()).thenAnswer((_) async => 1024 * 1024);
      when(mockValidationService.validateVideo(any))
          .thenAnswer((_) async => VideoValidationResult(
                isValid: false,
                errors: ['Invalid format'],
              ));

      // Act & Assert
      expect(
        () => videoService.uploadVideo(
          videoFile: mockVideoFile,
          title: 'Test Video',
          description: 'Test Description',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Video validation failed'),
        )),
      );

      verify(mockVideoRepository.createVideo(any)).called(1);
      verify(mockVideoRepository.updateVideo(any, any)).called(1);
    });

    test('handles upload failure', () async {
      // Arrange
      when(mockVideoFile.length()).thenAnswer((_) async => 1024 * 1024);
      when(mockValidationService.validateVideo(any))
          .thenAnswer((_) async => VideoValidationResult(isValid: true));
      when(mockStorageRef.putFile(any, any))
          .thenThrow(Exception('Upload failed'));

      // Act & Assert
      expect(
        () => videoService.uploadVideo(
          videoFile: mockVideoFile,
          title: 'Test Video',
          description: 'Test Description',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to upload video'),
        )),
      );

      verify(mockVideoRepository.createVideo(any)).called(1);
      verify(mockVideoRepository.updateVideo(any, any)).called(1);
    });

    test('reports upload progress correctly', () async {
      // Arrange
      final progressValues = <double>[];
      when(mockVideoFile.length()).thenAnswer((_) async => 1024 * 1024);
      when(mockValidationService.validateVideo(any))
          .thenAnswer((_) async => VideoValidationResult(isValid: true));
      when(mockStorageRef.putFile(any, any)).thenReturn(mockUploadTask);
      
      // Simulate upload progress events
      when(mockUploadTask.snapshotEvents).thenAnswer((_) => Stream.fromIterable([
            MockTaskSnapshot()
              ..stub((s) => s.bytesTransferred).toReturn(512 * 1024)
              ..stub((s) => s.totalBytes).toReturn(1024 * 1024),
            MockTaskSnapshot()
              ..stub((s) => s.bytesTransferred).toReturn(1024 * 1024)
              ..stub((s) => s.totalBytes).toReturn(1024 * 1024),
          ]));
      
      when(mockUploadTask).thenAnswer((_) async => mockSnapshot);
      when(mockStorageRef.getDownloadURL())
          .thenAnswer((_) async => 'https://example.com/video.mp4');

      // Act
      await videoService.uploadVideo(
        videoFile: mockVideoFile,
        title: 'Test Video',
        description: 'Test Description',
        onProgress: (progress) => progressValues.add(progress),
      );

      // Assert
      expect(progressValues, [0.5, 1.0]); // Should receive 50% and 100% progress
    });
  });
} 