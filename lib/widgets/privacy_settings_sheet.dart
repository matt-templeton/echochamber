import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/user_repository.dart';

class PrivacySettingsSheet extends StatefulWidget {
  const PrivacySettingsSheet({super.key});

  @override
  State<PrivacySettingsSheet> createState() => _PrivacySettingsSheetState();
}

class _PrivacySettingsSheetState extends State<PrivacySettingsSheet> {
  final _userRepository = UserRepository();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Privacy settings
  bool _isPrivateAccount = false;
  String _commentPermissions = 'everyone';
  String _dmPermissions = 'everyone';
  bool _allowDuets = true;
  List<String> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userData = await _userRepository.getUserById(user.uid);
      if (userData?.privacySettings != null && mounted) {
        final settings = userData!.privacySettings!;
        setState(() {
          _isPrivateAccount = settings['isPrivateAccount'] ?? false;
          _commentPermissions = settings['commentPermissions'] ?? 'everyone';
          _dmPermissions = settings['dmPermissions'] ?? 'everyone';
          _allowDuets = settings['allowDuets'] ?? true;
          _blockedUsers = List<String>.from(settings['blockedUsers'] ?? []);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load privacy settings';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePrivacySettings() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final privacySettings = {
        'isPrivateAccount': _isPrivateAccount,
        'commentPermissions': _commentPermissions,
        'dmPermissions': _dmPermissions,
        'allowDuets': _allowDuets,
        'blockedUsers': _blockedUsers,
      };

      await _userRepository.updateUser(user.uid, {
        'privacySettings': privacySettings,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save privacy settings';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Privacy Settings',
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
          const SizedBox(height: 24),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            // Account Privacy Toggle
            SwitchListTile(
              title: const Text('Private Account'),
              subtitle: const Text('Only approved followers can see your content'),
              value: _isPrivateAccount,
              onChanged: (value) => setState(() => _isPrivateAccount = value),
            ),
            const Divider(),

            // Comment Permissions Dropdown
            ListTile(
              title: const Text('Comment Permissions'),
              subtitle: DropdownButton<String>(
                value: _commentPermissions,
                isExpanded: true,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _commentPermissions = value);
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: 'everyone',
                    child: Text('Everyone'),
                  ),
                  DropdownMenuItem(
                    value: 'followers',
                    child: Text('Followers Only'),
                  ),
                  DropdownMenuItem(
                    value: 'none',
                    child: Text('No One'),
                  ),
                ],
              ),
            ),
            const Divider(),

            // DM Permissions Dropdown
            ListTile(
              title: const Text('Direct Message Permissions'),
              subtitle: DropdownButton<String>(
                value: _dmPermissions,
                isExpanded: true,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _dmPermissions = value);
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: 'everyone',
                    child: Text('Everyone'),
                  ),
                  DropdownMenuItem(
                    value: 'followers',
                    child: Text('Followers Only'),
                  ),
                  DropdownMenuItem(
                    value: 'none',
                    child: Text('No One'),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Duet/Collaboration Toggle
            SwitchListTile(
              title: const Text('Allow Duets'),
              subtitle: const Text('Let others create duets with your videos'),
              value: _allowDuets,
              onChanged: (value) => setState(() => _allowDuets = value),
            ),
            const Divider(),

            // Block List
            ListTile(
              title: const Text('Blocked Users'),
              subtitle: Text(
                _blockedUsers.isEmpty
                    ? 'No blocked users'
                    : '${_blockedUsers.length} blocked',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Implement blocked users management screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Block list management coming soon'),
                  ),
                );
              },
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
                  onPressed: _isSaving ? null : _savePrivacySettings,
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
    );
  }
} 