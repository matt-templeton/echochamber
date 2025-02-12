import '../providers/video_feed_provider.dart';

abstract class ScreenState {
  void onEnter();
  void onExit();
}

class HomeScreenState implements ScreenState {
  final VideoFeedProvider provider;
  
  HomeScreenState(this.provider);
  
  @override
  void onEnter() {
    provider.setEnabled(true);
  }
  
  @override
  void onExit() {
    provider.setEnabled(false);
  }
}

class ProfileScreenState implements ScreenState {
  final VideoFeedProvider provider;
  
  ProfileScreenState(this.provider);
  
  @override
  void onEnter() {
    provider.setEnabled(false);
  }
  
  @override
  void onExit() {
    // No specific cleanup needed for profile screen
  }
}

class NavigationStateManager {
  static final NavigationStateManager _instance = NavigationStateManager._internal();
  factory NavigationStateManager() => _instance;
  NavigationStateManager._internal();

  ScreenState? _currentState;
  
  void navigateToScreen(ScreenState newState) {
    _currentState?.onExit();
    _currentState = newState;
    _currentState?.onEnter();
  }
} 