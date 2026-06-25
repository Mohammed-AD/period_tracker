import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:bloom_cycle/services/auth_service.dart';
import 'package:bloom_cycle/services/cycle_repository.dart';
import 'package:bloom_cycle/theme/app_theme.dart';
import 'package:bloom_cycle/screens/home/home_screen.dart';

/// Shown every time a registered user reopens the app (if lock is enabled).
/// PIN entry plus a visible fingerprint/biometric icon button.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _error = '';
  bool _checkingBiometric = false;
  bool _biometricAvailable = false;
  late TextEditingController _pinController;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    // We own this controller (it's passed into PinCodeTextField), so we
    // must dispose it ourselves -- the field is never unmounted while this
    // screen is alive (see build()), so this is the only place it happens.
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    final settings = CycleRepository.getSettings();
    final canCheck = await AuthService.canCheckBiometrics();
    if (mounted) {
      setState(() => _biometricAvailable = canCheck && settings.biometricEnabled);
    }
    // Auto-prompt biometric once on launch for convenience.
    if (_biometricAvailable) {
      _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    setState(() => _checkingBiometric = true);
    final success = await AuthService.authenticateWithBiometrics();
    if (!mounted) return;
    setState(() => _checkingBiometric = false);
    if (success) _goHome();
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _onPinCompleted(String pin) async {
    final valid = await AuthService.verifyPin(pin);
    if (valid) {
      _goHome();
    } else {
      setState(() => _error = 'Incorrect PIN — try again');
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = CycleRepository.getSettings();
    final greeting = settings.userName?.isNotEmpty == true
        ? 'Welcome back, ${settings.userName}'
        : 'Welcome back';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/app_logo.png', width: 64, height: 64),
              const SizedBox(height: 24),
              Text(greeting,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Enter your PIN to continue',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              // IMPORTANT: the PinCodeTextField below stays mounted at all
              // times (we only overlay a spinner on top of it while
              // checking biometrics, instead of swapping it out of the
              // tree). pin_code_fields disposes the TextEditingController
              // it's given as soon as its widget is removed from the tree;
              // if we conditionally unmounted/remounted this field while
              // reusing the same _pinController, the second mount would be
              // handed an already-disposed controller and crash with
              // "A TextEditingController was used after being disposed."
              // That was the cause of the crash after picking biometric
              // unlock -- keeping the field permanently mounted avoids it.
              SizedBox(
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: _checkingBiometric ? 0 : 1,
                      child: IgnorePointer(
                        ignoring: _checkingBiometric,
                        child: PinCodeTextField(
                          appContext: context,
                          length: 4,
                          controller: _pinController,
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
                          onChanged: (_) {
                            if (_error.isNotEmpty) setState(() => _error = '');
                          },
                          onCompleted: _onPinCompleted,
                        ),
                      ),
                    ),
                    if (_checkingBiometric) CircularProgressIndicator(color: AppColors.primary),
                  ],
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error, style: TextStyle(color: AppColors.concern)),
              ],
              const SizedBox(height: 16),
              if (_biometricAvailable && !_checkingBiometric)
                _BiometricButton(onTap: _tryBiometric),
            ],
          ),
        ),
      ),
    );
  }
}

/// Visible lock/fingerprint icon button for biometric unlock,
/// shown directly on the login screen as requested.
class _BiometricButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BiometricButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Use biometric unlock',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
