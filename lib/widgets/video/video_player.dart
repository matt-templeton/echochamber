// import 'package:flutter/material.dart';
// import 'package:echochamber/widgets/video/hls_video_player.dart';
// import 'package:echochamber/models/video_model.dart';

// class EchoVideoPlayer extends StatelessWidget {
//   final String? videoUrl;
//   final bool autoPlay;
//   final bool showControls;
//   final VoidCallback? onError;
//   final VoidCallback? onVideoEnd;

//   const EchoVideoPlayer({
//     super.key,
//     this.videoUrl,
//     this.autoPlay = false,
//     this.showControls = true,
//     this.onError,
//     this.onVideoEnd,
//   });

//   @override
//   Widget build(BuildContext context) {
//     // Create a minimal Video object for HLSVideoPlayer
//     final video = videoUrl != null ? Video(
//       id: 'temp_id',
//       userId: 'temp_user_id',
//       title: 'Video',
//       description: 'Video from URL',
//       duration: 0,
//       videoUrl: videoUrl!,
//       uploadedAt: DateTime.now(),
//       lastModified: DateTime.now(),
//       author: {'id': 'temp_id', 'name': 'Unknown'},
//       copyrightStatus: {'status': 'unknown', 'owner': 'Unknown'},
//     ) : null;

//     return HLSVideoPlayer(
//       video: video,
//       autoPlay: autoPlay,
//       showControls: showControls,
//       onError: onError,
//       onVideoEnd: onVideoEnd,
//     );
//   }
// } 