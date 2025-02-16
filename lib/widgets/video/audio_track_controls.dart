import 'package:flutter/material.dart';
import '../../models/audio_track_model.dart';
import 'dart:developer' as dev;

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

class _AudioTrackControlsState extends State<AudioTrackControls> {
  final Map<String, bool> _enabledTracks = {};
  final Map<String, double> _trackVolumes = {};
  bool _isOriginalEnabled = true;

  @override
  void initState() {
    super.initState();
    // Initialize track states
    for (final track in widget.tracks) {
      _enabledTracks[track.id] = track.type == AudioTrackType.original;
      _trackVolumes[track.id] = 1.0;
    }
    _logCurrentlyPlayingTracks();
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
      // If enabling original track, disable all others
      if (!_enabledTracks[track.id]!) {
        setState(() {
          for (final t in widget.tracks) {
            _enabledTracks[t.id] = t.id == track.id;
          }
          _isOriginalEnabled = true;
        });
      }
    } else {
      // If enabling any other track, disable original
      setState(() {
        _enabledTracks[track.id] = !_enabledTracks[track.id]!;
        
        // Find original track and disable it
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
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: widget.tracks.length,
              separatorBuilder: (context, index) => const Divider(color: Colors.white24),
              itemBuilder: (context, index) {
                final track = widget.tracks[index];
                final isEnabled = _enabledTracks[track.id] ?? false;
                final volume = _trackVolumes[track.id] ?? 1.0;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Track toggle
                        Switch(
                          value: isEnabled,
                          onChanged: (_) => _handleTrackToggle(track),
                          activeColor: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        // Track name
                        Expanded(
                          child: Text(
                            _getTrackLabel(track.type),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: isEnabled ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        // Volume icon
                        Icon(
                          volume > 0 ? Icons.volume_up : Icons.volume_off,
                          color: isEnabled ? Colors.white : Colors.white38,
                          size: 24,
                        ),
                      ],
                    ),
                    // Volume slider
                    if (isEnabled)
                      Slider(
                        value: volume,
                        onChanged: (value) => _handleVolumeChange(track, value),
                        activeColor: Colors.white,
                        inactiveColor: Colors.white24,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 