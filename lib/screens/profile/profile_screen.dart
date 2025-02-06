import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../widgets/primary_nav_bar.dart';
import '../../widgets/sign_in_bottom_sheet.dart';
import '../../widgets/privacy_settings_sheet.dart';
import '../../widgets/notification_settings_sheet.dart';
import '../../services/firebase_service.dart';
import '../../repositories/user_repository.dart';
import '../home/home_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedIndex = 4; // Profile tab index
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _nameController = TextEditingController();
  final _twitterController = TextEditingController();
  final _instagramController = TextEditingController();
  final _youtubeController = TextEditingController();
  bool _isSaving = false;
  bool _isLoading = true;

  // Add regex patterns for social media validation
  static final RegExp _twitterUsernameRegex = RegExp(r'^@?[a-zA-Z0-9_]{1,15}$');
  static final RegExp _instagramUsernameRegex = RegExp(r'^@?[a-zA-Z0-9._]{1,30}$');
  static final RegExp _youtubeUrlRegex = RegExp(
    r'^(https?:\/\/)?(www\.)?(youtube\.com\/(c\/|channel\/|user\/)?|youtu\.be\/)[\w\-]{1,}$',
    caseSensitive: false,
  );

  String? _validateSocialMediaLink(String? value, String platform) {
    if (value == null || value.isEmpty) {
      return null; // Empty values are allowed
    }

    // Remove @ symbol if present for validation
    final cleanValue = value.startsWith('@') ? value.substring(1) : value;

    switch (platform) {
      case 'twitter':
        if (!_twitterUsernameRegex.hasMatch(cleanValue)) {
          return 'Invalid Twitter username';
        }
        break;
      case 'instagram':
        if (!_instagramUsernameRegex.hasMatch(cleanValue)) {
          return 'Invalid Instagram username';
        }
        break;
      case 'youtube':
        if (!_youtubeUrlRegex.hasMatch(value)) {
          return 'Invalid YouTube channel URL';
        }
        break;
    }
    return null;
  }

  // Helper method to clean social media values
  String _cleanSocialMediaValue(String value, String platform) {
    switch (platform) {
      case 'twitter':
      case 'instagram':
        // Ensure @ prefix for usernames
        return value.startsWith('@') ? value : '@$value';
      case 'youtube':
        // Ensure https:// prefix for YouTube URLs
        if (!value.startsWith('http://') && !value.startsWith('https://')) {
          return 'https://$value';
        }
        return value;
      default:
        return value;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userRepository = UserRepository();
      final userData = await userRepository.getUserById(user.uid);

      if (userData != null && mounted) {
        setState(() {
          _nameController.text = userData.name;
          _bioController.text = userData.bio ?? '';
          
          // Load social media links if they exist
          if (userData.socialMediaLinks != null) {
            _twitterController.text = userData.socialMediaLinks!['twitter'] ?? '';
            _instagramController.text = userData.socialMediaLinks!['instagram'] ?? '';
            _youtubeController.text = userData.socialMediaLinks!['youtube'] ?? '';
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load profile data')),
        );
        _isLoading = false;
      }
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _nameController.dispose();
    _twitterController.dispose();
    _instagramController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  void _showSignInSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SignInBottomSheet(showSignUpFirst: false),
    );
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a Photo'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512, // Reasonable size for profile pictures
        maxHeight: 512,
        imageQuality: 75, // Good quality while keeping file size down
      );

      if (image != null) {
        await _uploadProfilePicture(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick image')),
        );
      }
    }
  }

  Future<void> _uploadProfilePicture(File imageFile) async {
    try {
      final user = context.read<User?>();
      if (user == null) return;

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading profile picture...')),
        );
      }

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${user.uid}.jpg');
      
      await storageRef.putFile(imageFile);
      final downloadUrl = await storageRef.getDownloadURL();

      // Update user profile
      await user.updatePhotoURL(downloadUrl);
      
      // Update in Firestore
      final userRepository = UserRepository();
      await userRepository.updateUser(user.uid, {
        'profilePictureUrl': downloadUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile picture')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final authService = context.read<AuthService>();
    await authService.signOut();
  }

  // Add new method to save name changes
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Update Firebase Auth display name
      await user.updateDisplayName(_nameController.text.trim());

      // Prepare social media links - only include non-empty values
      final Map<String, String> socialMediaLinks = {};
      
      final twitterValue = _twitterController.text.trim();
      final instagramValue = _instagramController.text.trim();
      final youtubeValue = _youtubeController.text.trim();

      if (twitterValue.isNotEmpty) {
        socialMediaLinks['twitter'] = _cleanSocialMediaValue(twitterValue, 'twitter');
      }
      if (instagramValue.isNotEmpty) {
        socialMediaLinks['instagram'] = _cleanSocialMediaValue(instagramValue, 'instagram');
      }
      if (youtubeValue.isNotEmpty) {
        socialMediaLinks['youtube'] = _cleanSocialMediaValue(youtubeValue, 'youtube');
      }

      // Update Firestore user document
      final userRepository = UserRepository();
      await userRepository.updateUser(user.uid, {
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'socialMediaLinks': socialMediaLinks.isEmpty ? null : socialMediaLinks,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showPrivacySettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PrivacySettingsSheet(),
    );
  }

  void _showNotificationSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    final isAuthenticated = user != null;

    return Scaffold(
      body: isAuthenticated 
        ? _buildAuthenticatedProfile(user)
        : _buildUnauthenticatedProfile(),
      bottomNavigationBar: PrimaryNavBar(
        selectedIndex: _selectedIndex,
        onItemSelected: (index) {
          if (index != _selectedIndex) {
            if (index == 0) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const HomeScreen(),
                ),
              );
            }
            setState(() => _selectedIndex = index);
          }
        },
      ),
    );
  }

  Widget _buildUnauthenticatedProfile() {
    return Center(
      child: ElevatedButton(
        onPressed: _showSignInSheet,
        child: const Text('Sign In'),
      ),
    );
  }

  Widget _buildAuthenticatedProfile(User user) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Profile Picture Section
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: user.photoURL != null 
                      ? NetworkImage(user.photoURL!) 
                      : null,
                    child: user.photoURL == null 
                      ? const Icon(Icons.person, size: 60) 
                      : null,
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                      onPressed: _showImagePickerModal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter your name (2-50 characters)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  if (value.length < 2 || value.length > 50) {
                    return 'Name must be between 2 and 50 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Bio Field
              TextFormField(
                controller: _bioController,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Tell us about yourself (max 500 characters)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Social Media Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Social Media Links',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _twitterController,
                        decoration: const InputDecoration(
                          labelText: 'Twitter',
                          hintText: '@username',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: (value) => _validateSocialMediaLink(value, 'twitter'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _instagramController,
                        decoration: const InputDecoration(
                          labelText: 'Instagram',
                          hintText: '@username',
                          prefixIcon: Icon(Icons.camera_alt_outlined),
                        ),
                        validator: (value) => _validateSocialMediaLink(value, 'instagram'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _youtubeController,
                        decoration: const InputDecoration(
                          labelText: 'YouTube',
                          hintText: 'Channel URL',
                          prefixIcon: Icon(Icons.play_circle_outline),
                          helperText: 'Enter your full YouTube channel URL',
                        ),
                        validator: (value) => _validateSocialMediaLink(value, 'youtube'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Privacy Settings Button
              OutlinedButton.icon(
                onPressed: _showPrivacySettings,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Privacy Settings'),
              ),
              const SizedBox(height: 16),

              // Notification Settings Button
              OutlinedButton.icon(
                onPressed: _showNotificationSettings,
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Notification Settings'),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () {
                      // Reset the name field to current value
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        _nameController.text = user.displayName ?? '';
                      }
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    child: _isSaving 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Sign Out Button
              TextButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
} 