import 'package:hive_flutter/hive_flutter.dart';
import '../models/cycle_entry.dart';
import '../models/user_settings.dart';
import '../models/chat_message.dart';
import '../models/daily_log.dart';
import 'auth_service.dart';

class CycleRepository {
  static const String cycleBoxName = 'cycle_entries';
  static const String settingsBoxName = 'user_settings';
  static const String chatBoxName = 'chat_messages';
  static const String dailyLogBoxName = 'daily_logs';

  static Box<CycleEntry> get _cycleBox => Hive.box<CycleEntry>(cycleBoxName);
  static Box<UserSettings> get _settingsBox => Hive.box<UserSettings>(settingsBoxName);
  static Box<ChatMessage> get _chatBox => Hive.box<ChatMessage>(chatBoxName);
  static Box<DailyLog> get _dailyLogBox => Hive.box<DailyLog>(dailyLogBoxName);

  /// Call once in main() before runApp.
  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(CycleEntryAdapter());
    Hive.registerAdapter(UserSettingsAdapter());
    Hive.registerAdapter(ChatMessageAdapter());
    Hive.registerAdapter(DailyLogAdapter());

    await Hive.openBox<CycleEntry>(cycleBoxName);
    await Hive.openBox<UserSettings>(settingsBoxName);
    await Hive.openBox<ChatMessage>(chatBoxName);
    await Hive.openBox<DailyLog>(dailyLogBoxName);
    await AuthService.init();

    // Ensure a settings object always exists.
    if (_settingsBox.isEmpty) {
      await _settingsBox.put('settings', UserSettings());
    }
  }

  // ---------- Cycle Entries ----------

  static List<CycleEntry> getAllEntries() {
    return _cycleBox.values.toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  static Future<void> addEntry(CycleEntry entry) async {
    await _cycleBox.put(entry.id, entry);
  }

  static Future<void> updateEntry(CycleEntry entry) async {
    entry.updatedAt = DateTime.now();
    await entry.save();
  }

  static Future<void> deleteEntry(String id) async {
    await _cycleBox.delete(id);
  }

  static CycleEntry? getLatestEntry() {
    final all = getAllEntries();
    return all.isNotEmpty ? all.first : null;
  }

  /// Entries whose START date falls within the given month (an entry that
  /// starts in June and runs into July still counts as a June entry —
  /// matches how it reads on the calendar, since it's logged against its
  /// start date).
  static List<CycleEntry> getEntriesForMonth(DateTime month) {
    return getAllEntries()
        .where((e) => e.startDate.year == month.year && e.startDate.month == month.month)
        .toList();
  }

  /// Deletes every entry whose start date falls within the given month.
  /// Returns how many were deleted, so the caller can confirm to the user
  /// exactly what just happened.
  static Future<int> deleteEntriesForMonth(DateTime month) async {
    final toDelete = getEntriesForMonth(month);
    for (final entry in toDelete) {
      await _cycleBox.delete(entry.id);
    }
    return toDelete.length;
  }

  // ---------- Settings ----------

  static UserSettings getSettings() {
    return _settingsBox.get('settings') ?? UserSettings();
  }

  static Future<void> saveSettings(UserSettings settings) async {
    await _settingsBox.put('settings', settings);
  }

  // ---------- Daily Logs (Sleep + Water) ----------

  static String _dayKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Returns the log for [date] if one exists, or null. Never creates one —
  /// use [getOrCreateDailyLog] when you intend to write to it.
  static DailyLog? getDailyLog(DateTime date) {
    return _dailyLogBox.get(_dayKey(date));
  }

  /// Returns the existing log for [date], or creates+saves a fresh empty
  /// one. Callers can mutate the returned object's fields and call
  /// [saveDailyLog] (or `.save()` directly, since it's a HiveObject already
  /// in the box once created here).
  static Future<DailyLog> getOrCreateDailyLog(DateTime date) async {
    final key = _dayKey(date);
    final existing = _dailyLogBox.get(key);
    if (existing != null) return existing;
    final fresh = DailyLog(date: DateTime(date.year, date.month, date.day));
    await _dailyLogBox.put(key, fresh);
    return fresh;
  }

  static Future<void> saveDailyLog(DailyLog log) async {
    await _dailyLogBox.put(_dayKey(log.date), log);
  }

  /// Logs for the last [days] days (including today), oldest first —
  /// handy for sleep/water history charts.
  static List<DailyLog> getRecentDailyLogs(int days) {
    final today = DateTime.now();
    final result = <DailyLog>[];
    for (int i = days - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final log = getDailyLog(day);
      result.add(log ?? DailyLog(date: DateTime(day.year, day.month, day.day)));
    }
    return result;
  }

  // ---------- Chat ----------

  static List<ChatMessage> getChatHistory() {
    final list = _chatBox.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  static Future<void> addChatMessage(ChatMessage message) async {
    await _chatBox.put(message.id, message);
  }

  static Future<void> clearChatHistory() async {
    await _chatBox.clear();
  }

  // ---------- Forgot PIN / full local reset ----------

  /// Wipes everything stored on this device: cycle entries, chat history,
  /// settings, and the PIN itself, then recreates a fresh default
  /// UserSettings so the app behaves like a brand-new install.
  ///
  /// This app is fully local/offline with no account or server, so there is
  /// no way to "recover" a forgotten PIN — resetting is the only option,
  /// and it intentionally also erases the data the PIN was protecting.
  /// Callers MUST get explicit user confirmation before calling this.
  static Future<void> resetAllLocalData() async {
    await _cycleBox.clear();
    await _chatBox.clear();
    await _dailyLogBox.clear();
    await AuthService.clearPin();
    await _settingsBox.clear();
    await _settingsBox.put('settings', UserSettings());
  }
}
