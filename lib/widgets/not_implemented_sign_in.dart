import 'package:flutter/material.dart';

class NotImplementedSignIn extends StatelessWidget {
  final String provider;
  final VoidCallback onBack;

  const NotImplementedSignIn({
    super.key,
    required this.provider,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.construction,
          size: 64,
          color: Colors.grey,
        ),
        const SizedBox(height: 24),
        Text(
          '$provider login not implemented',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onBack,
            child: const Text('← Go back'),
          ),
        ),
      ],
    );
  }
} 