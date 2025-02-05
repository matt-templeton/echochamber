import 'package:flutter/material.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:go_router/go_router.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EmailVerificationScreen(
      actions: [
        EmailVerifiedAction(() {
          context.go('/');  // Go to home screen when email is verified
        }),
        AuthCancelledAction((context) {
          context.go('/sign-in');  // Go back to sign in if cancelled
        }),
      ],
    );
  }
} 