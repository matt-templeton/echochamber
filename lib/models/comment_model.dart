import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String videoId;
  final String userId;
  final String text;
  final DateTime createdAt;
  final DateTime? editedAt;
  final int likesCount;
  final int repliesCount;
  final String? parentCommentId;
  final Map<String, dynamic> authorMetadata;  // Cached user data for quick display

  Comment({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.editedAt,
    this.likesCount = 0,
    this.repliesCount = 0,
    this.parentCommentId,
    required this.authorMetadata,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      videoId: data['videoId'],
      userId: data['userId'],
      text: data['text'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      editedAt: data['editedAt'] != null ? (data['editedAt'] as Timestamp).toDate() : null,
      likesCount: data['likesCount'] ?? 0,
      repliesCount: data['repliesCount'] ?? 0,
      parentCommentId: data['parentCommentId'],
      authorMetadata: Map<String, dynamic>.from(data['authorMetadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'videoId': videoId,
      'userId': userId,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      if (editedAt != null) 'editedAt': Timestamp.fromDate(editedAt!),
      'likesCount': likesCount,
      'repliesCount': repliesCount,
      if (parentCommentId != null) 'parentCommentId': parentCommentId,
      'authorMetadata': authorMetadata,
    };
  }

  Comment copyWith({
    String? id,
    String? videoId,
    String? userId,
    String? text,
    DateTime? createdAt,
    DateTime? editedAt,
    int? likesCount,
    int? repliesCount,
    String? parentCommentId,
    Map<String, dynamic>? authorMetadata,
  }) {
    return Comment(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      userId: userId ?? this.userId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      likesCount: likesCount ?? this.likesCount,
      repliesCount: repliesCount ?? this.repliesCount,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      authorMetadata: authorMetadata ?? this.authorMetadata,
    );
  }
} 