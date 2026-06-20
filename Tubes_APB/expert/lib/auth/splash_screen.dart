import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../admin/dashboard_admin.dart';
import '../data/app_session_service.dart';
import '../user/dashboard.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _minimumSplashDuration = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();
    _openLoginWhenReady();
  }

  Future<void> _openLoginWhenReady() async {
    await Future.wait([
      _ensureFirebaseReady(),
      Future<void>.delayed(_minimumSplashDuration),
    ]);

    if (!mounted) return;
    final restoredSession = await AppSessionService().restore();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            _screenForSession(restoredSession),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final scaleTween = Tween<double>(begin: 1.08, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOutCubic));
          final fadeTween = Tween<double>(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn));

          return ScaleTransition(
            scale: animation.drive(scaleTween),
            child: FadeTransition(
              opacity: animation.drive(fadeTween),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  Widget _screenForSession(RestoredAppSession? session) {
    if (session?.role == AppSessionRole.admin) {
      return const DashboardAdminPage();
    }
    if (session?.role == AppSessionRole.user) {
      return const DashboardScreen();
    }
    return const LoginScreen();
  }

  Future<void> _ensureFirebaseReady() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (error) {
      debugPrint('Firebase init skipped: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Gambar Logo dari assets
            Image.asset(
              'assets/logo.jpeg',
              width: 250,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Text(
                    'Mohon masukkan gambar ke assets/logo.jpeg\natau sesuaikan nama file',
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
