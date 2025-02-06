import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:echochamber/services/firebase_service.dart';
import 'package:echochamber/repositories/user_repository.dart';
import 'package:echochamber/models/user_model.dart' as app_models;
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_service_test.mocks.dart';

@GenerateMocks([UserRepository])
void main() {
  late MockFirebaseAuth mockAuth;
  late MockUserRepository mockUserRepository;
  late AuthService authService;
  late MockUser mockUser;

  setUp(() async {
    mockUser = MockUser(
      uid: 'test-user-id',
      email: 'test@example.com',
      displayName: 'Test User',
    );
    // Initialize mock auth with signed in user
    mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);
    mockUserRepository = MockUserRepository();
    
    // Create a custom AuthService that uses our mocks
    authService = AuthService(
      auth: mockAuth,
      userRepository: mockUserRepository,
    );
  });

  tearDown(() {
    // Clean up any resources
  });

  group('AuthService - User Management', () {
    test('currentUser should return the current user when logged in', () {
      // Act
      final user = authService.currentUser;

      // Assert
      expect(user, isNotNull);
      expect(user?.uid, 'test-user-id');
      expect(user?.email, 'test@example.com');
      expect(user?.displayName, 'Test User');
    });

    test('currentUser should return null when not logged in', () {
      // Arrange
      mockAuth = MockFirebaseAuth(signedIn: false);
      authService = AuthService(
        auth: mockAuth,
        userRepository: mockUserRepository,
      );

      // Act
      final user = authService.currentUser;

      // Assert
      expect(user, isNull);
    });

    test('authStateChanges should emit user when signed in', () {
      // Act & Assert
      expect(
        mockAuth.authStateChanges(),
        emitsInOrder([isA<User>()]),
      );
    });

    test('authStateChanges should emit null when signed out', () async {
      // Arrange
      mockAuth = MockFirebaseAuth(signedIn: false);
      authService = AuthService(
        auth: mockAuth,
        userRepository: mockUserRepository,
      );

      // Act & Assert
      expect(
        mockAuth.authStateChanges(),
        emitsInOrder([null]),
      );
    });
  });

  group('AuthService - App User Management', () {
    test('getCurrentAppUser should return app user when logged in', () async {
      // Arrange
      final appUser = app_models.User(
        id: 'test-user-id',
        name: 'Test User',
        email: 'test@example.com',
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
      );
      
      when(mockUserRepository.getUserById('test-user-id'))
          .thenAnswer((_) async => appUser);

      // Act
      final result = await authService.getCurrentAppUser();

      // Assert
      expect(result, isNotNull);
      expect(result?.id, 'test-user-id');
      expect(result?.name, 'Test User');
      expect(result?.email, 'test@example.com');
      verify(mockUserRepository.getUserById('test-user-id')).called(1);
    });

    test('getCurrentAppUser should return null when not logged in', () async {
      // Arrange
      mockAuth = MockFirebaseAuth(signedIn: false);
      authService = AuthService(
        auth: mockAuth,
        userRepository: mockUserRepository,
      );

      // Act
      final result = await authService.getCurrentAppUser();

      // Assert
      expect(result, isNull);
      verifyNever(mockUserRepository.getUserById(any));
    });
  });

  group('AuthService - Sign Out', () {
    test('signOut should successfully sign out user', () async {
      // Arrange - Start with a signed in user
      expect(mockAuth.currentUser, isNotNull);
      
      // Act
      await authService.signOut();

      // Assert
      expect(mockAuth.currentUser, isNull);
      
      // Create a new auth instance to test the signed out state
      final signedOutAuth = MockFirebaseAuth(signedIn: false);
      expect(
        signedOutAuth.authStateChanges(),
        emitsInOrder([null]),
      );
    });
  });
} 