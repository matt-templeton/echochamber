import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import 'dart:developer' as dev;

class TranscriptionService {
  static const String _functionUrl = 'http://127.0.0.1:5001/echo-chamber-8fb5f/us-central1/transcribe_to_midi';

  /// Transcribes an audio track to MIDI
  /// 
  /// [trackId] should be in the format "videoId/audioTrackId"
  /// [startTime] and [endTime] are optional timestamps in seconds
  static Future<void> transcribeToMidi({
    required String trackId,
    double? startTime,
    double? endTime,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_functionUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'trackId': trackId,
          if (startTime != null) 'startTime': startTime,
          if (endTime != null) 'endTime': endTime,
        }),
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to transcribe audio');
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to transcribe audio');
      }

      // Convert base64 MIDI data to blob
      final midiData = base64.decode(data['midiData']);
      final blob = html.Blob([midiData], 'audio/midi');
      
      // Create download URL and trigger download
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', data['filename'])
        ..style.display = 'none';
      
      html.document.body!.children.add(anchor);
      anchor.click();
      
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

    } catch (e) {
      dev.log('Error transcribing audio: $e', name: 'TranscriptionService', error: e);
      rethrow;
    }
  }
} 