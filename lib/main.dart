import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'services/cycle_repository.dart';
import 'services/auth_service.dart';
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
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        return snapshot.data!;
      },
    );
  }
}
