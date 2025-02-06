import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/user_repository.dart';

class NotificationSettingsSheet extends StatefulWidget {
  const NotificationSettingsSheet({super.key});

  @override
  State<NotificationSettingsSheet> createState() => _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<NotificationSettingsSheet> {
  final _userRepository = UserRepository();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Notification settings
  bool _likesNotifications = true;
  bool _commentNotifications = true;
  bool _followerNotifications = true;
  bool _dmNotifications = true;
  bool _collaborationNotifications = true;
  bool _processingNotifications = true;
  Map<String, bool> _emailPreferences = {
    'weekly_digest': true,
    'marketing': false,
    'collaboration_requests': true,
    'account_updates': true,
  };

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userData = await _userRepository.getUserById(user.uid);
      if (userData?.notificationSettings != null && mounted) {
        final settings = userData!.notificationSettings!;
        setState(() {
          _likesNotifications = settings['likes'] ?? true;
          _commentNotifications = settings['comments'] ?? true;
          _followerNotifications = settings['followers'] ?? true;
          _dmNotifications = settings['direct_messages'] ?? true;
          _collaborationNotifications = settings['collaborations'] ?? true;
          _processingNotifications = settings['video_processing'] ?? true;
          _emailPreferences = Map<String, bool>.from(
            settings['email_preferences'] ?? {
              'weekly_digest': true,
              'marketing': false,
              'collaboration_requests': true,
              'account_updates': true,
            },
          );
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load notification settings';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveNotificationSettings() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final notificationSettings = {
        'likes': _likesNotifications,
        'comments': _commentNotifications,
        'followers': _followerNotifications,
        'direct_messages': _dmNotifications,
        'collaborations': _collaborationNotifications,
        'video_processing': _processingNotifications,
        'email_preferences': _emailPreferences,
      };

      await _userRepository.updateUser(user.uid, {
        'notificationSettings': notificationSettings,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save notification settings';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header - Keep this outside of scroll view
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notification Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Content - Make this scrollable
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      // Push Notification Settings
                      const Text(
                        'Push Notifications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Like Notifications
                      SwitchListTile(
                        title: const Text('Likes'),
                        subtitle: const Text('Get notified when someone likes your content'),
                        value: _likesNotifications,
                        onChanged: (value) => setState(() => _likesNotifications = value),
                      ),
                      const Divider(),

                      // Comment Notifications
                      SwitchListTile(
                        title: const Text('Comments'),
                        subtitle: const Text('Get notified when someone comments on your content'),
                        value: _commentNotifications,
                        onChanged: (value) => setState(() => _commentNotifications = value),
                      ),
                      const Divider(),

                      // Follower Notifications
                      SwitchListTile(
                        title: const Text('New Followers'),
                        subtitle: const Text('Get notified when someone follows you'),
                        value: _followerNotifications,
                        onChanged: (value) => setState(() => _followerNotifications = value),
                      ),
                      const Divider(),

                      // Direct Message Notifications
                      SwitchListTile(
                        title: const Text('Direct Messages'),
                        subtitle: const Text('Get notified when you receive a direct message'),
                        value: _dmNotifications,
                        onChanged: (value) => setState(() => _dmNotifications = value),
                      ),
                      const Divider(),

                      // Collaboration Request Notifications
                      SwitchListTile(
                        title: const Text('Collaboration Requests'),
                        subtitle: const Text('Get notified about collaboration opportunities'),
                        value: _collaborationNotifications,
                        onChanged: (value) => setState(() => _collaborationNotifications = value),
                      ),
                      const Divider(),

                      // Video Processing Notifications
                      SwitchListTile(
                        title: const Text('Video Processing'),
                        subtitle: const Text('Get notified when your video processing is complete'),
                        value: _processingNotifications,
                        onChanged: (value) => setState(() => _processingNotifications = value),
                      ),
                      const Divider(),

                      // Email Preferences Section
                      const SizedBox(height: 16),
                      const Text(
                        'Email Notifications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Weekly Digest
                      SwitchListTile(
                        title: const Text('Weekly Digest'),
                        subtitle: const Text('Receive a weekly summary of your activity'),
                        value: _emailPreferences['weekly_digest'] ?? true,
                        onChanged: (value) => setState(() => 
                          _emailPreferences['weekly_digest'] = value
                        ),
                      ),
                      const Divider(),

                      // Marketing Emails
                      SwitchListTile(
                        title: const Text('Marketing Emails'),
                        subtitle: const Text('Receive updates about new features and promotions'),
                        value: _emailPreferences['marketing'] ?? false,
                        onChanged: (value) => setState(() => 
                          _emailPreferences['marketing'] = value
                        ),
                      ),
                      const Divider(),

                      // Collaboration Request Emails
                      SwitchListTile(
                        title: const Text('Collaboration Requests'),
                        subtitle: const Text('Receive emails about collaboration opportunities'),
                        value: _emailPreferences['collaboration_requests'] ?? true,
                        onChanged: (value) => setState(() => 
                          _emailPreferences['collaboration_requests'] = value
                        ),
                      ),
                      const Divider(),

                      // Account Updates
                      SwitchListTile(
                        title: const Text('Account Updates'),
                        subtitle: const Text('Receive important updates about your account'),
                        value: _emailPreferences['account_updates'] ?? true,
                        onChanged: (value) => setState(() => 
                          _emailPreferences['account_updates'] = value
                        ),
                      ),
                      const Divider(),

                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),

                      // Save Button
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveNotificationSettings,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Save Changes'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 