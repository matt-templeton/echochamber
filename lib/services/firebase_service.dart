import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart' as app_models;

class FirebaseService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user stream
  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<app_models.User> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    firebase_auth.UserCredential? userCredential;
    try {
      // Create authentication user
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('Failed to create user');
      }

      // Create user profile in Firestore
      final user = app_models.User(
        id: userCredential.user!.uid,
        name: name,
        email: email,
        createdAt: DateTime.now(),
        isEmailVerified: userCredential.user!.emailVerified,
      );

      // Save user data to Firestore
      try {
        await _firestore
            .collection('users')
            .doc(user.id)
            .set(user.toMap());
      } catch (e) {
        // If Firestore creation fails, delete the auth user to maintain consistency
        await userCredential.user?.delete();
        throw Exception('Failed to create user profile: $e');
      }

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      return user;
    } on firebase_auth.FirebaseAuthException catch (e) {
      // Clean up any created auth user if we fail
      if (userCredential?.user != null) {
        await userCredential!.user!.delete();
      }
      throw _handleAuthError(e);
    } catch (e) {
      // Clean up any created auth user if we fail
      if (userCredential?.user != null) {
        await userCredential!.user!.delete();
      }
      throw Exception('Failed to create user: $e');
    }
  }

  // Helper method to handle Firebase Auth errors
  Exception _handleAuthError(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return Exception('The password provided is too weak.');
      case 'email-already-in-use':
        return Exception('An account already exists for that email.');
      case 'invalid-email':
        return Exception('The email address is not valid.');
      case 'operation-not-allowed':
        return Exception('Email/password accounts are not enabled.');
      default:
        return Exception(e.message ?? 'An unknown error occurred.');
    }
  }

  Future<app_models.User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('Failed to sign in');
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User data not found');
      }

      return app_models.User.fromFirebase(
        userDoc.data()!,
        userDoc.id,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No user found with this email');
        case 'wrong-password':
          throw Exception('Wrong password');
        case 'invalid-email':
          throw Exception('Invalid email address');
        case 'user-disabled':
          throw Exception('This account has been disabled');
        default:
          throw Exception('Failed to sign in: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }
} 