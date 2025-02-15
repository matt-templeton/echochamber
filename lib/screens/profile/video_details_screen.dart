import 'package:flutter/material.dart';
import '../../models/video_model.dart';
import '../../repositories/video_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';

class VideoDetailsScreen extends StatefulWidget {
  final Video video;

  const VideoDetailsScreen({
    Key? key,
    required this.video,
  }) : super(key: key);

  @override
  State<VideoDetailsScreen> createState() => _VideoDetailsScreenState();
}

class _VideoDetailsScreenState extends State<VideoDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final VideoRepository _repository = VideoRepository();
  bool _isEditing = false;
  bool _isDeleting = false;
  bool _isSplittingAudio = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.video.title;
    _descriptionController.text = widget.video.description;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isEditing = true);

    try {
      await _repository.updateVideo(widget.video.id, {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'titleLower': _titleController.text.trim().toLowerCase(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video updated successfully')),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update video: $e')),
        );
        setState(() => _isEditing = false);
      }
    }
  }

  Future<void> _deleteVideo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: const Text(
          'Are you sure you want to delete this video? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      await _repository.deleteVideo(widget.video.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video deleted successfully')),
        );
        // Pop twice to go back to My Videos screen
        Navigator.of(context)
          ..pop() // Pop details screen
          ..pop(); // Pop My Videos screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete video: $e')),
        );
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _splitAudio() async {
    setState(() => _isSplittingAudio = true);

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('extract_audio_and_split');
      
      final result = await callable.call({
        'data': {
          'videoId': widget.video.id,
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio splitting process started')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start audio splitting: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSplittingAudio = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please sign in to view video details'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Details'),
        actions: [
          if (!_isDeleting)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteVideo,
              color: Colors.red,
            ),
        ],
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: widget.video.thumbnailUrl != null
                          ? Image.network(
                              widget.video.thumbnailUrl!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey[700],
                              child: const Center(
                                child: Icon(Icons.video_library, size: 40),
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        if (value.length < 3) {
                          return 'Title must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Stats
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Stats',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildStatRow(
                              'Views',
                              widget.video.viewsCount.toString(),
                              Icons.visibility,
                            ),
                            const SizedBox(height: 8),
                            _buildStatRow(
                              'Likes',
                              widget.video.likesCount.toString(),
                              Icons.favorite,
                            ),
                            const SizedBox(height: 8),
                            _buildStatRow(
                              'Comments',
                              widget.video.commentsCount.toString(),
                              Icons.comment,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Split Audio Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSplittingAudio ? null : _splitAudio,
                        icon: _isSplittingAudio 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.music_note),
                        label: const Text('Split Audio'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isEditing ? null : _saveChanges,
                        child: _isEditing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
} 