import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/foundation.dart';

enum VideoProcessingStatus {
  pending,
  validating,
  transcoding,
  generating_thumbnails,
  creating_hls,
  completed,
  failed
}

enum VideoProcessingError {
  none,
  invalid_format,
  duration_exceeded,
  resolution_exceeded,
  processing_failed,
  storage_error
}

class VideoQualityVariant {
  final String quality;
  final int bitrate;
  final String playlistUrl;

  VideoQualityVariant({
    required this.quality,
    required this.bitrate,
    required String playlistUrl,
  }) : playlistUrl = playlistUrl.startsWith('http') ? 
          playlistUrl : 
          playlistUrl.startsWith('gs://') ?
            playlistUrl.replaceFirst(
              'gs://', 
              'https://firebasestorage.googleapis.com/v0/b/'
            ) + '?alt=media' :
            playlistUrl;

  factory VideoQualityVariant.fromMap(Map<String, dynamic> map) {
    // Handle missing or null values
    final quality = map['quality']?.toString() ?? 'auto';
    final bitrate = (map['bitrate'] as num?)?.toInt() ?? 0;
    final playlistUrl = map['playlistUrl']?.toString();
    
    if (playlistUrl == null) {
      throw FormatException('Missing playlistUrl in variant data');
    }
    
    // Handle different URL formats
    String transformedUrl = playlistUrl;
    if (playlistUrl.startsWith('gs://')) {
      // Convert gs:// URL to HTTPS
      transformedUrl = playlistUrl
        .replaceFirst('gs://', 'https://firebasestorage.googleapis.com/v0/b/')
        + '?alt=media';
    } else if (!playlistUrl.startsWith('http')) {
      // Handle relative paths
      transformedUrl = 'https://firebasestorage.googleapis.com/v0/b/echo-chamber-8fb5f.appspot.com/o/$playlistUrl?alt=media';
    }
    
    return VideoQualityVariant(
      quality: quality,
      bitrate: bitrate,
      playlistUrl: transformedUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'quality': quality,
      'bitrate': bitrate,
      'playlistUrl': playlistUrl,
    };
  }
}

class VideoValidationMetadata {
  final int? width;
  final int? height;
  final double? duration;
  final String? codec;
  final String? format;
  final List<VideoQualityVariant>? variants;

  VideoValidationMetadata({
    this.width,
    this.height,
    this.duration,
    this.codec,
    this.format,
    this.variants,
  });

  factory VideoValidationMetadata.fromMap(Map<String, dynamic> map) {
    // Handle missing or null values
    final width = (map['width'] as num?)?.toInt();
    final height = (map['height'] as num?)?.toInt();
    final duration = map['duration'] != null ? (map['duration'] as num).toDouble() : null;
    final codec = map['codec']?.toString();
    final format = map['format']?.toString();
    
    List<VideoQualityVariant>? variants;
    if (map['variants'] != null) {
      try {
        variants = (map['variants'] as List<dynamic>)
            .map((v) => VideoQualityVariant.fromMap(v as Map<String, dynamic>))
            .toList();
      } catch (e) {
        // Continue without variants
      }
    }
    
    return VideoValidationMetadata(
      width: width,
      height: height,
      duration: duration,
      codec: codec,
      format: format,
      variants: variants,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (duration != null) 'duration': duration,
      if (codec != null) 'codec': codec,
      if (format != null) 'format': format,
      if (variants != null) 'variants': variants!.map((v) => v.toMap()).toList(),
    };
  }
}

class Video {
  final String id;
  final String userId;
  final String title;
  final String titleLower;
  final String description;
  final int duration;
  final String videoUrl;  // This will be the master playlist URL for HLS
  final String? hlsBasePath;  // New field for HLS base path
  final String? thumbnailUrl;
  final DateTime uploadedAt;
  final DateTime lastModified;
  final DateTime? scheduledPublishTime;
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final int sharesCount;
  final List<String> tags;
  final List<String> genres;
  final List<VideoTimestamp> timestamps;
  final List<VideoCredit> credits;
  final Map<String, dynamic> author;
  final String? duetVideoId;
  final List<VideoSubtitle>? subtitles;
  final bool ageRestricted;
  final Map<String, dynamic> copyrightStatus;
  final VideoProcessingStatus processingStatus;
  final VideoProcessingError processingError;
  final VideoValidationMetadata? validationMetadata;
  final List<String>? validationErrors;
  final int watchCount;
  final DateTime? lastWatchedAt;
  final int totalWatchDuration; // in seconds

