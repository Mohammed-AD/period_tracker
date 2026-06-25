import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';

/// PIN storage backend.
///
/// NOTE: We intentionally do NOT use flutter_secure_storage here.
/// On Flutter Web, that package has a well-documented bug where a value
/// written and then read back within the SAME browser session can throw
/// or return null — it only becomes readable after a full page reload.
/// (See: github.com/mogol/flutter_secure_storage issues #381 and similar.)
/// This caused the "PIN doesn't work until I reload" bug.
///
/// Hive (already used elsewhere in this app) does not have this issue and
/// behaves identically across web, Android, and iOS, so we standardize on
/// it for the PIN as well. On mobile this is stored in Hive's local file;
/// on web it's stored in IndexedDB. It is not OS-keychain-grade security,
/// but combined with the app being entirely local-only (no server, no
/// account data to steal), this is an appropriate, consistent trade-off.
class AuthService {
  static const String _boxName = 'secure_auth_box';
  static const String _pinKey = 'app_lock_pin';
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// True if the user authenticated via biometrics in this session.
  /// Reset to false on PIN-based login.
  static bool loggedInViaBiometric = false;

  static Box? _box;

  /// Must be called once during app init (after Hive.initFlutter()),
  /// before any other AuthService method is used.
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _authBox {
    final box = _box;
    if (box == null) {
      throw StateError('AuthService.init() must be called before use.');
    }
    return box;
  }

  static Future<void> setPin(String pin) async {
    await _authBox.put(_pinKey, pin);
    // Defensive: ensure the write is flushed before any caller proceeds
    // to navigate away (avoids any timing edge case on web).
    await _authBox.flush();
  }

  static Future<bool> hasPin() async {
    final value = _authBox.get(_pinKey) as String?;
    return value != null && value.isNotEmpty;
  }

  static Future<bool> verifyPin(String pin) async {
    final saved = _authBox.get(_pinKey) as String?;
    return saved == pin;
  }

  static Future<void> clearPin() async {
    await _authBox.delete(_pinKey);
    await _authBox.flush();
  }

  static Future<bool> canCheckBiometrics() async {
    if (kIsWeb) return false; // local_auth has no web support
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticateWithBiometrics() async {
    if (kIsWeb) return false; // local_auth has no web support
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock to view your cycle data',
        options: const AuthenticationOptions(
          biometricOnly: false, // allows device PIN/pattern fallback too
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
