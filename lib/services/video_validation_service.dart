import 'dart:io';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter/media_information.dart';
import 'package:ffmpeg_kit_flutter/stream_information.dart';
import '../models/video_model.dart';

class VideoValidationResult {
  final bool isValid;
  final List<String> errors;
  final VideoValidationMetadata? metadata;

  VideoValidationResult({
    required this.isValid,
    this.errors = const [],
    this.metadata,
  });
}

class VideoValidationService {
  static const int _maxDurationSeconds = 1800; // 30 minutes
  static const int _maxWidth = 3840; // 4K
  static const int _maxHeight = 2160; // 4K
  static const List<String> _supportedFormats = ['mp4', 'mov', 'webm', 'avi'];
  static const List<String> _supportedCodecs = ['h264'];

  Future<VideoValidationResult> validateVideo(String videoPath) async {
    try {
      // Get media information using FFprobe
      final mediaInformation = await _getMediaInformation(videoPath);
      if (mediaInformation == null) {
        return VideoValidationResult(
          isValid: false,
          errors: ['Failed to extract video information'],
        );
      }

      final errors = <String>[];
      final metadata = await _extractMetadata(mediaInformation);

      // Validate format
      if (!_supportedFormats.contains(metadata.format?.toLowerCase())) {
        errors.add('Unsupported format: ${metadata.format}. Supported formats: ${_supportedFormats.join(", ")}');
      }

      // Validate codec
      if (!_supportedCodecs.contains(metadata.codec?.toLowerCase())) {
        errors.add('Unsupported codec: ${metadata.codec}. Supported codecs: ${_supportedCodecs.join(", ")}');
      }

      // Validate duration
      if ((metadata.duration ?? 0) > _maxDurationSeconds) {
        errors.add('Video duration exceeds maximum limit of 30 minutes');
      }

      // Validate resolution
      if ((metadata.width ?? 0) > _maxWidth || (metadata.height ?? 0) > _maxHeight) {
        errors.add('Video resolution exceeds maximum limit of 4K (3840x2160)');
      }

      // Check file integrity
      if (!await _checkFileIntegrity(videoPath)) {
        errors.add('Video file appears to be corrupted');
      }

      return VideoValidationResult(
        isValid: errors.isEmpty,
        errors: errors,
        metadata: metadata,
      );
    } catch (e) {
      return VideoValidationResult(
        isValid: false,
        errors: ['Failed to validate video: $e'],
      );
    }
  }

  Future<MediaInformation?> _getMediaInformation(String videoPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(videoPath);
      return session.getMediaInformation();
    } catch (e) {
      return null;
    }
  }

  Future<VideoValidationMetadata> _extractMetadata(MediaInformation mediaInfo) async {
    final format = mediaInfo.getFormat();
    final streams = mediaInfo.getStreams();
    
    // Find the video stream
    final videoStream = streams.firstWhere(
      (stream) => stream.getType()?.toLowerCase() == 'video',
      orElse: () => streams.first,
    );

    return VideoValidationMetadata(
      width: int.tryParse(videoStream.getWidth() ?? ''),
      height: int.tryParse(videoStream.getHeight() ?? ''),
      duration: double.tryParse(format.getDuration() ?? ''),
      codec: videoStream.getCodec(),
      format: format.getFormat(),
      bitrate: int.tryParse(format.getBitrate() ?? ''),
    );
  }

  Future<bool> _checkFileIntegrity(String videoPath) async {
    try {
      // Use FFmpeg to check file integrity by attempting to read the entire file
      final session = await FFmpegKit.execute(
        '-v error -i "$videoPath" -f null -'
      );
      
      // If return code is 0, the file is valid
      return session.getReturnCode()?.getValue() == 0;
    } catch (e) {
      return false;
    }
  }
} 