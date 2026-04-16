import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/dashboard_screen.dart';
import '../../features/login/login_screen.dart';
import '../../features/splash/splash_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    if (Firebase.apps.isEmpty) return null;

    final currentUser = FirebaseAuth.instance.currentUser;
    final path = state.uri.path;
    final isAuthRoute = path == '/' || path == '/login';
    final verified = currentUser?.emailVerified == true;

    if (verified && isAuthRoute) return '/dashboard';
    if (!verified && path == '/dashboard') return '/login';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
  ],
);
