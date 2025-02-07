import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_functions/firebase_functions.dart';
import 'package:path/path.dart' as path;
import '../repositories/video_repository.dart';
import '../models/video_model.dart';
import 'video_validation_service.dart';

class VideoService {
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final VideoRepository _videoRepository;
  final FirebaseFunctions _functions;

  VideoService({
    FirebaseStorage? storage,
    FirebaseAuth? auth,
    VideoRepository? videoRepository,
    FirebaseFunctions? functions,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _videoRepository = videoRepository ?? VideoRepository(),
        _functions = functions ?? FirebaseFunctions.instance;

  Future<Video> uploadVideo({
    required File videoFile,
    required String title,
    required String description,
    List<String> tags = const [],
    List<String> genres = const [],
    void Function(double)? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to upload videos');
    }

    // Validate file size (max 500MB as per security rules)
    final fileSize = await videoFile.length();
    if (fileSize > 500 * 1024 * 1024) {
      throw Exception('Video file size exceeds 500MB limit');
    }

    // Generate a unique video ID
    final videoId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Create initial video document with pending status
    final video = Video(
      id: videoId,
      userId: user.uid,
      title: title,
      description: description,
      videoUrl: '', // Will be updated after upload
      thumbnailUrl: '', // Will be updated after processing
      duration: 0, // Will be updated after validation
      uploadedAt: DateTime.now(),
      lastModified: DateTime.now(),
      tags: tags,
      genres: genres,
      author: {
        'id': user.uid,
        'name': user.displayName ?? 'Anonymous',
        'profilePictureUrl': user.photoURL,
      },
      processingStatus: VideoProcessingStatus.validating,
      copyrightStatus: {
        'status': 'pending',
        'owner': user.displayName ?? 'Anonymous',
        'license': 'Standard',
      },
    );

    // Save initial video document
    await _videoRepository.createVideo(video);

    try {
      // Create the storage path following the structure from documentation
      final videoPath = 'videos/${user.uid}/$videoId/openshot/original.mp4';
      final storageRef = _storage.ref().child(videoPath);

      // Start the upload task
      final UploadTask uploadTask = storageRef.putFile(
        videoFile,
        SettableMetadata(
          contentType: 'video/${path.extension(videoFile.path).replaceAll('.', '')}',
          customMetadata: {
            'userId': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
            'originalFileName': path.basename(videoFile.path),
          },
        ),
      );

      // Listen to upload progress if callback provided
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      // Wait for the upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Call the Cloud Function to validate and prepare video
      try {
        final result = await _functions.httpsCallable('validate_and_prepare_video').call({
          'videoId': videoId,
          'userId': user.uid,
          'title': title,
          'description': description,
        });

        // Update video document with validation results
        final validationData = result.data;
        final updatedVideo = video.copyWith(
          videoUrl: downloadUrl,
          processingStatus: VideoProcessingStatus.pending,
          validationMetadata: VideoValidationMetadata(
            width: validationData['validationMetadata']['width'],
            height: validationData['validationMetadata']['height'],
            duration: validationData['validationMetadata']['duration'],
            codec: validationData['validationMetadata']['codec'],
            format: validationData['validationMetadata']['format'],
            bitrate: validationData['validationMetadata']['bitrate'],
          ),
        );

        await _videoRepository.updateVideo(videoId, updatedVideo.toFirestore());
        return updatedVideo;

      } catch (e) {
        // Cloud Function will handle updating the error status in Firestore
        throw Exception('Failed to validate video: $e');
      }

    } catch (e) {
      // Update video document with error status
      await _videoRepository.updateVideo(videoId, {
        'processingStatus': VideoProcessingStatus.failed.toString().split('.').last,
        'processingError': VideoProcessingError.processing_failed.toString().split('.').last,
        'validationErrors': ['Failed to upload video: $e'],
      });
      throw Exception('Failed to upload video: $e');
    }
  }
} 