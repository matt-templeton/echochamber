import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:echochamber/widgets/video/video_player.dart';

void main() {
  group('EchoVideoPlayer Widget Tests', () {
    testWidgets('EchoVideoPlayer can be instantiated and displayed', (tester) async {
      // Build our widget and trigger a frame
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EchoVideoPlayer(),
          ),
        ),
      );

      // Verify that the widget is present in the tree
      expect(find.byType(EchoVideoPlayer), findsOneWidget);
      
      // Since no URL is provided, we expect to see the placeholder UI
      expect(find.text('Loading video...'), findsOneWidget);
      expect(find.byIcon(Icons.video_library), findsOneWidget);
    });
  });
} 