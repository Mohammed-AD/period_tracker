import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:bloom_cycle/services/auth_service.dart';
import 'package:bloom_cycle/theme/app_theme.dart';

/// Lets a signed-in user set a new PIN without touching any cycle data.
///
/// This is the recommended recovery path when biometric unlock is enabled:
///   1. User forgets PIN → opens app → biometric auto-prompt succeeds
///   2. User goes to Profile → Edit Profile → Change PIN
///   3. New PIN is saved; ALL historical data is preserved.
class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  String _firstPin = '';
  bool _confirming = false;
  String _error = '';
  final TextEditingController _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _onCompleted(String pin) async {
    if (!_confirming) {
      setState(() {
        _firstPin = pin;
        _confirming = true;
        _error = '';
      });
      _pinController.clear();
      return;
    }

    if (pin != _firstPin) {
      setState(() {
        _error = "PINs didn't match — try again";
        _confirming = false;
        _firstPin = '';
      });
      _pinController.clear();
      return;
    }

    // Only the PIN is updated — all cycle entries, settings, and profile
    // data remain completely untouched.
    await AuthService.setPin(pin);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('PIN updated successfully!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Change PIN')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 24),
              Text(
                _confirming ? 'Confirm your new PIN' : 'Enter your new PIN',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Your cycle history and all data stay exactly as they are.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              PinCodeTextField(
                appContext: context,
                length: 4,
                controller: _pinController,
                obscureText: true,
                animationType: AnimationType.scale,
                keyboardType: TextInputType.number,
                autoFocus: true,
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
                onCompleted: _onCompleted,
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error, style: TextStyle(color: AppColors.concern)),
              ],
              if (_confirming) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _confirming = false;
                      _firstPin = '';
                      _error = '';
                    });
                    _pinController.clear();
                  },
                  child: Text(
                    'Start over',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
