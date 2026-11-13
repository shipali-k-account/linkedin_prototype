
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/views/signup_view.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/auth/views/home_view.dart';
import '../../features/auth/views/profile_view.dart';
import '../../features/auth/views/public_profile_view.dart';
import '../../features/auth/views/edit_profile_view.dart';
import '../../features/auth/views/add_education_view.dart';
import '../../features/auth/views/add_experience_view.dart';
import '../../features/auth/views/add_skills_view.dart';
import '../../features/auth/views/create_post_view.dart';
import '../../features/auth/views/jobs_view.dart';

class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier() {
    _subscription = FirebaseAuth.instance
        .authStateChanges()
        .listen((user) {
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final authRefreshNotifier = AuthRefreshNotifier();

final GoRouter appRouter = GoRouter(
  initialLocation: '/signup',
  refreshListenable: authRefreshNotifier,

  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;

    final isLogin = state.matchedLocation == '/login';
    final isSignup = state.matchedLocation == '/signup';

    if (user == null) {
      if (isLogin || isSignup) {
        return null;
      }
      return '/login';
    }

    if (isLogin || isSignup) {
      return '/home';
    }

    return null;
  },

  routes: [
    // Root route
    GoRoute(
      path: '/',
      redirect: (context, state) {
        final user = FirebaseAuth.instance.currentUser;
        return user != null ? '/home' : '/login';
      },
    ),

    // Signup
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupView(),
    ),

    // Login
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginView(),
    ),

    // Home
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeView(),
    ),

    // My Profile
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileView(),
    ),

    // View another user's profile
    GoRoute(
      path: '/user-profile/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;

        return PublicProfileView(
          userId: userId,
        );
      },
    ),

    // Create or Edit Profile
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};

        return EditProfileView(
          name: data['name'] ?? '',
          headline: data['headline'] ?? '',
          about: data['about'] ?? '',
          isEditing: data['isEditing'] ?? false,
        );
      },
    ),

    // Add Education
    GoRoute(
      path: '/add-education',
      builder: (context, state) => const AddEducationView(),
    ),

    // Add Experience
    GoRoute(
      path: '/add-experience',
      builder: (context, state) => const AddExperienceView(),
    ),

    // Add Skills
    GoRoute(
      path: '/add-skills',
      builder: (context, state) => const AddSkillsView(),
    ),

    // Create Post
    GoRoute(
      path: '/create-post',
      builder: (context, state) => const CreatePostView(),
    ),

    // Jobs
    GoRoute(
      path: '/jobs',
      builder: (context, state) => const JobsView(),
    ),
  ],
);
