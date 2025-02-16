import 'package:flutter/material.dart';
import '../../models/audio_track_model.dart';
import 'dart:developer' as dev;

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

  const AudioTrackControls({
    Key? key,
    required this.tracks,
    required this.isExpanded,
    required this.onCollapse,
    required this.onTrackToggle,
    required this.onVolumeChange,
  }) : super(key: key);

  @override
  State<AudioTrackControls> createState() => _AudioTrackControlsState();
}

class _AudioTrackControlsState extends State<AudioTrackControls> with TickerProviderStateMixin {
  final Map<String, bool> _enabledTracks = {};
  final Map<String, double> _trackVolumes = {};
  final Map<String, bool> _expandedTracks = {};
  final Map<String, AnimationController> _volumeMeterControllers = {};
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
    
    for (final track in _sortedTracks) {
      _enabledTracks[track.id] = track.type == AudioTrackType.original;
      _trackVolumes[track.id] = 1.0;
      _expandedTracks[track.id] = false;
      
      // Make the animation faster and more dynamic
      _volumeMeterControllers[track.id] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 50),
      )..repeat(reverse: true);
    }
    _logCurrentlyPlayingTracks();
  }

  @override
  void dispose() {
    for (final controller in _volumeMeterControllers.values) {
      controller.dispose();
    }
    super.dispose();
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
          }
          _isOriginalEnabled = true;
        });
      }
    } else {
      setState(() {
        _enabledTracks[track.id] = !_enabledTracks[track.id]!;
        final originalTrack = widget.tracks.firstWhere(
          (t) => t.type == AudioTrackType.original,
          orElse: () => widget.tracks.first,
        );
        _enabledTracks[originalTrack.id] = false;
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

  IconData _getTrackIcon(AudioTrackType type) {
    switch (type) {
      case AudioTrackType.original:
        return Icons.music_note;
      case AudioTrackType.vocals:
        return Icons.mic;
      case AudioTrackType.drums:
        return Icons.album;
      case AudioTrackType.bass:
        return Icons.queue_music;
      case AudioTrackType.other:
        return Icons.piano;
    }
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

                return Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _toggleTrackExpansion(track.id),
                      borderRadius: BorderRadius.circular(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: isExpanded ? 88 : 36,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Track header (always visible)
                            SizedBox(
                              height: 36,
                              child: Row(
                                children: [
                                  const SizedBox(width: 8),
                                  Icon(
                                    _getTrackIcon(track.type),
                                    color: isEnabled ? Colors.white : Colors.white38,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _getTrackLabel(track.type),
                                      style: TextStyle(
                                        color: isEnabled ? Colors.white : Colors.white38,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isEnabled ? Icons.volume_up : Icons.volume_off,
                                      color: isEnabled ? Colors.white : Colors.white38,
                                      size: 18,
                                    ),
                                    onPressed: () => _handleTrackToggle(track),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Expanded controls with volume meter
                            if (isExpanded)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(34, 0, 8, 8),
                                child: Row(
                                  children: [
                                    const Spacer(),  // Push everything to the right
                                    SizedBox(
                                      width: 160,  // Increased from 120 to 160
                                      height: 36,
                                      child: Stack(
                                        children: [
                                          // Volume meter (background)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: SizedBox(
                                              height: 36,
                                              child: AnimatedBuilder(
                                                animation: _volumeMeterControllers[track.id]!,
                                                builder: (context, child) {
                                                  // Create a more dynamic level simulation
                                                  final baseLevel = _volumeMeterControllers[track.id]!.value;
                                                  // Make the level vary more dramatically
                                                  final level = isEnabled ? (baseLevel * baseLevel) : 0.0;
                                                  
                                                  return CustomPaint(
                                                    painter: VolumeMeterPainter(
                                                      level: level,
                                                      value: volume,
                                                      color: const Color(0xFF2EBD59),
                                                    ),
                                                    size: const Size.fromHeight(36),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                          // Volume slider overlay
                                          SizedBox(
                                            height: 36,
                                            child: SliderTheme(
                                              data: SliderTheme.of(context).copyWith(
                                                trackHeight: 8,  // Increased from 1
                                                trackShape: EmptyTrackShape(),
                                                thumbShape: const EmptyCircleThumbShape(radius: 6),
                                                overlayShape: const RoundSliderOverlayShape(
                                                  overlayRadius: 12,
                                                ),
                                                activeTrackColor: Colors.transparent,
                                                inactiveTrackColor: Colors.transparent,
                                                thumbColor: Colors.white,
                                                overlayColor: Colors.white.withOpacity(0.1),
                                              ),
                                              child: Slider(
                                                value: volume,
                                                onChanged: isEnabled 
                                                  ? (value) => _handleVolumeChange(track, value)
                                                  : null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 