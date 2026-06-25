import '../models/cycle_entry.dart';
import 'cycle_analyzer.dart';
import 'cycle_repository.dart';
import 'notification_service.dart';

/// Single place that decides WHAT reminders should be scheduled, based on
/// current entries + UserSettings toggles, and asks NotificationService to
/// make it so. Call [rescheduleAll] any time something that affects
/// predictions or reminder preferences changes (new/edited/deleted period
/// entry, or a toggle flipped in Profile) — it's cheap and always safe to
/// call again.
class ReminderScheduler {
  ReminderScheduler._();

  /// Reschedules all three reminder kinds based on current entries +
  /// settings. Each kind is scheduled independently inside its own
  /// try/catch: a platform-level notification failure (missing
  /// permission, OEM battery restrictions, a plugin quirk on a specific
  /// Android version, etc.) for one kind must never prevent the others
  /// from being scheduled, and must never throw back to the caller — this
  /// runs as a side effect after saving an entry, after toggling a
  /// setting, and on every app startup, none of which should ever fail
  /// because a notification couldn't be scheduled.
  static Future<void> rescheduleAll(List<CycleEntry> entries) async {
    final settings = CycleRepository.getSettings();
    final analyzer = CycleAnalyzer(entries);

    try {
      if (settings.remindersEnabled && settings.periodReminderEnabled) {
        final predicted = analyzer.predictedNextPeriodStart;
        if (predicted != null) {
          await NotificationService.schedulePeriodReminder(predictedStart: predicted);
        } else {
          await NotificationService.cancelPeriodReminder();
        }
      } else {
        await NotificationService.cancelPeriodReminder();
      }
    } catch (_) {
      // Non-fatal — see method doc.
    }

    try {
      if (settings.remindersEnabled && settings.ovulationReminderEnabled) {
        final ovulation = analyzer.predictedOvulationDate;
        if (ovulation != null) {
          await NotificationService.scheduleOvulationReminder(predictedOvulation: ovulation);
        } else {
          await NotificationService.cancelOvulationReminder();
        }
      } else {
        await NotificationService.cancelOvulationReminder();
      }
    } catch (_) {
      // Non-fatal — see method doc.
    }

    try {
      if (settings.remindersEnabled && settings.waterReminderEnabled) {
        // Four evenly-spaced nudges through a typical waking day. Kept
        // simple/fixed for now rather than configurable per-hour, to
        // match the scope of a single on/off "Water reminder" toggle in
        // Profile.
        await NotificationService.scheduleWaterReminders(const [10, 13, 16, 19]);
      } else {
        await NotificationService.cancelWaterReminders();
      }
    } catch (_) {
      // Non-fatal — see method doc.
    }
  }
}