  Video({
    required this.id,
    required this.userId,
    required this.title,
    String? titleLower,
    required this.description,
    required this.duration,
    required this.videoUrl,
    this.hlsBasePath,
    this.thumbnailUrl,
    required this.uploadedAt,
    required this.lastModified,
    this.scheduledPublishTime,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewsCount = 0,
    this.sharesCount = 0,
    this.tags = const [],
    this.genres = const [],
    this.timestamps = const [],
    this.credits = const [],
    required this.author,
    this.duetVideoId,
    this.subtitles,
    this.ageRestricted = false,
    required this.copyrightStatus,
    this.processingStatus = VideoProcessingStatus.pending,
    this.processingError = VideoProcessingError.none,
    this.validationMetadata,
    this.validationErrors,
    this.watchCount = 0,
    this.lastWatchedAt,
    this.totalWatchDuration = 0,
  }) : titleLower = titleLower ?? title.toLowerCase();

  // Create a Video from a Firestore document
  factory Video.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Handle description that might be an array
    String description = '';
    if (data['description'] is List) {
      description = (data['description'] as List).join('\n');
    } else if (data['description'] is String) {
      description = data['description'];
    }
    
    // Handle optional validation metadata
    VideoValidationMetadata? validationMetadata;
    if (data.containsKey('validationMetadata') && data['validationMetadata'] != null) {
      try {
        validationMetadata = VideoValidationMetadata.fromMap(
          data['validationMetadata'] as Map<String, dynamic>
        );
      } catch (e) {
        // Continue without validation metadata
      }
    }
    
    return Video(
      id: doc.id,
      userId: data['userId'],
      title: data['title'],
      titleLower: data['titleLower'] ?? data['title'].toLowerCase(),
      description: description,
      duration: data['duration'],
      videoUrl: data['videoUrl'],
      hlsBasePath: data['hlsBasePath'],
      thumbnailUrl: data['thumbnailUrl'],
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastModified: (data['lastModified'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scheduledPublishTime: data['scheduledPublishTime'] != null 
          ? (data['scheduledPublishTime'] as Timestamp).toDate() 
          : null,
      likesCount: data['likesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      viewsCount: data['viewsCount'] ?? 0,
      sharesCount: data['sharesCount'] ?? 0,
      tags: List<String>.from(data['tags'] ?? []),
      genres: List<String>.from(data['genres'] ?? []),
      timestamps: (data['timestamps'] as List<dynamic>? ?? [])
          .map((t) => VideoTimestamp.fromMap(t as Map<String, dynamic>))
          .toList(),
      credits: (data['credits'] as List<dynamic>? ?? [])
          .map((c) => VideoCredit.fromMap(c as Map<String, dynamic>))
          .toList(),
      author: Map<String, dynamic>.from(data['author'] ?? {}),
      duetVideoId: data['duetVideoId'],
      subtitles: data['subtitles'] != null
          ? (data['subtitles'] as List<dynamic>)
              .map((s) => VideoSubtitle.fromMap(s as Map<String, dynamic>))
              .toList()
          : null,
      ageRestricted: data['ageRestricted'] ?? false,
      copyrightStatus: Map<String, dynamic>.from(data['copyrightStatus'] ?? {}),
      processingStatus: VideoProcessingStatus.values.firstWhere(
        (e) => e.toString() == 'VideoProcessingStatus.${data['processingStatus'] ?? 'pending'}',
        orElse: () => VideoProcessingStatus.pending,
      ),
      processingError: VideoProcessingError.values.firstWhere(
        (e) => e.toString() == 'VideoProcessingError.${data['processingError'] ?? 'none'}',
        orElse: () => VideoProcessingError.none,
      ),
      validationMetadata: validationMetadata,
      validationErrors: data['validationErrors'] != null
          ? List<String>.from(data['validationErrors'] as List)
          : null,
      watchCount: data['watchCount'] ?? 0,
      lastWatchedAt: data['lastWatchedAt'] != null 
          ? (data['lastWatchedAt'] as Timestamp).toDate() 
          : null,
      totalWatchDuration: data['totalWatchDuration'] ?? 0,
    );
  }

  // Convert Video to a Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'titleLower': titleLower,
      'description': description,
      'duration': duration,
      'videoUrl': videoUrl,
      if (hlsBasePath != null) 'hlsBasePath': hlsBasePath,
      'thumbnailUrl': thumbnailUrl,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'lastModified': Timestamp.fromDate(lastModified),
      if (scheduledPublishTime != null)
        'scheduledPublishTime': Timestamp.fromDate(scheduledPublishTime!),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'viewsCount': viewsCount,
      'sharesCount': sharesCount,
      'tags': tags,
      'genres': genres,
      'timestamps': timestamps.map((t) => t.toMap()).toList(),
      'credits': credits.map((c) => c.toMap()).toList(),
      'author': author,
      if (duetVideoId != null) 'duetVideoId': duetVideoId,
      if (subtitles != null)
        'subtitles': subtitles!.map((s) => s.toMap()).toList(),
      'ageRestricted': ageRestricted,
      'copyrightStatus': copyrightStatus,
      'processingStatus': processingStatus.toString().split('.').last,
      'processingError': processingError.toString().split('.').last,
      if (validationMetadata != null) 'validationMetadata': validationMetadata!.toMap(),
      if (validationErrors != null) 'validationErrors': validationErrors,
      'watchCount': watchCount,
      if (lastWatchedAt != null) 'lastWatchedAt': Timestamp.fromDate(lastWatchedAt!),
      'totalWatchDuration': totalWatchDuration,
    };
  }

