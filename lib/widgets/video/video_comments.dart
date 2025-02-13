import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as dev;
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
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  Comment? _selectedComment;  // Track which comment we're viewing replies for

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoComments oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If video changes, exit reply thread
    if (widget.videoId != oldWidget.videoId && _selectedComment != null) {
      setState(() => _selectedComment = null);
    }
  }

  void _showReplies(Comment comment) {
    setState(() => _selectedComment = comment);
  }

  void _hideReplies() {
    setState(() => _selectedComment = null);
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
      child: Stack(
        children: [
          // Main comments view
          AnimatedSlide(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            offset: _selectedComment != null ? const Offset(-1, 0) : Offset.zero,
            child: SizedBox(
              height: expandedHeight,
              child: SafeArea(
                bottom: false,  // Don't pad the bottom
                child: Column(
                  mainAxisSize: MainAxisSize.min,  // Only take needed space
                  children: [
                    // Header - fixed height
                    SizedBox(
                      height: 48,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    ),
                    // Comments list - takes remaining space
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
                              dev.log('Error in comments StreamBuilder: ${snapshot.error}', 
                                name: 'VideoComments', 
                                error: snapshot.error);
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Error loading comments',
                                      style: TextStyle(color: Colors.red[400]),
                                    ),
                                    if (snapshot.error.toString().contains('requires an index')) ...[
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Missing Firestore index',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ],
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

                            // Sort comments by most recent first
                            comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
                                  commentId: comment.id,
                                  videoId: widget.videoId,
                                  onReplyTap: () => _showReplies(comment),
                                  showReplyButton: true,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    // Comment input
                    _buildCommentInput(isAuthenticated, auth),
                  ],
                ),
              ),
            ),
          ),
          // Replies view
          if (_selectedComment != null)
            AnimatedSlide(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              offset: _selectedComment != null ? Offset.zero : const Offset(1, 0),
              child: SizedBox(
                height: expandedHeight,
                child: Material(
                  color: Colors.black,
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header - fixed height
                        SizedBox(
                          height: 48,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  color: Colors.white,
                                  onPressed: _hideReplies,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Replies',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Original comment
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: CommentItem(
                            username: '@${_selectedComment!.authorMetadata['name'] ?? 'user'}',
                            timeAgo: _getTimeAgo(_selectedComment!.createdAt),
                            content: _selectedComment!.text,
                            likesCount: _selectedComment!.likesCount,
                            repliesCount: _selectedComment!.repliesCount,
                            profileLetter: (_selectedComment!.authorMetadata['name'] as String?)?.isNotEmpty == true
                                ? (_selectedComment!.authorMetadata['name'] as String).characters.first.toUpperCase()
                                : 'U',
                            commentId: _selectedComment!.id,
                            videoId: widget.videoId,
                            showReplyButton: false,
                          ),
                        ),

                        // Replies list - takes remaining space
                        Expanded(
                          child: RawScrollbar(
                            thumbColor: Colors.white.withOpacity(0.2),
                            radius: const Radius.circular(20),
                            thickness: 4,
                            thumbVisibility: false,
                            trackVisibility: false,
                            child: StreamBuilder<List<Comment>>(
                              stream: VideoRepository().getCommentReplies(widget.videoId, _selectedComment!.id),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  dev.log('Error loading replies: ${snapshot.error}', name: 'CommentReplies');
                                  return const Center(
                                    child: Text(
                                      'No replies yet',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                  );
                                }

                                if (!snapshot.hasData) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                final replies = snapshot.data!;
                                if (replies.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      'No replies yet',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: replies.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    final reply = replies[index];
                                    return CommentItem(
                                      username: '@${reply.authorMetadata['name'] ?? 'user'}',
                                      timeAgo: _getTimeAgo(reply.createdAt),
                                      content: reply.text,
                                      likesCount: reply.likesCount,
                                      repliesCount: 0,
                                      profileLetter: (reply.authorMetadata['name'] as String?)?.isNotEmpty == true
                                          ? (reply.authorMetadata['name'] as String).characters.first.toUpperCase()
                                          : 'U',
                                      commentId: reply.id,
                                      videoId: widget.videoId,
                                      showReplyButton: false,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),

                        // Reply input
                        _buildCommentInput(isAuthenticated, auth),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(bool isAuthenticated, FirebaseAuth auth) {
    return Container(
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

class CommentItem extends StatefulWidget {
  final String username;
  final String timeAgo;
  final String content;
  final int likesCount;
  final int repliesCount;
  final String profileLetter;
  final String commentId;
  final String videoId;
  final VoidCallback? onReplyTap;
  final bool showReplyButton;

  const CommentItem({
    Key? key,
    required this.username,
    required this.timeAgo,
    required this.content,
    required this.likesCount,
    required this.repliesCount,
    required this.profileLetter,
    required this.commentId,
    required this.videoId,
    this.onReplyTap,
    this.showReplyButton = true,
  }) : super(key: key);

  @override
  State<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  bool _isLiked = false;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
  }

  Future<void> _checkIfLiked() async {
    final auth = context.read<FirebaseAuth>();
    final user = auth.currentUser;
    if (user == null) return;

    try {
      final repository = VideoRepository();
      final hasLiked = await repository.hasUserLikedComment(
        widget.videoId,
        widget.commentId,
        user.uid,
      );
      if (mounted) {
        setState(() => _isLiked = hasLiked);
      }
    } catch (e) {
      // Silently handle error
    }
  }

  Future<void> _toggleLike() async {
    final auth = context.read<FirebaseAuth>();
    final user = auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like comments')),
      );
      return;
    }

    if (_isLiking) return;

    setState(() => _isLiking = true);

    try {
      final repository = VideoRepository();
      if (_isLiked) {
        await repository.unlikeComment(widget.videoId, widget.commentId, user.uid);
      } else {
        await repository.likeComment(widget.videoId, widget.commentId, user.uid);
      }
      if (mounted) {
        setState(() => _isLiked = !_isLiked);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${_isLiked ? 'unlike' : 'like'} comment')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLiking = false);
      }
    }
  }

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
            widget.profileLetter,
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
                    widget.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.timeAgo,
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
                widget.content,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _CommentAction(
                    icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    label: widget.likesCount.toString(),
                    onTap: _toggleLike,
                    isLoading: _isLiking,
                  ),
                  const SizedBox(width: 16),
                  if (widget.showReplyButton)
                    _CommentAction(
                      icon: Icons.chat_bubble_outline,
                      label: widget.repliesCount > 0 ? '${widget.repliesCount} replies' : 'Reply',
                      onTap: widget.onReplyTap ?? () {},
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
  final bool isLoading;

  const _CommentAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          if (isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
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