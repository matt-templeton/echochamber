import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart' as app_models;

class ApplicationState extends ChangeNotifier {
  ApplicationState() {
    init();
  }

  bool _loggedIn = false;
  bool get loggedIn => _loggedIn;

  bool _emailVerified = false;
  bool get emailVerified => _emailVerified;

  User? _user;
  User? get user => _user;

  app_models.User? _appUser;
  app_models.User? get appUser => _appUser;

  Future<void> init() async {
    // Configure Firebase UI Auth providers
    FirebaseUIAuth.configureProviders([
      EmailAuthProvider(),
    ]);

    // Listen to auth state changes
    FirebaseAuth.instance.userChanges().listen((user) async {
      if (user != null && user != _user) {
        // Only update if the user has changed
        _user = user;
        _loggedIn = true;
        _emailVerified = user.emailVerified;

        // Fetch or create the user document in Firestore
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            _appUser = app_models.User.fromFirebase(
              userDoc.data()!,
              userDoc.id,
            );
          } else {
            // Create new user document if it doesn't exist
            final newUser = app_models.User(
              id: user.uid,
              name: user.displayName ?? '',
              email: user.email ?? '',
              createdAt: DateTime.now(),
              isEmailVerified: user.emailVerified,
              photoUrl: user.photoURL,
            );

            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set(newUser.toMap());

            _appUser = newUser;
          }
        } catch (e) {
          print('Error fetching/creating user document: $e');
        }
      } else if (user == null && _user != null) {
        // User has signed out
        _user = null;
        _loggedIn = false;
        _emailVerified = false;
        _appUser = null;
      }
      
      notifyListeners();
    });
  }

  Future<void> refreshLoggedInUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    await currentUser.reload();
    
    // Update state after reload
    _emailVerified = currentUser.emailVerified;
    notifyListeners();
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
} 