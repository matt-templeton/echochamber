import 'package:flutter/material.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/application_state.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String? _displayName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SignInScreen(
          showAuthActionSwitch: true,
          actions: [
            ForgotPasswordAction((context, email) {
              context.push('/forgot-password?email=$email');
            }),
            AuthStateChangeAction<SignedIn>((context, state) {
              context.go('/');
            }),
            AuthStateChangeAction<UserCreated>((context, state) async {
              // Update display name if provided
              if (state.credential.user != null && _displayName != null) {
                await state.credential.user!.updateDisplayName(_displayName);
              }
              context.go('/');
            }),
            AuthStateChangeAction<CredentialLinked>((context, state) {
              context.go('/');
            }),
          ],
          styles: const {
            EmailFormStyle(
              signInButtonVariant: ButtonVariant.filled,
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(),
                filled: false,
              ),
            ),
          },
          subtitleBuilder: (context, action) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: action == AuthAction.signIn
                  ? const Text(
                      'Welcome back to Echo Chamber!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const Text(
                      'Create your account',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            );
          },
          footerBuilder: (context, action) {
            return Column(
              children: [
                if (action == AuthAction.signUp) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _displayName = value;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'By continuing, you agree to our terms and conditions.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
} 