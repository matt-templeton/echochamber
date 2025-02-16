import 'package:flutter/material.dart';
import '../../models/audio_track_model.dart';

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

// Add custom track shape that's completely transparent and extends to edges
class ExtendedTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 0;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

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
    // Don't paint anything - we'll handle it in the meter painter
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

class AudioTrackItem extends StatefulWidget {
  final AudioTrack track;
  final bool isEnabled;
  final double volume;
  final bool isExpanded;
  final Function(bool enabled) onTrackToggle;
  final Function(double volume) onVolumeChange;
  final VoidCallback onTap;

  const AudioTrackItem({
    Key? key,
    required this.track,
    required this.isEnabled,
    required this.volume,
    required this.isExpanded,
    required this.onTrackToggle,
    required this.onVolumeChange,
    required this.onTap,
  }) : super(key: key);

  @override
  State<AudioTrackItem> createState() => _AudioTrackItemState();
}

class _AudioTrackItemState extends State<AudioTrackItem> with SingleTickerProviderStateMixin {
  late final AnimationController _volumeMeterController;

  @override
  void initState() {
    super.initState();
    _volumeMeterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _volumeMeterController.dispose();
    super.dispose();
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
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: widget.isExpanded ? 88 : 36,
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
                        _getTrackIcon(widget.track.type),
                        color: widget.isEnabled ? Colors.white : Colors.white38,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getTrackLabel(widget.track.type),
                          style: TextStyle(
                            color: widget.isEnabled ? Colors.white : Colors.white38,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          widget.isEnabled ? Icons.volume_up : Icons.volume_off,
                          color: widget.isEnabled ? Colors.white : Colors.white38,
                          size: 18,
                        ),
                        onPressed: () => widget.onTrackToggle(!widget.isEnabled),
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
                if (widget.isExpanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(34, 0, 8, 8),
                    child: Row(
                      children: [
                        const Spacer(),  // Push everything to the right
                        SizedBox(
                          width: 160,
                          height: 36,
                          child: Stack(
                            children: [
                              // Volume meter (background)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: SizedBox(
                                  height: 36,
                                  child: AnimatedBuilder(
                                    animation: _volumeMeterController,
                                    builder: (context, child) {
                                      // Create a more dynamic level simulation
                                      final baseLevel = _volumeMeterController.value;
                                      // Make the level vary more dramatically
                                      final level = widget.isEnabled ? (baseLevel * baseLevel) : 0.0;
                                      
                                      return CustomPaint(
                                        painter: VolumeMeterPainter(
                                          level: level,
                                          value: widget.isEnabled ? widget.volume : 0.0,
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
                                    trackHeight: 8,
                                    trackShape: ExtendedTrackShape(),
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
                                    value: widget.isEnabled ? widget.volume : 0.0,
                                    onChanged: (value) {
                                      // If track is disabled and user starts dragging, enable it
                                      if (!widget.isEnabled && value > 0) {
                                        widget.onTrackToggle(true);
                                      }
                                      // If volume reaches 0, mute the track
                                      else if (widget.isEnabled && value == 0) {
                                        widget.onTrackToggle(false);
                                      }
                                      widget.onVolumeChange(value);
                                    },
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
  }
} 