import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../services/auth_service.dart';
import '../../services/cycle_repository.dart';
import '../../services/otp_service.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';
import '../register/register_screen.dart';

enum _Step { confirmEmail, enterOtp, setNewPin }

/// Lets a user who forgot their PIN regain access via a one-time email
/// code, WITHOUT erasing their cycle data. Their registered email
/// (UserSettings.email) is shown pre-filled and read-only so they can
/// confirm it's the right inbox before requesting a code.
///
/// If no email was saved at registration, or the OTP backend isn't
/// configured yet, this falls back to the old "erase everything and
/// start over" path as the only remaining option — it's explained
/// clearly so the user understands why.
class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  _Step _step = _Step.confirmEmail;
  String? _email;
  String _resetToken = '';
  String _error = '';
  bool _loading = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  // New-PIN step state (mirrors RegisterScreen/SetPinScreen pattern).
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  String _firstNewPin = '';
  bool _confirmingNewPin = false;

  @override
  void initState() {
    super.initState();
    _email = CycleRepository.getSettings().email;
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _otpController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  bool get _canUseOtp => _email != null && _email!.isNotEmpty && OtpService.isConfigured;

  void _startCooldown() {
    setState(() => _resendCooldown = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _requestOtp() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final result = await OtpService.sendOtp(_email!);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      setState(() => _step = _Step.enterOtp);
      _startCooldown();
    } else {
      setState(() => _error = result.message ?? 'Could not send the code.');
    }
  }

  Future<void> _verifyOtp(String otp) async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final result = await OtpService.verifyOtp(_email!, otp);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      setState(() {
        _resetToken = result.resetToken ?? '';
        _step = _Step.setNewPin;
      });
    } else {
      setState(() => _error = result.message ?? 'Incorrect code.');
      _otpController.clear();
    }
  }

  Future<void> _onNewPinCompleted(String pin) async {
    if (!_confirmingNewPin) {
      setState(() {
        _firstNewPin = pin;
        _confirmingNewPin = true;
        _error = '';
      });
      _pinController.clear();
      return;
    }

    if (pin != _firstNewPin) {
      setState(() {
        _error = "PINs didn't match — try again";
        _confirmingNewPin = false;
        _firstNewPin = '';
      });
      _pinController.clear();
      return;
    }

    // Cycle data, settings, everything else on-device is untouched —
    // we only ever replace the PIN itself.
    await AuthService.setPin(pin);
    await OtpService.confirmReset(_email!, _resetToken);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _confirmEraseInstead() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Erase & reset instead?'),
        content: const Text(
          'This permanently erases your PIN AND all locally saved cycle data, '
          'and brings you back to the setup screen.\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.concern),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Erase & reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await CycleRepository.resetAllLocalData();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Forgot PIN')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _canUseOtp ? _buildOtpFlow() : _buildNoEmailFallback(),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpFlow() {
    switch (_step) {
      case _Step.confirmEmail:
        return _buildConfirmEmailStep();
      case _Step.enterOtp:
        return _buildOtpStep();
      case _Step.setNewPin:
        return _buildNewPinStep();
    }
  }

  Widget _buildConfirmEmailStep() {
    return Column(
      key: const ValueKey('confirm_email'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.mail_outline_rounded, size: 48, color: AppColors.primary),
        const SizedBox(height: 24),
        Text(
          "We'll send a code to:",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          _email ?? '',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          'Your cycle data stays exactly as it is — only your PIN will change.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        if (_error.isNotEmpty) ...[
          Text(_error, textAlign: TextAlign.center, style: TextStyle(color: AppColors.concern)),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _requestOtp,
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Send code'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _confirmEraseInstead,
          child: Text("Can't access this email? Erase & reset", style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      key: const ValueKey('enter_otp'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.password_rounded, size: 48, color: AppColors.primary),
        const SizedBox(height: 24),
        Text(
          'Enter the 6-digit code',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Sent to $_email — it expires in 5 minutes.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        if (_loading)
          CircularProgressIndicator(color: AppColors.primary)
        else
          PinCodeTextField(
            appContext: context,
            length: 6,
            controller: _otpController,
            obscureText: false,
            animationType: AnimationType.scale,
            keyboardType: TextInputType.number,
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(12),
              fieldHeight: 48,
              fieldWidth: 40,
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
            onCompleted: _verifyOtp,
          ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_error, style: TextStyle(color: AppColors.concern)),
        ],
        const SizedBox(height: 16),
        TextButton(
          onPressed: (_resendCooldown > 0 || _loading) ? null : _requestOtp,
          child: Text(_resendCooldown > 0 ? 'Resend code in ${_resendCooldown}s' : 'Resend code'),
        ),
      ],
    );
  }

  Widget _buildNewPinStep() {
    return Column(
      key: const ValueKey('new_pin'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_reset_rounded, size: 48, color: AppColors.primary),
        const SizedBox(height: 24),
        Text(
          _confirmingNewPin ? 'Confirm your new PIN' : 'Create a new PIN',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Your cycle data and settings are unchanged.',
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
          onCompleted: _onNewPinCompleted,
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_error, style: TextStyle(color: AppColors.concern)),
        ],
      ],
    );
  }

  Widget _buildNoEmailFallback() {
    final reason = OtpService.isConfigured
        ? "You didn't save a recovery email when you set up Bloom."
        : "Email-based recovery isn't set up for this app yet.";
    return Column(
      key: const ValueKey('no_email'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.concern),
        const SizedBox(height: 24),
        Text(
          "We can't send you a recovery code",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          '$reason Bloom stores everything only on this device — there is no '
          'account to recover your PIN from another way. Resetting will permanently '
          'erase your PIN AND all locally saved cycle data, and bring you back to the setup screen.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.concern),
            onPressed: _confirmEraseInstead,
            child: const Text('Erase & reset'),
          ),
        ),
      ],
    );
  }
}
