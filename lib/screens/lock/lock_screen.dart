import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../services/auth_service.dart';
import '../../services/cycle_repository.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _error = '';
  bool _checkingBiometric = false;

  @override
  void initState() {
    super.initState();
    _tryBiometricOnLaunch();
  }

  Future<void> _tryBiometricOnLaunch() async {
    final settings = CycleRepository.getSettings();
    if (settings.biometricEnabled) {
      setState(() => _checkingBiometric = true);
      final success = await AuthService.authenticateWithBiometrics();
      setState(() => _checkingBiometric = false);
      if (success && mounted) {
        _goHome();
      }
    }
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _onCompleted(String pin) async {
    final valid = await AuthService.verifyPin(pin);
    if (valid) {
      _goHome();
    } else {
      setState(() => _error = 'Incorrect PIN — try again');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                child: Icon(Icons.favorite_rounded, color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 24),
              Text('Welcome back',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Enter your PIN to continue',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              if (_checkingBiometric)
                CircularProgressIndicator(color: AppColors.primary)
              else
                PinCodeTextField(
                  appContext: context,
                  length: 4,
                  obscureText: true,
                  animationType: AnimationType.scale,
                  keyboardType: TextInputType.number,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(12),
                    fieldHeight: 56,
                    fieldWidth: 56,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.divider,
                    selectedColor: AppColors.primaryDark,
                    activeFillColor: AppColors.cardBackground,
                    inactiveFillColor: AppColors.cardBackground,
                    selectedFillColor: AppColors.cardBackground,
                  ),
                  onChanged: (_) {},
                  onCompleted: _onCompleted,
                ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error, style: TextStyle(color: AppColors.concern)),
              ],
              const SizedBox(height: 16),
              FutureBuilder<bool>(
                future: AuthService.canCheckBiometrics(),
                builder: (context, snapshot) {
                  final settings = CycleRepository.getSettings();
                  if (snapshot.data == true && settings.biometricEnabled) {
                    return TextButton.icon(
                      onPressed: _tryBiometricOnLaunch,
                      icon: Icon(Icons.fingerprint, color: AppColors.primary),
                      label: const Text('Use biometric unlock'),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
