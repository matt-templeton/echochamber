import 'package:cloud_firestore/cloud_firestore.dart';

enum AudioTrackType {
  original,
  vocals,
  drums,
  bass,
  other
}

class AudioTrackVariant {
  final String quality;
  final int bitrate;
  final String playlistUrl;

  AudioTrackVariant({
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
            'https://firebasestorage.googleapis.com/v0/b/echo-chamber-8fb5f.appspot.com/o/$playlistUrl?alt=media';

  factory AudioTrackVariant.fromMap(Map<String, dynamic> map) {
    final quality = map['quality']?.toString() ?? 'auto';
    final bitrate = (map['bitrate'] as num?)?.toInt() ?? 256000;
    final playlistUrl = map['playlistUrl']?.toString();
    
    if (playlistUrl == null) {
      throw FormatException('Missing playlistUrl in variant data');
    }
    
    return AudioTrackVariant(
      quality: quality,
      bitrate: bitrate,
      playlistUrl: playlistUrl,
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

class AudioTrack {
  final String id;
  final String videoId;
  final AudioTrackType type;
  final String masterPlaylistUrl;
  final String hlsBasePath;
  final List<AudioTrackVariant> variants;
  final DateTime createdAt;
  final DateTime lastModified;
  final Map<String, dynamic> metadata;

  AudioTrack({
    required this.id,
    required this.videoId,
    required this.type,
    required this.masterPlaylistUrl,
    required this.hlsBasePath,
    required this.variants,
    required this.createdAt,
    required this.lastModified,
    this.metadata = const {},
  });

  factory AudioTrack.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return AudioTrack(
      id: doc.id,
      videoId: data['videoId'],
      type: AudioTrackType.values.firstWhere(
        (e) => e.toString() == 'AudioTrackType.${data['type']}',
        orElse: () => AudioTrackType.original,
      ),
      masterPlaylistUrl: data['masterPlaylistUrl'],
      hlsBasePath: data['hlsBasePath'],
      variants: (data['variants'] as List<dynamic>? ?? [])
          .map((v) => AudioTrackVariant.fromMap(v as Map<String, dynamic>))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastModified: (data['lastModified'] as Timestamp).toDate(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'videoId': videoId,
      'type': type.toString().split('.').last,
      'masterPlaylistUrl': masterPlaylistUrl,
      'hlsBasePath': hlsBasePath,
      'variants': variants.map((v) => v.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'lastModified': Timestamp.fromDate(lastModified),
      'metadata': metadata,
    };
  }

  AudioTrack copyWith({
    String? id,
    String? videoId,
    AudioTrackType? type,
    String? masterPlaylistUrl,
    String? hlsBasePath,
    List<AudioTrackVariant>? variants,
    DateTime? createdAt,
    DateTime? lastModified,
    Map<String, dynamic>? metadata,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      type: type ?? this.type,
      masterPlaylistUrl: masterPlaylistUrl ?? this.masterPlaylistUrl,
      hlsBasePath: hlsBasePath ?? this.hlsBasePath,
      variants: variants ?? this.variants,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      metadata: metadata ?? this.metadata,
    );
  }

  // Helper method to get URL for specific quality
  String? getVariantUrl(String quality) {
    return variants.firstWhere(
      (v) => v.quality == quality,
      orElse: () => variants.first,
    ).playlistUrl;
  }

  // Helper method to get best quality URL based on bandwidth
  String getAdaptiveUrl(int bandwidthBps) {
    if (variants.isEmpty) {
      return masterPlaylistUrl;
    }

    return variants
        .where((v) => v.bitrate <= bandwidthBps)
        .reduce((a, b) => a.bitrate > b.bitrate ? a : b)
        .playlistUrl;
  }
} 