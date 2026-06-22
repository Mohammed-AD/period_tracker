import 'package:hive/hive.dart';

part 'user_settings.g.dart';

@HiveType(typeId: 1)
class UserSettings extends HiveObject {
  @HiveField(0)
  bool onboardingComplete;

  @HiveField(1)
  int averageCycleLength; // days, default 28

  @HiveField(2)
  int averagePeriodLength; // days, default 5

  @HiveField(3)
  bool lockEnabled;

  @HiveField(4)
  bool biometricEnabled;

  @HiveField(5)
  String? userName;

  @HiveField(6)
  DateTime? lastPeriodStartManual; // used before any logs exist

  @HiveField(7)
  bool remindersEnabled;

  /// Selected color theme id, e.g. 'rose', 'lavender', 'dark'.
  /// See ThemeCatalog in app_theme.dart for available values.
  @HiveField(8)
  String themeName;

  /// Absolute on-device file path to the user's chosen profile photo.
  /// Null/empty means "no photo set, show default avatar". Never uploaded
  /// anywhere — purely local, like everything else in this app.
  @HiveField(9)
  String? profileImagePath;

  /// User's age, optional. Shown on the profile header if set.
  @HiveField(10)
  int? age;

  /// Email address, used ONLY for the forgot-PIN OTP recovery flow.
  /// Stored locally; sent to our OTP backend solely to deliver a one-time
  /// code when the user requests a PIN reset. Never used for anything else.
  @HiveField(11)
  String? email;

  UserSettings({
    this.onboardingComplete = false,
    this.averageCycleLength = 28,
    this.averagePeriodLength = 5,
    this.lockEnabled = false,
    this.biometricEnabled = false,
    this.userName,
    this.lastPeriodStartManual,
    this.remindersEnabled = true,
    this.themeName = 'rose',
    this.profileImagePath,
    this.age,
    this.email,
  });
}
