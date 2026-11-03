
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/views/login_view.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Home Screen
    GoRoute(
      path: '/',
      builder: (context, state) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                context.go('/login');
              },
              child: const Text('Go to Login'),
            ),
          ),
        );
      },
    ),

    // Login Screen
    GoRoute(
      path: '/login',
      builder: (context, state) {
        return const LoginView();
      },
    ),
  ],
);
