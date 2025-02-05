import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/application_state.dart';
import '../../widgets/primary_nav_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedIndex = 4; // Profile tab index

  @override
  Widget build(BuildContext context) {
    return Consumer<ApplicationState>(
      builder: (context, appState, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // User Icon or Photo
              if (appState.appUser?.photoUrl != null)
                CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(appState.appUser!.photoUrl!),
                )
              else
                const Icon(
                  Icons.account_circle,
                  size: 100,
                  color: Colors.grey,
                ),
              const SizedBox(height: 24),
              // User Info or Sign In Button
              if (appState.loggedIn) ...[
                Text(
                  appState.appUser?.name ?? 'No name',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  appState.appUser?.email ?? 'No email',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                if (!appState.emailVerified)
                  const Text(
                    'Please verify your email',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                  ),
                ElevatedButton(
                  onPressed: () => appState.signOut(),
                  child: const Text('Sign Out'),
                ),
              ] else
                ElevatedButton(
                  onPressed: () => context.go('/sign-in'),
                  child: const Text('Sign In'),
                ),
            ],
          ),
        ),
        bottomNavigationBar: PrimaryNavBar(
          selectedIndex: _selectedIndex,
          onItemSelected: (index) {
            if (index != _selectedIndex) {
              if (index == 0) {
                context.go('/');
              }
              setState(() => _selectedIndex = index);
            }
          },
        ),
      ),
    );
  }
} 