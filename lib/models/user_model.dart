import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String name;
  final String email;
  final DateTime createdAt;
  final bool isEmailVerified;
  final String? photoUrl;
  final String? bio;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
    this.isEmailVerified = false,
    this.photoUrl,
    this.bio,
  });

  // Create a User from a Firebase User
  factory User.fromFirebase(Map<String, dynamic> data, String id) {
    return User(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isEmailVerified: data['isEmailVerified'] ?? false,
      photoUrl: data['photoUrl'],
      bio: data['bio'],
    );
  }

  // Convert User to a Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
      'isEmailVerified': isEmailVerified,
      'photoUrl': photoUrl,
      'bio': bio,
    };
  }

  // Create a copy of User with modified fields
  User copyWith({
    String? name,
    String? email,
    DateTime? createdAt,
    bool? isEmailVerified,
    String? photoUrl,
    String? bio,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
    );
  }
} 