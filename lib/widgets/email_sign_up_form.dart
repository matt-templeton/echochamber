import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user_model.dart' as app_models;
import '../repositories/user_repository.dart';

class EmailSignUpForm extends StatefulWidget {
  final VoidCallback onBack;
  final firebase_auth.FirebaseAuth auth;
  final UserRepository userRepository;

  const EmailSignUpForm({
    super.key,
    required this.onBack,
    required this.auth,
    required this.userRepository,
  });

  @override
  State<EmailSignUpForm> createState() => _EmailSignUpFormState();
}

class _EmailSignUpFormState extends State<EmailSignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Create the user in Firebase Auth
      final authResult = await widget.auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (authResult.user != null) {
        // Create the user document in Firestore
        final user = app_models.User(
          id: authResult.user!.uid,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          createdAt: DateTime.now(),
          lastActive: DateTime.now(),
          followersCount: 0,
          followingCount: 0,
          onboardingProgress: {
            'profile_complete': false,
            'first_video': false,
          },
        );

        await widget.userRepository.createUser(user);

        // Update display name in Firebase Auth
        await authResult.user!.updateDisplayName(_nameController.text.trim());

        if (mounted) {
          Navigator.of(context).pop(); // Close the bottom sheet
        }
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled. Please contact support.';
      case 'weak-password':
        return 'Please enter a stronger password.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sign up with email',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            key: const Key('nameField'),
            controller: _nameController,
            enabled: !_isLoading,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('emailField'),
            controller: _emailController,
            enabled: !_isLoading,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('passwordField'),
            controller: _passwordController,
            enabled: !_isLoading,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('confirmPasswordField'),
            controller: _confirmPasswordController,
            enabled: !_isLoading,
            decoration: const InputDecoration(
              labelText: 'Confirm Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _signUp,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Sign Up'),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _isLoading ? null : widget.onBack,
            child: const Text('← Go back'),
          ),
        ],
      ),
    );
  }
} 