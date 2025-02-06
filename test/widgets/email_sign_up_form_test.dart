import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:echochamber/widgets/email_sign_up_form.dart';
import 'package:echochamber/repositories/user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

// Create a mock Navigator Observer to verify navigation
class MockNavigatorObserver extends Mock implements NavigatorObserver {
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {}
}

// Create a delayed mock auth
class DelayedMockAuth extends MockFirebaseAuth {
  final Duration delay;

  DelayedMockAuth({
    required this.delay,
    bool signedIn = false,
    MockUser? mockUser,
  }) : super(signedIn: signedIn, mockUser: mockUser);

  @override
  Future<firebase_auth.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await Future.delayed(delay);
    return super.createUserWithEmailAndPassword(email: email, password: password);
  }
}

@GenerateMocks([UserRepository])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeFirestore;
  late UserRepository userRepository;
  late VoidCallback mockOnBack;
  late MockNavigatorObserver mockObserver;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    fakeFirestore = FakeFirebaseFirestore();
    userRepository = UserRepository(firestore: fakeFirestore);
    mockOnBack = () {};
    mockObserver = MockNavigatorObserver();
  });

  tearDown(() {
    // Clean up resources
  });

  Future<void> pumpEmailSignUpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [mockObserver],
        home: Scaffold(
          body: EmailSignUpForm(
            onBack: mockOnBack,
            auth: mockAuth,
            userRepository: userRepository,
          ),
        ),
      ),
    );
    await tester.pump(); // Ensure widget is fully built
  }

  group('EmailSignUpForm Widget Tests', () {
    testWidgets('renders correctly', (WidgetTester tester) async {
      await pumpEmailSignUpForm(tester);
      expect(find.byType(Form), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4)); // Name, Email, Password, Confirm Password
    });

    group('Form Validation', () {
      testWidgets('shows error when name is empty', (WidgetTester tester) async {
        await pumpEmailSignUpForm(tester);
        
        // Find and tap the sign up button
        final signUpButton = find.byType(ElevatedButton);
        await tester.tap(signUpButton);
        await tester.pumpAndSettle();

        // Verify error message is shown
        expect(find.text('Please enter your name'), findsOneWidget);
      });

      testWidgets('shows error when email is empty', (WidgetTester tester) async {
        await pumpEmailSignUpForm(tester);
        
        // Enter only name
        await tester.enterText(find.byKey(const Key('nameField')), 'Test User');
        
        // Tap sign up button
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // Verify error message is shown
        expect(find.text('Please enter your email'), findsOneWidget);
      });

      testWidgets('shows error when email is invalid', (WidgetTester tester) async {
        await pumpEmailSignUpForm(tester);
        
        // Enter name and invalid email
        await tester.enterText(find.byKey(const Key('nameField')), 'Test User');
        await tester.enterText(find.byKey(const Key('emailField')), 'invalid-email');
        
        // Tap sign up button
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // Verify error message
        expect(find.text('Please enter a valid email'), findsOneWidget);
      });

      testWidgets('shows error when password is empty', (WidgetTester tester) async {
        await pumpEmailSignUpForm(tester);
        
        // Enter name and email only
        await tester.enterText(find.byKey(const Key('nameField')), 'Test User');
        await tester.enterText(find.byKey(const Key('emailField')), 'test@example.com');
        
        // Tap sign up button
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // Verify error message
        expect(find.text('Please enter a password'), findsOneWidget);
      });

      testWidgets('shows error when password is too short', (WidgetTester tester) async {
        await pumpEmailSignUpForm(tester);
        
        // Enter name, email, and short password
        await tester.enterText(find.byKey(const Key('nameField')), 'Test User');
        await tester.enterText(find.byKey(const Key('emailField')), 'test@example.com');
        await tester.enterText(find.byKey(const Key('passwordField')), '12345');
        
        // Tap sign up button
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // Verify error message
        expect(find.text('Password must be at least 6 characters'), findsOneWidget);
      });

      testWidgets('shows error when passwords do not match', (WidgetTester tester) async {
        await pumpEmailSignUpForm(tester);
        
        // Enter all fields but mismatched passwords
        await tester.enterText(find.byKey(const Key('nameField')), 'Test User');
        await tester.enterText(find.byKey(const Key('emailField')), 'test@example.com');
        await tester.enterText(find.byKey(const Key('passwordField')), 'password123');
        await tester.enterText(find.byKey(const Key('confirmPasswordField')), 'password456');
        
        // Tap sign up button
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // Verify error message
        expect(find.text('Passwords do not match'), findsOneWidget);
      });
    });

    group('Firebase Integration', () {
      testWidgets('successful sign up closes the form', (WidgetTester tester) async {
        // Setup successful auth response
        final mockUser = MockUser(
          uid: 'test-user-id',
          email: 'test@example.com',
        );
        mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: false);
        
        await pumpEmailSignUpForm(tester);

        // Enter valid credentials
        await tester.enterText(find.byKey(const Key('nameField')), 'Test User');
        await tester.enterText(find.byKey(const Key('emailField')), 'test@example.com');
        await tester.enterText(find.byKey(const Key('passwordField')), 'password123');
        await tester.enterText(find.byKey(const Key('confirmPasswordField')), 'password123');

        // Tap sign up button and wait for navigation
        await tester.tap(find.byType(ElevatedButton));
        
        // Wait for the sign up process and navigation
        await tester.pump(); // Start the sign up
        await tester.pump(const Duration(milliseconds: 100)); // Wait for loading state
        await tester.pumpAndSettle(); // Wait for navigation

        // Verify form was closed
        expect(find.byType(EmailSignUpForm), findsNothing);
      });

      testWidgets('shows loading indicator during sign up', (WidgetTester tester) async {
        // Setup a delayed auth response to ensure we can see the loading state
        mockAuth = DelayedMockAuth(
          delay: const Duration(seconds: 2),
          signedIn: false,
          mockUser: MockUser(uid: 'test-user-id'),
        );
        
        await pumpEmailSignUpForm(tester);

        // Enter valid credentials
        await tester.enterText(find.byKey(const Key('nameField')), 'Test User');
        await tester.enterText(find.byKey(const Key('emailField')), 'test@example.com');
        await tester.enterText(find.byKey(const Key('passwordField')), 'password123');
        await tester.enterText(find.byKey(const Key('confirmPasswordField')), 'password123');

        // Tap sign up button
        await tester.tap(find.byType(ElevatedButton));
        
        // Pump the widget to start the sign up process
        await tester.pump();

        // Verify the sign up button text is replaced with loading indicator
        expect(find.text('Sign Up'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Wait for the auth delay to complete
        await tester.pumpAndSettle();
      });
    });
  });
} 