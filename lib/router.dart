import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as firebase_ui;

import 'services/application_state.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/auth/auth_screen.dart';

// Make navigation keys static to prevent duplication
final class RouterKeys {
  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final shellNavigatorKey = GlobalKey<NavigatorState>();
  
  // Private constructor to prevent instantiation
  RouterKeys._();
}

GoRouter createRouter() {
  return GoRouter(
    navigatorKey: RouterKeys.rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final appState = Provider.of<ApplicationState>(context, listen: false);
      final isLoggingIn = state.matchedLocation == '/sign-in';
      
      // Don't redirect if we're already going where we need to
      if (!appState.loggedIn && isLoggingIn) return null;
      if (appState.loggedIn && !isLoggingIn) return null;

      // Otherwise, send to appropriate location
      return appState.loggedIn ? '/' : '/sign-in';
    },
    routes: [
      // Shell route for bottom navigation
      ShellRoute(
        navigatorKey: RouterKeys.shellNavigatorKey,
        builder: (context, state, child) {
          return child;
        },
        routes: [
          // Home route
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          // Profile route
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      // Authentication routes
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) {
          final arguments = state.uri.queryParameters;
          return firebase_ui.ForgotPasswordScreen(
            email: arguments['email'],
            headerBuilder: (context, constraints, shrinkOffset) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset('assets/images/logo.png'),
                ),
              );
            },
          );
        },
      ),
    ],
  );
} 