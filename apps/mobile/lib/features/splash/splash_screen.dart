import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _routeAfterBootstrap();
  }

  Future<void> _routeAfterBootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    if (Firebase.apps.isEmpty) {
      context.go('/login');
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      context.go('/login');
      return;
    }

    try {
      await currentUser.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser?.emailVerified == true) {
        await refreshedUser!.getIdToken(true);
        if (mounted) context.go('/dashboard');
      } else if (mounted) {
        context.go('/login');
      }
    } catch (_) {
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mosque, size: 72, color: Color(0xFF13896F)),
            SizedBox(height: 18),
            Text(
              'Masjid Manager',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 8),
            Text('Realtime mosque management'),
          ],
        ),
      ),
    );
  }
}
