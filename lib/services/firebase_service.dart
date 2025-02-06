import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart' as app_models;
import '../repositories/user_repository.dart';

class AuthService {
  final FirebaseAuth _auth;
  final UserRepository _userRepository;

  AuthService({
    FirebaseAuth? auth,
    UserRepository? userRepository,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _userRepository = userRepository ?? UserRepository();

  // Get the current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get the current app user from Firestore
  Future<app_models.User?> getCurrentAppUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      return await _userRepository.getUserById(user.uid);
    }
    return null;
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
} 