import 'package:flutter/material.dart';

class PrimaryNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const PrimaryNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: selectedIndex,
      onTap: onItemSelected,
      backgroundColor: Colors.black,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.grey[600],
      showSelectedLabels: true,
      showUnselectedLabels: true,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Friends',
        ),
        // Center add button with no label and larger icon
        BottomNavigationBarItem(
          icon: Container(
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(
              Icons.add,
              size: 32,
              color: Colors.white,
            ),
          ),
          label: '',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.chat),
          label: 'Input',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
} 