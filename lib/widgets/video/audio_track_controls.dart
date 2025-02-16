import 'package:flutter/material.dart';
import '../../models/audio_track_model.dart';
import 'dart:developer' as dev;
import 'audio_track_item.dart';

// Add custom slider thumb that's just a circle with no value indicator
class EmptyCircleThumbShape extends SliderComponentShape {
  final double radius;

  const EmptyCircleThumbShape({
    this.radius = 5,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(radius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, paint);
  }
}

// Add custom track shape that's completely transparent (we'll draw it in the meter painter)
class EmptyTrackShape extends RoundedRectSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    // Don't draw anything - we'll handle it in the meter painter
  }
}

// Add volume meter painter
class VolumeMeterPainter extends CustomPainter {
  final double level;  // This now controls how much of the available space is filled (0.0 to 1.0)
  final Color color;
  final double value;  // This controls the maximum width (slider position)

  VolumeMeterPainter({
    required this.level,
    required this.value,
    this.color = Colors.green,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackHeight = 8.0;
    final yCenter = size.height / 2;
    
    // Draw the base track (white line)
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(trackHeight / 2, yCenter),
      Offset(size.width - trackHeight / 2, yCenter),
      trackPaint,
    );

    // Calculate the maximum available width based on the slider value
    final maxWidth = (size.width - trackHeight) * value;
    if (maxWidth > 0) {
      // Calculate the actual meter width based on the level
      final meterWidth = maxWidth * level;
      
      final meterPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackHeight
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(trackHeight / 2, yCenter),
        Offset(meterWidth + trackHeight / 2, yCenter),
        meterPaint,
      );
    }
  }

  @override
  bool shouldRepaint(VolumeMeterPainter oldDelegate) {
    return level != oldDelegate.level || 
           color != oldDelegate.color || 
           value != oldDelegate.value;
  }
}

class AudioTrackControls extends StatefulWidget {
  final List<AudioTrack> tracks;
  final bool isExpanded;
  final VoidCallback onCollapse;
  final Function(String trackId, bool enabled) onTrackToggle;
  final Function(String trackId, double volume) onVolumeChange;
  final Map<String, bool> initialEnabledTracks;
  final Map<String, double> initialTrackVolumes;

  const AudioTrackControls({
    Key? key,
    required this.tracks,
    required this.isExpanded,
    required this.onCollapse,
    required this.onTrackToggle,
    required this.onVolumeChange,
    required this.initialEnabledTracks,
    required this.initialTrackVolumes,
  }) : super(key: key);

  @override
  State<AudioTrackControls> createState() => _AudioTrackControlsState();
}

class _AudioTrackControlsState extends State<AudioTrackControls> {
  final Map<String, bool> _enabledTracks = {};
  final Map<String, double> _trackVolumes = {};
  final Map<String, bool> _expandedTracks = {};
  bool _isOriginalEnabled = true;
  late final List<AudioTrack> _sortedTracks;

  @override
  void initState() {
    super.initState();
    _sortedTracks = List<AudioTrack>.from(widget.tracks);
    _sortedTracks.sort((a, b) {
      if (a.type == AudioTrackType.original) return -1;
      if (b.type == AudioTrackType.original) return 1;
      return 0;
    });
    
    // Initialize with provided states
    _enabledTracks.addAll(widget.initialEnabledTracks);
    _trackVolumes.addAll(widget.initialTrackVolumes);
    
    // Initialize expansion state
    for (final track in _sortedTracks) {
      _expandedTracks[track.id] = false;
    }
    
    // Update original track enabled state
    final originalTrack = _sortedTracks.firstWhere(
      (t) => t.type == AudioTrackType.original,
      orElse: () => _sortedTracks.first,
    );
    _isOriginalEnabled = _enabledTracks[originalTrack.id] ?? false;
    
    _logCurrentlyPlayingTracks();
  }

