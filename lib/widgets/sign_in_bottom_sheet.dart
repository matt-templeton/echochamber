import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/user_repository.dart';
import 'email_sign_up_form.dart';
import 'email_sign_in_form.dart';
import 'not_implemented_sign_in.dart';

class SignInBottomSheet extends StatefulWidget {
  final bool showSignUpFirst;

  const SignInBottomSheet({
    super.key,
    this.showSignUpFirst = false,
  });

  @override
  State<SignInBottomSheet> createState() => _SignInBottomSheetState();
}

class _SignInBottomSheetState extends State<SignInBottomSheet> {
  Widget? _currentForm;
  bool _showingSignUp = false;
  final _auth = FirebaseAuth.instance;
  final _userRepository = UserRepository();

  @override
  void initState() {
    super.initState();
    _showingSignUp = widget.showSignUpFirst;
  }

  void _showEmailSignUp() {
    setState(() {
      _showingSignUp = true;
      _currentForm = EmailSignUpForm(
        onBack: () => setState(() => _currentForm = null),
        auth: _auth,
        userRepository: _userRepository,
      );
    });
  }

  void _showEmailSignIn() {
    setState(() {
      _showingSignUp = false;
      _currentForm = EmailSignInForm(
        onBack: () => setState(() => _currentForm = null),
        auth: _auth,
      );
    });
  }

  void _showNotImplemented(String provider) {
    setState(() {
      _currentForm = NotImplementedSignIn(
        provider: provider,
        onBack: () => setState(() => _currentForm = null),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          if (_currentForm == null) ...[
            // Close button
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 16),
            // Headers
            Text(
              _showingSignUp ? 'Sign up for Echo Chamber' : 'Sign in to Echo Chamber',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _showingSignUp 
                ? 'Create a profile, follow other accounts, share music, and more'
                : 'Welcome back! Sign in to continue sharing music',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            // Sign in buttons
            _SignInButton(
              icon: Icons.email,
              iconColor: Colors.black,
              text: 'Use phone or email',
              onPressed: _showingSignUp ? _showEmailSignUp : _showEmailSignIn,
            ),
            const SizedBox(height: 12),
            _SignInButton(
              icon: FontAwesomeIcons.facebook,
              iconColor: const Color(0xFF1877F2), // Facebook blue
              text: 'Continue with Facebook',
              onPressed: () => _showNotImplemented('Facebook'),
            ),
            const SizedBox(height: 12),
            _SignInButton(
              icon: FontAwesomeIcons.apple,
              iconColor: Colors.black,
              text: 'Continue with Apple',
              onPressed: () => _showNotImplemented('Apple'),
            ),
            const SizedBox(height: 12),
            _SignInButton(
              icon: FontAwesomeIcons.google,
              iconColor: const Color(0xFFDB4437), // Google red
              text: 'Continue with Google',
              onPressed: () => _showNotImplemented('Google'),
            ),
            const SizedBox(height: 12),
            _SignInButton(
              icon: FontAwesomeIcons.xTwitter,
              iconColor: Colors.black,
              text: 'Continue with Twitter',
              onPressed: () => _showNotImplemented('Twitter'),
            ),
            const Spacer(),
            // Toggle between sign in and sign up
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showingSignUp 
                    ? 'Already have an account?' 
                    : 'Don\'t have an account?',
                  style: const TextStyle(color: Colors.grey),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showingSignUp = !_showingSignUp;
                    });
                  },
                  child: Text(_showingSignUp ? 'Sign in' : 'Sign up'),
                ),
              ],
            ),
          ] else
            Expanded(child: _currentForm!),
          
          // Add extra padding at the bottom for the home indicator/gesture bar
          if (_currentForm == null)
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final VoidCallback onPressed;

  const _SignInButton({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: Colors.grey),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              icon,
              size: 24,
              color: iconColor,
            ),
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 40),  // Balance the icon on the left
          ],
        ),
      ),
    );
  }
} 