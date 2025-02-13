import 'package:flutter/material.dart';

class VideoComments extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onCollapse;

  const VideoComments({
    Key? key,
    required this.isExpanded,
    required this.onCollapse,
  }) : super(key: key);

  @override
  State<VideoComments> createState() => _VideoCommentsState();
}

class _VideoCommentsState extends State<VideoComments> {
  bool _isTopSelected = true;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final expandedHeight = screenHeight * 0.5;  // 50% of screen height

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
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: const [
                CommentItem(
                  username: '@2152mohamed',
                  timeAgo: '1h ago',
                  content: 'This is the only new outlet that I listen every morning. Thanks AMY',
                  likesCount: 85,
                  repliesCount: 2,
                  profileLetter: 'M',
                ),
                SizedBox(height: 16),
                CommentItem(
                  username: '@donaldmuhammad2411',
                  timeAgo: '1h ago',
                  content: 'this is the way news should be done!',
                  likesCount: 52,
                  repliesCount: 0,
                  profileLetter: 'D',
                ),
                SizedBox(height: 16),
                CommentItem(
                  username: '@annerfrancis',
                  timeAgo: '56 min ago',
                  content: 'Great content as always! Keep it up',
                  likesCount: 23,
                  repliesCount: 1,
                  profileLetter: 'A',
                ),
              ],
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
                  backgroundColor: Colors.pink,
                  radius: 18,
                  child: const Text(
                    'M',
                    style: TextStyle(
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
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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