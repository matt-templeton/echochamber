import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:echochamber/widgets/email_sign_in_form.dart';
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
  Future<firebase_auth.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await Future.delayed(delay);
    return super.signInWithEmailAndPassword(email: email, password: password);
  }
}

void main() {
  late MockFirebaseAuth mockAuth;
  late VoidCallback mockOnBack;
  late MockNavigatorObserver mockObserver;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockOnBack = () {};
    mockObserver = MockNavigatorObserver();
  });

  tearDown(() {
    // Clean up resources
  });

  Future<void> pumpEmailSignInForm(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [mockObserver],
        home: Scaffold(
          body: EmailSignInForm(
            onBack: mockOnBack,
            auth: mockAuth,
          ),
        ),
      ),
    );
  }

  group('EmailSignInForm Widget Tests', () {
    testWidgets('renders correctly', (WidgetTester tester) async {
      await pumpEmailSignInForm(tester);
      expect(find.byType(Form), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2)); // Email and password fields
    });

    group('Form Validation', () {
      testWidgets('shows error when email is empty', (WidgetTester tester) async {
        await pumpEmailSignInForm(tester);
        
        // Find and tap the sign in button
        final signInButton = find.byType(ElevatedButton);
        await tester.tap(signInButton);
        await tester.pump();

        // Verify error message is shown
        expect(find.text('Please enter your email'), findsOneWidget);
      });

      testWidgets('shows error when email is invalid', (WidgetTester tester) async {
        await pumpEmailSignInForm(tester);
        
        // Enter invalid email
        await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'invalid-email');
        
        // Tap sign in button
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();

        // Verify error message
        expect(find.text('Please enter a valid email'), findsOneWidget);
      });

      testWidgets('shows error when password is empty', (WidgetTester tester) async {
        await pumpEmailSignInForm(tester);
        
        // Enter valid email but no password
        await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'test@example.com');
        
        // Tap sign in button
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();

        // Verify error message
        expect(find.text('Please enter your password'), findsOneWidget);
      });
    });

    group('Firebase Integration', () {
      testWidgets('successful sign in closes the form', (WidgetTester tester) async {
        // Setup successful auth response
        final mockUser = MockUser(
          uid: 'test-user-id',
          email: 'test@example.com',
        );
        mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: false);
        
        await pumpEmailSignInForm(tester);

        // Enter valid credentials
        await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'test@example.com');
        await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');

        // Tap sign in button and wait for navigation
        await tester.tap(find.byType(ElevatedButton));
        
        // Wait for the sign in process and navigation
        await tester.pump(); // Start the sign in
        await tester.pump(const Duration(milliseconds: 100)); // Wait for loading state
        await tester.pumpAndSettle(); // Wait for navigation

        // Verify form was closed
        expect(find.byType(EmailSignInForm), findsNothing);
      });

      testWidgets('shows loading indicator during sign in', (WidgetTester tester) async {
        // Setup a delayed auth response to ensure we can see the loading state
        mockAuth = DelayedMockAuth(
          delay: const Duration(seconds: 2),
          signedIn: false,
          mockUser: MockUser(uid: 'test-user-id'),
        );
        
        await pumpEmailSignInForm(tester);

        // Enter valid credentials
        await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'test@example.com');
        await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');

        // Tap sign in button
        await tester.tap(find.byType(ElevatedButton));
        
        // Pump the widget to start the sign in process
        await tester.pump();

        // Verify the sign in button text is replaced with loading indicator
        expect(find.text('Sign In'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Wait for the auth delay to complete
        await tester.pumpAndSettle();
      });
    });
  });
} 