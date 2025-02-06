import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String? profilePictureUrl;
  final String? bio;
  final Map<String, String>? socialMediaLinks;
  final DateTime createdAt;
  final DateTime lastActive;
  final String? timezone;
  final int followersCount;
  final int followingCount;
  final Map<String, bool>? onboardingProgress;
  final Map<String, dynamic>? monetization;
  final Map<String, int>? stats;
  final List<Map<String, dynamic>>? recentVideos;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.profilePictureUrl,
    this.bio,
    this.socialMediaLinks,
    required this.createdAt,
    required this.lastActive,
    this.timezone,
    this.followersCount = 0,
    this.followingCount = 0,
    this.onboardingProgress,
    this.monetization,
    this.stats,
    this.recentVideos,
  });

  // Create a User from a Firestore document
  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return User(
      id: doc.id,
      name: data['name'] as String,
      email: data['email'] as String,
      profilePictureUrl: data['profilePictureUrl'] as String?,
      bio: data['bio'] as String?,
      socialMediaLinks: data['socialMediaLinks'] != null 
          ? Map<String, String>.from(data['socialMediaLinks'] as Map)
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastActive: (data['lastActive'] as Timestamp).toDate(),
      timezone: data['timezone'] as String?,
      followersCount: data['followersCount'] as int? ?? 0,
      followingCount: data['followingCount'] as int? ?? 0,
      onboardingProgress: data['onboardingProgress'] != null 
          ? Map<String, bool>.from(data['onboardingProgress'] as Map)
          : null,
      monetization: data['monetization'] as Map<String, dynamic>?,
      stats: data['stats'] != null 
          ? Map<String, int>.from(data['stats'] as Map)
          : null,
      recentVideos: data['recentVideos'] != null 
          ? List<Map<String, dynamic>>.from(data['recentVideos'] as List)
          : null,
    );
  }

  // Convert User to a Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      if (profilePictureUrl != null) 'profilePictureUrl': profilePictureUrl,
      if (bio != null) 'bio': bio,
      if (socialMediaLinks != null) 'socialMediaLinks': socialMediaLinks,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': Timestamp.fromDate(lastActive),
      if (timezone != null) 'timezone': timezone,
      'followersCount': followersCount,
      'followingCount': followingCount,
      if (onboardingProgress != null) 'onboardingProgress': onboardingProgress,
      if (monetization != null) 'monetization': monetization,
      if (stats != null) 'stats': stats,
      if (recentVideos != null) 'recentVideos': recentVideos,
    };
  }

  // Create a copy of User with modified fields
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? profilePictureUrl,
    String? bio,
    Map<String, String>? socialMediaLinks,
    DateTime? createdAt,
    DateTime? lastActive,
    String? timezone,
    int? followersCount,
    int? followingCount,
    Map<String, bool>? onboardingProgress,
    Map<String, dynamic>? monetization,
    Map<String, int>? stats,
    List<Map<String, dynamic>>? recentVideos,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      bio: bio ?? this.bio,
      socialMediaLinks: socialMediaLinks ?? this.socialMediaLinks,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
      timezone: timezone ?? this.timezone,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      onboardingProgress: onboardingProgress ?? this.onboardingProgress,
      monetization: monetization ?? this.monetization,
      stats: stats ?? this.stats,
      recentVideos: recentVideos ?? this.recentVideos,
    );
  }
} 