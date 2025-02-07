import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:better_player_enhanced/better_player.dart';
import 'package:echochamber/widgets/video/hls_video_player.dart';
import 'package:echochamber/models/video_model.dart';

void main() {
  late Video testVideo;
  final now = DateTime.now();

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    testVideo = Video(
      id: 'test_video_id',
      userId: 'test_user_id',
      title: 'Test Video',
      description: 'Test Description',
      videoUrl: 'https://example.com/master.m3u8',
      hlsBasePath: 'https://example.com/',
      thumbnailUrl: 'https://example.com/thumbnail.jpg',
      duration: 30,
      uploadedAt: now,
      lastModified: now,
      author: {
        'id': 'test_author_id',
        'name': 'Test Author',
        'avatarUrl': 'https://example.com/avatar.jpg'
      },
      copyrightStatus: {
        'type': 'original',
        'owner': 'Test Author',
        'license': 'All Rights Reserved'
      },
      validationMetadata: VideoValidationMetadata(
        width: 1080,
        height: 1920,
        duration: 30,
        codec: 'h264',
        format: 'hls',
        variants: [
          VideoQualityVariant(
            quality: '1080p',
            bitrate: 5000000,
            playlistUrl: 'https://example.com/1080p.m3u8',
          ),
          VideoQualityVariant(
            quality: '720p',
            bitrate: 2500000,
            playlistUrl: 'https://example.com/720p.m3u8',
          ),
          VideoQualityVariant(
            quality: '480p',
            bitrate: 1000000,
            playlistUrl: 'https://example.com/480p.m3u8',
          ),
        ],
      ),
    );
  });

  testWidgets('HLSVideoPlayer shows placeholder when video is null', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HLSVideoPlayer(
            video: null,
          ),
        ),
      ),
    );

    // No need for pumpAndSettle since this is a static state
    await tester.pump();

    // Verify placeholder is shown
    expect(find.byType(BetterPlayer), findsNothing);
    expect(find.byType(Icon), findsOneWidget);
    expect(find.text('Loading video...'), findsOneWidget);
  });

  testWidgets('HLSVideoPlayer shows error widget on error', (WidgetTester tester) async {
    bool errorCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HLSVideoPlayer(
            video: testVideo,
            onError: () => errorCalled = true,
          ),
        ),
      ),
    );

    // Wait for initial frame
    await tester.pump();

    // Simulate error using the exposed method
    final state = tester.state(find.byType(HLSVideoPlayer));
    (state as dynamic).setErrorState(true);
    
    // Wait for error UI to build
    await tester.pump();

    // Verify error widget is shown
    expect(find.byType(BetterPlayer), findsNothing);
    expect(find.byType(Icon), findsOneWidget);
    expect(find.text('Error loading video'), findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);
  });

  testWidgets('HLSVideoPlayer shows retry button that can be pressed', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HLSVideoPlayer(
            video: testVideo,
          ),
        ),
      ),
    );

    // Wait for initial frame
    await tester.pump();

    // Simulate error using the exposed method
    final state = tester.state(find.byType(HLSVideoPlayer));
    (state as dynamic).setErrorState(true);
    
    // Wait for error UI to build
    await tester.pump();

    // Verify error state
    expect(find.text('Error loading video'), findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);

    // Press retry button
    await tester.tap(find.byType(TextButton));
    await tester.pump();

    // Verify error widget is gone
    expect(find.text('Error loading video'), findsNothing);
  });
} 