  // Create a copy of Video with modified fields
  Video copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    int? duration,
    String? videoUrl,
    String? hlsBasePath,
    String? thumbnailUrl,
    DateTime? uploadedAt,
    DateTime? lastModified,
    DateTime? scheduledPublishTime,
    int? likesCount,
    int? commentsCount,
    int? viewsCount,
    int? sharesCount,
    List<String>? tags,
    List<String>? genres,
    List<VideoTimestamp>? timestamps,
    List<VideoCredit>? credits,
    Map<String, dynamic>? author,
    String? duetVideoId,
    List<VideoSubtitle>? subtitles,
    bool? ageRestricted,
    Map<String, dynamic>? copyrightStatus,
    VideoProcessingStatus? processingStatus,
    VideoProcessingError? processingError,
    VideoValidationMetadata? validationMetadata,
    List<String>? validationErrors,
    int? watchCount,
    DateTime? lastWatchedAt,
    int? totalWatchDuration,
  }) {
    return Video(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      titleLower: this.titleLower,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      videoUrl: videoUrl ?? this.videoUrl,
      hlsBasePath: hlsBasePath ?? this.hlsBasePath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      lastModified: lastModified ?? this.lastModified,
      scheduledPublishTime: scheduledPublishTime ?? this.scheduledPublishTime,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      viewsCount: viewsCount ?? this.viewsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      tags: tags ?? this.tags,
      genres: genres ?? this.genres,
      timestamps: timestamps ?? this.timestamps,
      credits: credits ?? this.credits,
      author: author ?? this.author,
      duetVideoId: duetVideoId ?? this.duetVideoId,
      subtitles: subtitles ?? this.subtitles,
      ageRestricted: ageRestricted ?? this.ageRestricted,
      copyrightStatus: copyrightStatus ?? this.copyrightStatus,
      processingStatus: processingStatus ?? this.processingStatus,
      processingError: processingError ?? this.processingError,
      validationMetadata: validationMetadata ?? this.validationMetadata,
      validationErrors: validationErrors ?? this.validationErrors,
      watchCount: watchCount ?? this.watchCount,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      totalWatchDuration: totalWatchDuration ?? this.totalWatchDuration,
    );
  }

  // Helper method to get variant URLs
  List<VideoQualityVariant>? get qualityVariants => validationMetadata?.variants;

  // Helper method to get URL for specific quality
  String? getVariantUrl(String quality) {
    return qualityVariants?.firstWhere(
      (v) => v.quality == quality,
      orElse: () => qualityVariants!.first,
    ).playlistUrl;
  }

  // Helper method to get best quality URL based on bandwidth
  String? getAdaptiveUrl(int bandwidthBps) {
    if (qualityVariants == null || qualityVariants!.isEmpty) {
      return videoUrl;  // Fall back to master playlist
    }

    return qualityVariants!
        .where((v) => v.bitrate <= bandwidthBps)
        .reduce((a, b) => a.bitrate > b.bitrate ? a : b)
        .playlistUrl;
  }
}

class VideoTimestamp {
  final double time;
  final String label;

