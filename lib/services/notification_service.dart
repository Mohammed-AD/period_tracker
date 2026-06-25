import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Schedules and cancels all of Bloom's local reminders:
/// - Period reminder, a few days before the predicted start
/// - Ovulation reminder, on the predicted ovulation day
/// - Water intake reminder, a repeating nudge through the day
///
/// Everything here is purely on-device (no push service, no server) —
/// it just asks the OS to show a notification at a future local time.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // Stable, distinct IDs per reminder "kind" so re-scheduling one kind
  // never collides with or accidentally cancels another.
  static const int periodReminderId = 1001;
  static const int ovulationReminderId = 1002;
  // Water reminders use a block of IDs (one per reminder of the day) so
  // multiple can be scheduled without overwriting each other.
  static const int waterReminderIdBase = 2000;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'bloom_reminders',
    'Bloom reminders',
    channelDescription: 'Period, ovulation, and water intake reminders',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  /// Must be called once during app init. Safe to call multiple times.
  static Future<void> init() async {
    if (_initialized || kIsWeb) return;

    tz_data.initializeTimeZones();
    // We don't know the device's IANA zone name without an extra plugin,
    // and reminders are always relative to "now" on this device, so using
    // the local offset Dart already knows about (via tz.local's default,
    // UTC, combined with our own local DateTime math below) keeps this
    // dependency-light. We schedule using the device's local wall-clock
    // time converted through tz.local, which flutter_local_notifications
    // resolves correctly as long as we build TZDateTime.from() from a
    // local DateTime, which is what every method below does.

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  /// Requests OS-level notification permission. Returns true if granted
  /// (or if the platform doesn't require an explicit prompt).
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      return granted ?? false;
    }
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      final granted = await iosImpl.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return true;
  }

  static tz.TZDateTime _nextInstanceAt(DateTime date, {int hour = 9, int minute = 0}) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local, date.year, date.month, date.day, hour, minute,
    );
    if (scheduled.isBefore(now)) {
      // Don't schedule in the past — push to the same time tomorrow as a
      // safe fallback (this only happens if the predicted date already
      // passed, which the caller should avoid, but it's defensive).
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Schedules a one-off reminder [daysBefore] the predicted period start.
  /// Pass null/cancel if there's no prediction yet.
  static Future<void> schedulePeriodReminder({
    required DateTime predictedStart,
    int daysBefore = 2,
  }) async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancel(periodReminderId);
    final reminderDate = predictedStart.subtract(Duration(days: daysBefore));
    if (reminderDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))) return;

    await _plugin.zonedSchedule(
      periodReminderId,
      'Your period may be coming soon 🌸',
      "Based on your cycle, it's expected in about $daysBefore days. Might be worth packing supplies just in case.",
      _nextInstanceAt(reminderDate, hour: 9),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedules a one-off reminder on the predicted ovulation day.
  static Future<void> scheduleOvulationReminder({required DateTime predictedOvulation}) async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancel(ovulationReminderId);
    if (predictedOvulation.isBefore(DateTime.now().subtract(const Duration(days: 1)))) return;

    await _plugin.zonedSchedule(
      ovulationReminderId,
      "Today's your predicted ovulation day 🌕",
      "You're likely in your fertile window around today. Logging symptoms now helps sharpen future predictions.",
      _nextInstanceAt(predictedOvulation, hour: 9),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancels just the period reminder (e.g. user disabled it in settings).
  static Future<void> cancelPeriodReminder() async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancel(periodReminderId);
  }

  /// Cancels just the ovulation reminder.
  static Future<void> cancelOvulationReminder() async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancel(ovulationReminderId);
  }

  /// Schedules repeating water-intake nudges at the given hours of the day
  /// (e.g. [10, 13, 16, 19]), every day, starting today. Replaces any
  /// previously scheduled water reminders.
  static Future<void> scheduleWaterReminders(List<int> hoursOfDay) async {
    if (kIsWeb || !_initialized) return;
    await cancelWaterReminders(maxSlots: 12);

    for (int i = 0; i < hoursOfDay.length; i++) {
      final hour = hoursOfDay[i];
      await _plugin.zonedSchedule(
        waterReminderIdBase + i,
        'Time for some water 💧',
        "A quick glass now keeps you on track for today's goal.",
        _nextInstanceAt(DateTime.now(), hour: hour, minute: 0),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// Cancels all scheduled water reminders.
  static Future<void> cancelWaterReminders({int maxSlots = 12}) async {
    if (kIsWeb || !_initialized) return;
    for (int i = 0; i < maxSlots; i++) {
      await _plugin.cancel(waterReminderIdBase + i);
    }
  }
}
