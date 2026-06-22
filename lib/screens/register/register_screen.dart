import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../services/auth_service.dart';
import '../../services/cycle_repository.dart';
import '../../theme/app_theme.dart';
import '../onboarding/onboarding_screen.dart';

/// First-run "account creation" screen. Fully local — there is no server,
/// this just sets the person's display name and a 4-digit PIN that will be
/// required on every future app open (see LoginScreen).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  String _firstPin = '';
  bool _confirmingPin = false;
  String _error = '';
  bool _showPinStep = false;
  String? _emailError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  void _proceedToPin() {
    final email = _emailController.text.trim();
    if (email.isNotEmpty && !_isValidEmail(email)) {
      setState(() => _emailError = 'Enter a valid email address');
      return;
    }
    setState(() {
      _emailError = null;
      _showPinStep = true;
      _error = '';
    });
  }

  Future<void> _onPinCompleted(String pin) async {
    if (!_confirmingPin) {
      setState(() {
        _firstPin = pin;
        _confirmingPin = true;
        _error = '';
      });
      // Clear via the controller only — do NOT give this field a new key
      // when the step changes. A new key would force Flutter to destroy
      // and recreate the PinCodeTextField element, and pin_code_fields
      // disposes the controller it was given when its widget is removed,
      // leaving the next-created field holding an already-disposed
      // controller (crashes with "TextEditingController was used after
      // being disposed"). Reusing the same widget/controller and just
      // clearing the text avoids that entirely.
      _pinController.clear();
      return;
    }

    if (pin != _firstPin) {
      setState(() {
        _error = "PINs didn't match — try again";
        _confirmingPin = false;
        _firstPin = '';
      });
      _pinController.clear();
      return;
    }

    // Save name + email + PIN, then move on to cycle-setup onboarding.
    await AuthService.setPin(pin);
    final settings = CycleRepository.getSettings();
    settings.userName = _nameController.text.trim().isEmpty
        ? null
        : _nameController.text.trim();
    settings.email = _emailController.text.trim().isEmpty
        ? null
        : _emailController.text.trim().toLowerCase();
    settings.lockEnabled = true;
    await CycleRepository.saveSettings(settings);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _showPinStep ? _buildPinStep() : _buildNameStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildNameStep() {
    return Column(
      key: const ValueKey('name_step'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset('assets/images/app_logo.png', width: 64, height: 64),
        const SizedBox(height: 20),
        Text('Create your space',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Bloom is completely private — everything stays on this device. Let\'s set it up.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 28),
        Text('What should we call you?', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(hintText: 'Your name (optional)'),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        Text('Email (for PIN recovery)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Only used to send you a one-time code if you forget your PIN. Optional, but without it you can\'t recover access without erasing your data.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            hintText: 'you@example.com',
            errorText: _emailError,
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_emailError != null) setState(() => _emailError = null);
          },
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _proceedToPin,
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }

  Widget _buildPinStep() {
    return Column(
      key: const ValueKey('pin_step'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.primary),
        const SizedBox(height: 24),
        Text(
          _confirmingPin ? 'Confirm your PIN' : 'Create a 4-digit PIN',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'You\'ll use this to unlock the app every time.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
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
          onCompleted: _onPinCompleted,
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_error, style: TextStyle(color: AppColors.concern)),
        ],
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() {
            _showPinStep = false;
            _confirmingPin = false;
            _firstPin = '';
            _error = '';
            _pinController.clear();
          }),
          child: const Text('Back'),
        ),
      ],
    );
  }
}
