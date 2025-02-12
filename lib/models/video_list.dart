// import 'package:flutter/foundation.dart';
// import 'video_model.dart';
// import 'dart:developer' as dev;

// /// Event emitted when a video is added to the list
// class VideoAddedEvent {
//   final Video video;
//   final int index;

//   VideoAddedEvent(this.video, this.index);
// }

// /// Manages a list of videos with a maximum length
// class VideoList extends ChangeNotifier {
//   final int maxLength;
//   final List<Video> _videos = [];
//   int _currentIndex = 0;

//   VideoList({required this.maxLength}) : assert(maxLength > 0, 'maxLength must be greater than 0');

//   // Getters
//   List<Video> get videos => List.unmodifiable(_videos);
//   int get length => _videos.length;
//   bool get isFull => _videos.length >= maxLength;
//   int get currentIndex => _currentIndex;
//   Video? get currentVideo => _currentIndex < _videos.length ? _videos[_currentIndex] : null;

//   /// Adds a video to the list if not at max length
//   /// Returns true if video was added, false if list is full
//   bool addVideo(Video video) {
//     if (isFull) {
//       dev.log('Cannot add video ${video.id}: list is full (max: $maxLength)', name: 'VideoList');
//       dev.log('Current videos in list: ${_videos.map((v) => v.id).join(", ")}', name: 'VideoList');
//       return false;
//     }

//     // Check for duplicates
//     if (_videos.any((v) => v.id == video.id)) {
//       dev.log('Video ${video.id} already exists in list', name: 'VideoList');
//       dev.log('Current videos in list: ${_videos.map((v) => v.id).join(", ")}', name: 'VideoList');
//       return false;
//     }

//     _videos.add(video);
//     dev.log('Added video ${video.id} to list. Total videos: ${_videos.length}', name: 'VideoList');
//     dev.log('Current videos in list: ${_videos.map((v) => v.id).join(", ")}', name: 'VideoList');
//     dev.log('Current index: $_currentIndex', name: 'VideoList');
//     notifyListeners();
//     return true;
//   }

//   /// Gets the next video in the list
//   /// Returns null if at the end of the list
//   Video? getNextVideo() {
//     if (_currentIndex >= _videos.length - 1) {
//       dev.log('No next video available: at end of list', name: 'VideoList');
//       return null;
//     }
//     dev.log('Getting next video: ${_videos[_currentIndex + 1].id}', name: 'VideoList');
//     return _videos[_currentIndex + 1];
//   }

//   /// Gets the previous video in the list
//   /// Returns null if at the start of the list
//   Video? getPreviousVideo() {
//     if (_currentIndex <= 0) {
//       dev.log('No previous video available: at start of list', name: 'VideoList');
//       return null;
//     }
//     dev.log('Getting previous video: ${_videos[_currentIndex - 1].id}', name: 'VideoList');
//     return _videos[_currentIndex - 1];
//   }

//   /// Moves to the next video if possible
//   /// Returns true if moved, false if at end of list
//   bool moveToNext() {
//     if (_currentIndex >= _videos.length - 1) {
//       dev.log('Cannot move to next: already at end of list', name: 'VideoList');
//       dev.log('Current index: $_currentIndex, List length: ${_videos.length}', name: 'VideoList');
//       return false;
//     }
//     _currentIndex++;
//     dev.log('----------------------------------------', name: 'VideoList');
//     dev.log('Moved to next video. New index: $_currentIndex', name: 'VideoList');
//     dev.log('Current video ID: ${_videos[_currentIndex].id}', name: 'VideoList');
//     dev.log('All videos in list: ${_videos.map((v) => v.id).join(", ")}', name: 'VideoList');
//     dev.log('----------------------------------------', name: 'VideoList');
//     notifyListeners();
//     return true;
//   }

//   /// Moves to the previous video if possible
//   /// Returns true if moved, false if at start of list
//   bool moveToPrevious() {
//     if (_currentIndex <= 0) {
//       dev.log('Cannot move to previous: already at start of list', name: 'VideoList');
//       dev.log('Current index: $_currentIndex, List length: ${_videos.length}', name: 'VideoList');
//       return false;
//     }
//     _currentIndex--;
//     dev.log('----------------------------------------', name: 'VideoList');
//     dev.log('Moved to previous video. New index: $_currentIndex', name: 'VideoList');
//     dev.log('Current video ID: ${_videos[_currentIndex].id}', name: 'VideoList');
//     dev.log('All videos in list: ${_videos.map((v) => v.id).join(", ")}', name: 'VideoList');
//     dev.log('----------------------------------------', name: 'VideoList');
//     notifyListeners();
//     return true;
//   }

//   /// Checks if there is a next video available
//   bool hasNext() => _currentIndex < _videos.length - 1;

//   /// Checks if there is a previous video available
//   bool hasPrevious() => _currentIndex > 0;

//   /// Gets a video at a specific index
//   /// Returns null if index is out of bounds
//   Video? getVideoAt(int index) {
//     if (index < 0 || index >= _videos.length) {
//       return null;
//     }
//     return _videos[index];
//   }

//   /// Updates a video at a specific index
//   /// Returns true if update was successful, false if index is out of bounds
//   bool updateVideo(int index, Video video) {
//     if (index < 0 || index >= _videos.length) {
//       dev.log('Cannot update video: index $index out of bounds', name: 'VideoList');
//       return false;
//     }
//     _videos[index] = video;
//     dev.log('Updated video at index $index: ${video.id}', name: 'VideoList');
//     notifyListeners();
//     return true;
//   }

//   /// Clears the list and resets the current index
//   void clear() {
//     _videos.clear();
//     _currentIndex = 0;
//     notifyListeners();
//   }
// } 