  VideoTimestamp({
    required this.time,
    required this.label,
  });

  factory VideoTimestamp.fromMap(Map<String, dynamic> map) {
    return VideoTimestamp(
      time: map['time'].toDouble(),
      label: map['label'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'time': time,
      'label': label,
    };
  }
}

class VideoCredit {
  final String userId;
  final String name;
  final String role;
  final String? profileUrl;

  VideoCredit({
    required this.userId,
    required this.name,
    required this.role,
    this.profileUrl,
  });

  factory VideoCredit.fromMap(Map<String, dynamic> map) {
    return VideoCredit(
      userId: map['userId'],
      name: map['name'],
      role: map['role'],
      profileUrl: map['profileUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'role': role,
      if (profileUrl != null) 'profileUrl': profileUrl,
    };
  }
}

class VideoSubtitle {
  final double timestamp;
  final String text;
  final String language;

  VideoSubtitle({
    required this.timestamp,
    required this.text,
    required this.language,
  });

  factory VideoSubtitle.fromMap(Map<String, dynamic> map) {
    return VideoSubtitle(
      timestamp: map['timestamp'].toDouble(),
      text: map['text'],
      language: map['language'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp,
      'text': text,
      'language': language,
    };
  }
}

class WatchSession {
  final String id;
  final String videoId;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final int watchDuration; // in seconds
  final int lastPosition; // in seconds
  final bool completedViewing;

  WatchSession({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.startTime,
    this.endTime,
    this.watchDuration = 0,
    this.lastPosition = 0,
    this.completedViewing = false,
  });

  factory WatchSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WatchSession(
      id: doc.id,
      videoId: data['videoId'],
      userId: data['userId'],
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null ? (data['endTime'] as Timestamp).toDate() : null,
      watchDuration: data['watchDuration'] ?? 0,
      lastPosition: data['lastPosition'] ?? 0,
      completedViewing: data['completedViewing'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'videoId': videoId,
      'userId': userId,
      'startTime': Timestamp.fromDate(startTime),
      if (endTime != null) 'endTime': Timestamp.fromDate(endTime!),
      'watchDuration': watchDuration,
      'lastPosition': lastPosition,
      'completedViewing': completedViewing,
    };
  }

  WatchSession copyWith({
    String? id,
    String? videoId,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    int? watchDuration,
    int? lastPosition,
    bool? completedViewing,
  }) {
    return WatchSession(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      watchDuration: watchDuration ?? this.watchDuration,
      lastPosition: lastPosition ?? this.lastPosition,
      completedViewing: completedViewing ?? this.completedViewing,
    );
  }
}

class WatchHistoryEntry {
  final String id;
  final String videoId;
  final String userId;
  final DateTime watchedAt;
  final int watchDuration;
  final VideoMetadata videoMetadata;
  final bool completed;

  WatchHistoryEntry({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.watchedAt,
    required this.watchDuration,
    required this.videoMetadata,
    this.completed = false,
  });

  factory WatchHistoryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WatchHistoryEntry(
      id: doc.id,
      videoId: data['videoId'],
      userId: data['userId'],
      watchedAt: (data['watchedAt'] as Timestamp).toDate(),
      watchDuration: data['watchDuration'] ?? 0,
      videoMetadata: VideoMetadata.fromMap(data['videoMetadata'] as Map<String, dynamic>),
      completed: data['completed'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'videoId': videoId,
      'userId': userId,
      'watchedAt': Timestamp.fromDate(watchedAt),
      'watchDuration': watchDuration,
      'videoMetadata': videoMetadata.toMap(),
      'completed': completed,
    };
  }
}

class VideoMetadata {
  final String title;
  final String? thumbnailUrl;
  final int duration;
  final Map<String, dynamic> author;

  VideoMetadata({
    required this.title,
    this.thumbnailUrl,
    required this.duration,
    required this.author,
  });

  factory VideoMetadata.fromMap(Map<String, dynamic> map) {
    return VideoMetadata(
      title: map['title'],
      thumbnailUrl: map['thumbnailUrl'],
      duration: map['duration'],
      author: Map<String, dynamic>.from(map['author']),
    );
  }

  factory VideoMetadata.fromVideo(Video video) {
    return VideoMetadata(
      title: video.title,
      thumbnailUrl: video.thumbnailUrl,
      duration: video.duration,
      author: video.author,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'author': author,
    };
  }
} 