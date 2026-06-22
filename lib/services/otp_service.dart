import 'dart:convert';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';

/// Result of an OTP-related call: either succeeded with optional data,
/// or failed with a human-readable message to show the user.
class OtpResult {
  final bool success;
  final String? message;
  final String? resetToken;

  const OtpResult.ok({this.resetToken}) : success = true, message = null;
  const OtpResult.fail(this.message) : success = false, resetToken = null;
}

/// Calls the Firebase Functions backend for the forgot-PIN email OTP
/// flow. Like ChatbotService, this NEVER talks to any third-party email
/// provider directly — only to our own Cloud Functions, which hold the
/// real Resend API key server-side.
///
/// IMPORTANT: this only ever sends/verifies a one-time code tied to the
/// user's email. The PIN and the cycle data never leave the device —
/// after the OTP is verified, the new PIN is saved locally exactly like
/// before (see AuthService.setPin).
class OtpService {
  /// Optional manual override for local development if you do not want to
  /// rely on the default Firebase project URL pattern.
  static const String _sendOtpEndpointOverride = 'REPLACE_WITH_YOUR_FIREBASE_FUNCTION_URL_FOR/sendOtp';
  static const String _verifyOtpEndpointOverride = 'REPLACE_WITH_YOUR_FIREBASE_FUNCTION_URL_FOR/verifyOtp';
  static const String _confirmResetEndpointOverride = 'REPLACE_WITH_YOUR_FIREBASE_FUNCTION_URL_FOR/confirmReset';

  static String get _projectId => DefaultFirebaseOptions.currentPlatform.projectId;

  static String _functionUrl(String functionName) {
    final normalizedProjectId = _projectId.trim();
    if (normalizedProjectId.isEmpty || normalizedProjectId == 'your-project-id') {
      return '';
    }
    return 'https://us-central1-$normalizedProjectId.cloudfunctions.net/$functionName';
  }

  static String get _sendOtpEndpoint =>
      _sendOtpEndpointOverride.startsWith('REPLACE_WITH_YOUR_FIREBASE_FUNCTION_URL_FOR')
          ? _functionUrl('sendOtp')
          : _sendOtpEndpointOverride;

  static String get _verifyOtpEndpoint =>
      _verifyOtpEndpointOverride.startsWith('REPLACE_WITH_YOUR_FIREBASE_FUNCTION_URL_FOR')
          ? _functionUrl('verifyOtp')
          : _verifyOtpEndpointOverride;

  static String get _confirmResetEndpoint =>
      _confirmResetEndpointOverride.startsWith('REPLACE_WITH_YOUR_FIREBASE_FUNCTION_URL_FOR')
          ? _functionUrl('confirmReset')
          : _confirmResetEndpointOverride;

  static bool get isConfigured =>
      _sendOtpEndpoint.isNotEmpty &&
      _verifyOtpEndpoint.isNotEmpty &&
      _confirmResetEndpoint.isNotEmpty;

  static Future<OtpResult> sendOtp(String email) async {
    if (!isConfigured) {
      return const OtpResult.fail(
        'OTP recovery isn\'t set up yet. See README_SETUP.md to connect the email backend.',
      );
    }
    try {
      final response = await http
          .post(
            Uri.parse(_sendOtpEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return const OtpResult.ok();
      }
      return OtpResult.fail(_extractError(response, fallback: 'Could not send the code. Please try again.'));
    } catch (_) {
      return const OtpResult.fail('Couldn\'t reach the server. Check your internet connection.');
    }
  }

  static Future<OtpResult> verifyOtp(String email, String otp) async {
    try {
      final response = await http
          .post(
            Uri.parse(_verifyOtpEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return OtpResult.ok(resetToken: data['resetToken'] as String?);
      }
      return OtpResult.fail(_extractError(response, fallback: 'Incorrect or expired code.'));
    } catch (_) {
      return const OtpResult.fail('Couldn\'t reach the server. Check your internet connection.');
    }
  }

  /// Called right after the new PIN is saved locally, purely to
  /// invalidate the one-time reset token server-side so it can't be
  /// reused. Failure here is non-fatal — the PIN change already
  /// succeeded locally — so callers should not block the user on it.
  static Future<void> confirmReset(String email, String resetToken) async {
    try {
      await http
          .post(
            Uri.parse(_confirmResetEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'resetToken': resetToken}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Non-fatal — see doc comment above.
    }
  }

  static String _extractError(http.Response response, {required String fallback}) {
    try {
      final data = jsonDecode(response.body);
      return data['error'] as String? ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
