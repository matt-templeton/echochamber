import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../repositories/video_repository.dart';
import '../../models/comment_model.dart';

class VideoComments extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onCollapse;
  final String videoId;

  const VideoComments({
    Key? key,
    required this.isExpanded,
    required this.onCollapse,
    required this.videoId,
  }) : super(key: key);

  @override
  State<VideoComments> createState() => _VideoCommentsState();
}

class _VideoCommentsState extends State<VideoComments> {
  bool _isTopSelected = true;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    final auth = context.read<FirebaseAuth>();
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      final repository = VideoRepository();
      await repository.addComment(widget.videoId, user.uid, text);
      
      if (mounted) {
        _commentController.clear();
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment added successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add comment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final expandedHeight = screenHeight * 0.5;
    final auth = context.watch<FirebaseAuth>();
    final isAuthenticated = auth.currentUser != null;

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
        children: [
          // Header
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[800]!,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Comments',
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
          // Filter tabs
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Top',
                  isSelected: _isTopSelected,
                  onTap: () => setState(() => _isTopSelected = true),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Newest',
                  isSelected: !_isTopSelected,
                  onTap: () => setState(() => _isTopSelected = false),
                ),
              ],
            ),
          ),
          // Comments list
          Expanded(
            child: RawScrollbar(
              thumbColor: Colors.white.withOpacity(0.2),
              radius: const Radius.circular(20),
              thickness: 4,
              thumbVisibility: false,
              trackVisibility: false,
              child: StreamBuilder<List<Comment>>(
                stream: VideoRepository().getVideoComments(widget.videoId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading comments',
                        style: TextStyle(color: Colors.red[400]),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final comments = snapshot.data!;
                  if (comments.isEmpty) {
                    return const Center(
                      child: Text(
                        'No comments yet',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }

                  // Sort comments based on selected filter
                  if (_isTopSelected) {
                    comments.sort((a, b) => b.likesCount.compareTo(a.likesCount));
                  } else {
                    comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: comments.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return CommentItem(
                        username: '@${comment.authorMetadata['name'] ?? 'user'}',
                        timeAgo: _getTimeAgo(comment.createdAt),
                        content: comment.text,
                        likesCount: comment.likesCount,
                        repliesCount: comment.repliesCount,
                        profileLetter: (comment.authorMetadata['name'] as String?)?.isNotEmpty == true
                            ? (comment.authorMetadata['name'] as String).characters.first.toUpperCase()
                            : 'U',
                      );
                    },
                  );
                },
              ),
            ),
          ),
          // Comment input
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(
                top: BorderSide(
                  color: Colors.grey[800]!,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isAuthenticated ? Colors.pink : Colors.grey[800],
                  radius: 18,
                  child: Text(
                    isAuthenticated 
                        ? (auth.currentUser?.displayName?.characters.first.toUpperCase() ?? 'U')
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    enabled: isAuthenticated && !_isSubmitting,
                    decoration: InputDecoration(
                      hintText: isAuthenticated 
                          ? 'Add a comment...'
                          : 'Sign in to comment',
                      hintStyle: TextStyle(
                        color: isAuthenticated ? Colors.grey : Colors.grey[700],
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: isAuthenticated ? (_) => _submitComment() : null,
                  ),
                ),
                if (isAuthenticated && _commentController.text.isNotEmpty)
                  IconButton(
                    icon: _isSubmitting 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send),
                    color: Colors.white,
                    onPressed: _isSubmitting ? null : _submitComment,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class CommentItem extends StatelessWidget {
  final String username;
  final String timeAgo;
  final String content;
  final int likesCount;
  final int repliesCount;
  final String profileLetter;

  const CommentItem({
    Key? key,
    required this.username,
    required this.timeAgo,
    required this.content,
    required this.likesCount,
    required this.repliesCount,
    required this.profileLetter,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile picture
        CircleAvatar(
          backgroundColor: Colors.grey[800],
          radius: 16,
          child: Text(
            profileLetter,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Comment content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    color: Colors.white,
                    iconSize: 16,
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _CommentAction(
                    icon: Icons.thumb_up_outlined,
                    label: likesCount.toString(),
                    onTap: () {},
                  ),
                  const SizedBox(width: 16),
                  _CommentAction(
                    icon: Icons.chat_bubble_outline,
                    label: repliesCount > 0 ? '$repliesCount replies' : 'Reply',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CommentAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
} 