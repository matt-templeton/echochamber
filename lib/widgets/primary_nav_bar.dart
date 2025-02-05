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
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.grey,
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
          icon: Icon(
            Icons.add_box,
            size: 32,
            color: Theme.of(context).primaryColor,
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