import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

/// Sets a new PIN directly — no "enter your current PIN" step. Two stages:
/// 1. Type a new 4-digit PIN
/// 2. Confirm it (must match #1)
///
/// IMPORTANT implementation note on the crash this used to have: each
/// stage gets its OWN fresh TextEditingController (created right when we
/// enter that stage, disposed right when we leave it) AND its own widget
/// Key. Earlier this screen tried to reuse a single long-lived controller
/// across stages while also changing the PinCodeTextField's Key — that
/// combination is what threw "A TextEditingController was used after
/// being disposed": changing the Key makes pin_code_fields tear down and
/// recreate its internal state (which is what actually fixes the
/// "confirm step stops accepting input" bug), but it also means the OLD
/// controller it was wired to should be considered finished, not reused.
/// Giving each stage its own controller removes that conflict entirely.
class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  bool _confirming = false;
  String _firstPin = '';
  String _error = '';

  TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Swaps in a brand new controller for the next stage and disposes the
  /// old one — called right before each setState that changes stages.
  void _freshController() {
    final old = _controller;
    _controller = TextEditingController();
    // Dispose after the current frame so PinCodeTextField's own teardown
    // (triggered by the Key change below) isn't fighting over the same
    // controller mid-rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  Future<void> _onCompleted(String pin) async {
    if (!_confirming) {
      _freshController();
      setState(() {
        _firstPin = pin;
        _confirming = true;
        _error = '';
      });
      return;
    }

    if (pin != _firstPin) {
      _freshController();
      setState(() {
        _error = "PINs didn't match — try again";
        _confirming = false;
        _firstPin = '';
      });
      return;
    }

    await AuthService.setPin(pin);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _goBack() {
    _freshController();
    setState(() {
      _confirming = false;
      _firstPin = '';
      _error = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Change PIN')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_reset_rounded, size: 48, color: AppColors.primary),
                  const SizedBox(height: 24),
                  Text(
                    _confirming ? 'Confirm your new PIN' : 'Create a new PIN',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a new 4-digit PIN to keep your history safe.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  PinCodeTextField(
                    // Fresh key per stage forces pin_code_fields to fully
                    // rebuild its internal state — paired with the fresh
                    // controller above, this is what reliably resets the
                    // field between "create" and "confirm" without the
                    // disposed-controller crash.
                    key: ValueKey(_confirming),
                    appContext: context,
                    length: 4,
                    controller: _controller,
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
                  const SizedBox(height: 16),
                  if (_confirming)
                    TextButton(onPressed: _goBack, child: const Text('Back')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
