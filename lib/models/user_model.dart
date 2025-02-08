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
  final Map<String, dynamic>? privacySettings;
  final Map<String, dynamic>? notificationSettings;

  User({
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
    this.privacySettings,
    this.notificationSettings,
  }) {
  }

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
      privacySettings: data['privacySettings'] as Map<String, dynamic>?,
      notificationSettings: data['notificationSettings'] as Map<String, dynamic>?,
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
      if (privacySettings != null) 'privacySettings': privacySettings,
      if (notificationSettings != null) 'notificationSettings': notificationSettings,
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
    Map<String, dynamic>? privacySettings,
    Map<String, dynamic>? notificationSettings,
  }) {

    final result = User(
      id: identical(id, this.id) ? this.id : id ?? this.id,
      name: identical(name, this.name) ? this.name : name ?? this.name,
      email: identical(email, this.email) ? this.email : email ?? this.email,
      profilePictureUrl: identical(profilePictureUrl, this.profilePictureUrl) ? this.profilePictureUrl : profilePictureUrl,
      bio: identical(bio, this.bio) ? this.bio : bio,
      socialMediaLinks: identical(socialMediaLinks, this.socialMediaLinks) ? this.socialMediaLinks : socialMediaLinks,
      createdAt: identical(createdAt, this.createdAt) ? this.createdAt : createdAt ?? this.createdAt,
      lastActive: identical(lastActive, this.lastActive) ? this.lastActive : lastActive ?? this.lastActive,
      timezone: identical(timezone, this.timezone) ? this.timezone : timezone,
      followersCount: identical(followersCount, this.followersCount) ? this.followersCount : followersCount ?? this.followersCount,
      followingCount: identical(followingCount, this.followingCount) ? this.followingCount : followingCount ?? this.followingCount,
      onboardingProgress: identical(onboardingProgress, this.onboardingProgress) ? this.onboardingProgress : onboardingProgress,
      monetization: identical(monetization, this.monetization) ? this.monetization : monetization,
      stats: identical(stats, this.stats) ? this.stats : stats,
      recentVideos: identical(recentVideos, this.recentVideos) ? this.recentVideos : recentVideos,
      privacySettings: identical(privacySettings, this.privacySettings) ? this.privacySettings : privacySettings,
      notificationSettings: identical(notificationSettings, this.notificationSettings) ? this.notificationSettings : notificationSettings,
    );
    return result;
  }
} 