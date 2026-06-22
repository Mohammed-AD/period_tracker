import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../services/auth_service.dart';
import '../../services/cycle_repository.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';

class SetPinScreen extends StatefulWidget {
  final bool isInitialSetup;
  const SetPinScreen({super.key, this.isInitialSetup = false});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  String _firstPin = '';
  bool _confirming = false;
  String _error = '';

  void _onCompleted(String pin) async {
    if (!_confirming) {
      setState(() {
        _firstPin = pin;
        _confirming = true;
        _error = '';
      });
    } else {
      if (pin == _firstPin) {
        await AuthService.setPin(pin);
        final settings = CycleRepository.getSettings();
        settings.lockEnabled = true;
        await CycleRepository.saveSettings(settings);

        final biometricAvailable = await AuthService.canCheckBiometrics();
        if (biometricAvailable && mounted) {
          _offerBiometric();
        } else if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        setState(() {
          _error = "PINs didn't match — try again";
          _confirming = false;
          _firstPin = '';
        });
      }
    }
  }

  void _offerBiometric() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enable biometric unlock?'),
        content: const Text('Use fingerprint or face unlock instead of typing your PIN every time.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () async {
              final settings = CycleRepository.getSettings();
              settings.biometricEnabled = true;
              await CycleRepository.saveSettings(settings);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
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
              Icon(Icons.lock_rounded, size: 48, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                _confirming ? 'Confirm your PIN' : 'Create a PIN to secure your data',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Only you will be able to open this app.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
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
            ],
          ),
        ),
      ),
    );
  }
}
