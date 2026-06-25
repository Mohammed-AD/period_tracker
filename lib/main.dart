import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'services/cycle_repository.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/register/register_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await CycleRepository.init();
  try {
    await NotificationService.init();
  } catch (e) {
    // Reminders are a nice-to-have, not core to the app — if notification
    // setup fails on a particular device/OS version, the rest of Bloom
    // (logging periods, tracking, insights) must still work normally.
    debugPrint('NotificationService.init failed (non-fatal): $e');
  }
  // Apply the user's saved theme before the first frame so there's no
  // flash of the default palette.
  ThemeController.instance.initialize(CycleRepository.getSettings().themeName);
  runApp(const BloomApp());
}

class BloomApp extends StatelessWidget {
  const BloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds with a fresh ThemeData whenever ThemeController.select() is
    // called anywhere in the app (e.g. from the Profile appearance picker).
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Bloom',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeFor(ThemeController.instance.active),
          home: const _RootRouter(),
        );
      },
    );
  }
}

/// Decides which screen to show first based on saved app state:
/// 1. No PIN set yet (first ever launch) -> RegisterScreen (name + create PIN)
/// 2. PIN exists + lock enabled -> LoginScreen (enter PIN / biometric)
/// 3. PIN exists but lock disabled, or already unlocked this session -> Home
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  Future<Widget> _decide() async {
    final hasPin = await AuthService.hasPin();
    if (!hasPin) {
      return const RegisterScreen();
    }
    final settings = CycleRepository.getSettings();
    if (settings.lockEnabled) {
      return const LoginScreen();
    }
    return const HomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _decide(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _LoadingScreen();
        }
        return snapshot.data!;
      },
    );
  }
}

/// Branded loading state shown briefly while we decide which screen to
/// open first (checking for a saved PIN, reading settings). A gently
/// pulsing version of the app mark reads calmer here than a plain spinner.
class _LoadingScreen extends StatefulWidget {
  const _LoadingScreen();

  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final scale = 0.9 + (_controller.value * 0.15);
            return Opacity(
              opacity: 0.6 + (_controller.value * 0.4),
              child: Transform.scale(
                scale: scale,
                child: Icon(Icons.local_florist_rounded, size: 56, color: AppColors.primary),
              ),
            );
          },
        ),
      ),
    );
  }
}