  @override
  void didUpdateWidget(AudioTrackControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update states if they've changed
    if (oldWidget.initialEnabledTracks != widget.initialEnabledTracks) {
      _enabledTracks.clear();
      _enabledTracks.addAll(widget.initialEnabledTracks);
    }
    if (oldWidget.initialTrackVolumes != widget.initialTrackVolumes) {
      _trackVolumes.clear();
      _trackVolumes.addAll(widget.initialTrackVolumes);
    }
    
    // Update original track enabled state
    final originalTrack = _sortedTracks.firstWhere(
      (t) => t.type == AudioTrackType.original,
      orElse: () => _sortedTracks.first,
    );
    _isOriginalEnabled = _enabledTracks[originalTrack.id] ?? false;
  }

  void _logCurrentlyPlayingTracks() {
    final enabledTracks = widget.tracks.where((track) => _enabledTracks[track.id] == true);
    final trackInfo = enabledTracks.map((track) => 
      '${_getTrackLabel(track.type)} (volume: ${_trackVolumes[track.id]?.toStringAsFixed(2)})'
    ).join(', ');
    dev.log('Currently playing tracks: $trackInfo', name: 'AudioTrackControls');
  }

  void _handleTrackToggle(AudioTrack track) {
    if (track.type == AudioTrackType.original) {
      if (!_enabledTracks[track.id]!) {
        setState(() {
          for (final t in widget.tracks) {
            _enabledTracks[t.id] = t.id == track.id;
            _trackVolumes[t.id] = t.id == track.id ? 0.85 : 0.0;
          }
          _isOriginalEnabled = true;
        });
      }
    } else {
      setState(() {
        final isEnabled = _enabledTracks[track.id] ?? false;
        _enabledTracks[track.id] = !isEnabled;
        final nowEnabled = _enabledTracks[track.id] ?? false;
        _trackVolumes[track.id] = nowEnabled ? 0.85 : 0.0;
        
        final originalTrack = widget.tracks.firstWhere(
          (t) => t.type == AudioTrackType.original,
          orElse: () => widget.tracks.first,
        );
        _enabledTracks[originalTrack.id] = false;
        _trackVolumes[originalTrack.id] = 0.0;
        _isOriginalEnabled = false;
      });
    }
    
    widget.onTrackToggle(track.id, _enabledTracks[track.id]!);
    _logCurrentlyPlayingTracks();
  }

  void _handleVolumeChange(AudioTrack track, double volume) {
    setState(() => _trackVolumes[track.id] = volume);
    widget.onVolumeChange(track.id, volume);
    _logCurrentlyPlayingTracks();
  }

  void _toggleTrackExpansion(String trackId) {
    setState(() {
      _expandedTracks[trackId] = !(_expandedTracks[trackId] ?? false);
    });
  }

  String _getTrackLabel(AudioTrackType type) {
    switch (type) {
      case AudioTrackType.original:
        return 'Original Mix';
      case AudioTrackType.vocals:
        return 'Vocals';
      case AudioTrackType.drums:
        return 'Drums';
      case AudioTrackType.bass:
        return 'Bass';
      case AudioTrackType.other:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final expandedHeight = screenHeight * 0.4;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: widget.isExpanded ? expandedHeight : 0,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Audio Tracks',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: 24,
                  color: Colors.white,
                  onPressed: widget.onCollapse,
                ),
              ],
            ),
          ),
          // Track list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _sortedTracks.length,
              itemBuilder: (context, index) {
                final track = _sortedTracks[index];
                final isEnabled = _enabledTracks[track.id] ?? false;
                final volume = _trackVolumes[track.id] ?? 1.0;
                final isExpanded = _expandedTracks[track.id] ?? false;

                return AudioTrackItem(
                  track: track,
                  isEnabled: isEnabled,
                  volume: volume,
                  isExpanded: isExpanded,
                  onTrackToggle: (enabled) => _handleTrackToggle(track),
                  onVolumeChange: (volume) => _handleVolumeChange(track, volume),
                  onTap: () => _toggleTrackExpansion(track.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 