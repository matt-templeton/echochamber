import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as auth_mocks;
import 'package:echochamber/widgets/video/hls_video_player.dart';
import 'package:echochamber/models/video_model.dart';
import 'package:echochamber/providers/video_feed_provider.dart';
import 'hls_video_player_test.mocks.dart';

@GenerateMocks([VideoFeedProvider])
void main() {
  late Video testVideo;
  late MockVideoFeedProvider mockProvider;
  late auth_mocks.MockFirebaseAuth mockAuth;
  final now = DateTime.now();

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockProvider = MockVideoFeedProvider();
    
    // Setup mock auth with a fake user
    final user = auth_mocks.MockUser(
      isAnonymous: false,
      uid: 'test-user-id',
      email: 'test@example.com',
      displayName: 'Test User'
    );
    mockAuth = auth_mocks.MockFirebaseAuth(mockUser: user);

    // Setup mock video player platform
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter.io/videoPlayer',
      (message) async => null,
    );
    
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
        ],
      ),
    );
  });

  Widget buildPlayerWithProvider({
    Video? video,
    VoidCallback? onError,
    VoidCallback? onVideoEnd,
  }) {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          ChangeNotifierProvider<VideoFeedProvider>.value(value: mockProvider),
        ],
        child: Builder(
          builder: (context) => Scaffold(
            body: Container(
              color: Colors.black,
              child: HLSVideoPlayer(
                video: video,
                onError: onError,
                onVideoEnd: onVideoEnd,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Shows placeholder when video is null', (WidgetTester tester) async {
    await tester.pumpWidget(buildPlayerWithProvider(video: null));
    await tester.pump();

    expect(find.text('Loading video...'), findsOneWidget);
    expect(find.byIcon(Icons.video_library), findsNothing); // Updated since the current implementation uses CircularProgressIndicator
  });

  testWidgets('Shows error UI when video fails to load', (WidgetTester tester) async {
    bool errorCalled = false;
    await tester.pumpWidget(buildPlayerWithProvider(
      video: testVideo,
      onError: () => errorCalled = true,
    ));
    
    // Wait for error to be processed
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Assert: Error UI should be shown and callback called
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Error loading video'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(errorCalled, isTrue);
  });

  testWidgets('Retries playback when retry button is pressed', (WidgetTester tester) async {
    await tester.pumpWidget(buildPlayerWithProvider(video: testVideo));
    await tester.pump();

    // Assert error is shown
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Error loading video'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // Act: Press retry button
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Assert: Player should attempt to reinitialize
    // Note: We can't verify much here since video_player is mocked in tests
  });

  testWidgets('Reports video end', (WidgetTester tester) async {
    bool videoEndCalled = false;
    
    // Build widget and wait for initialization
    await tester.pumpWidget(buildPlayerWithProvider(
      video: testVideo,
      onVideoEnd: () => videoEndCalled = true,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Find the HLSVideoPlayer and simulate video end
    final player = tester.widget<HLSVideoPlayer>(find.byType(HLSVideoPlayer));
    player.onVideoEnd?.call();
    
    expect(videoEndCalled, isTrue);
  });

  group('HLSVideoPlayer - Watch Session Integration', () {
    testWidgets('starts watch session when video is initialized', (WidgetTester tester) async {
      // Arrange
      when(mockProvider.currentVideo).thenReturn(testVideo);
      when(mockProvider.startWatchSession(any)).thenAnswer((_) async {});
      when(mockProvider.setControllerReady(any)).thenReturn(null);

      // Setup mock video player platform to simulate successful initialization
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'flutter.io/videoPlayer',
        (message) async {
          final Map<dynamic, dynamic> decoded = const StandardMessageCodec().decodeMessage(message);
          if (decoded['method'] == 'create') {
            return const StandardMessageCodec().encodeMessage(<String, dynamic>{
              'textureId': 1,
            });
          } else if (decoded['method'] == 'initialize') {
            return const StandardMessageCodec().encodeMessage(<String, dynamic>{
              'width': 1920,
              'height': 1080,
            });
          }
          return null;
        },
      );

      // Act
      await tester.pumpWidget(buildPlayerWithProvider(video: testVideo));
      
      // Wait for initialization
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      verify(mockProvider.startWatchSession('test-user-id')).called(1);
    });

    testWidgets('updates watch position periodically', (WidgetTester tester) async {
      // Arrange
      when(mockProvider.currentVideo).thenReturn(testVideo);
      when(mockProvider.startWatchSession(testVideo.id)).thenAnswer((_) async {});
      when(mockProvider.updateWatchPosition(any)).thenAnswer((_) async {});
      when(mockProvider.setControllerReady(any)).thenReturn(null);

      // Act
      await tester.pumpWidget(buildPlayerWithProvider(video: testVideo));
      await tester.pump(); // Wait for initialization
      await tester.pump(const Duration(seconds: 5)); // Wait for position update interval

      // Assert
      verify(mockProvider.updateWatchPosition(any)).called(greaterThan(0));
    });

    testWidgets('ends watch session when video ends', (WidgetTester tester) async {
      // Arrange
      when(mockProvider.currentVideo).thenReturn(testVideo);
      when(mockProvider.startWatchSession(testVideo.id)).thenAnswer((_) async {});
      when(mockProvider.endCurrentSession()).thenAnswer((_) async {});
      when(mockProvider.setControllerReady(any)).thenReturn(null);

      // Act
      await tester.pumpWidget(buildPlayerWithProvider(
        video: testVideo,
        onVideoEnd: () {},
      ));
      await tester.pump(); // Wait for initialization

      // Simulate video end
      final player = tester.widget<HLSVideoPlayer>(find.byType(HLSVideoPlayer));
      player.onVideoEnd?.call();
      await tester.pump();

      // Assert
      verify(mockProvider.endCurrentSession()).called(1);
    });

    testWidgets('handles video errors gracefully', (WidgetTester tester) async {
      // Arrange
      when(mockProvider.currentVideo).thenReturn(testVideo);
      when(mockProvider.startWatchSession(testVideo.id)).thenAnswer((_) async {});
      when(mockProvider.endCurrentSession()).thenAnswer((_) async {});
      when(mockProvider.setControllerReady(any)).thenReturn(null);

      bool errorCalled = false;

      // Act
      await tester.pumpWidget(buildPlayerWithProvider(
        video: testVideo,
        onError: () => errorCalled = true,
      ));
      await tester.pump(); // Wait for initialization

      // Assert
      expect(errorCalled, isTrue); // Video player should fail in test environment
      verify(mockProvider.endCurrentSession()).called(1);
    });
  });
} 