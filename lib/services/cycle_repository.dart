import 'package:hive_flutter/hive_flutter.dart';
import '../models/cycle_entry.dart';
import '../models/user_settings.dart';
import '../models/chat_message.dart';
import 'auth_service.dart';

class CycleRepository {
  static const String cycleBoxName = 'cycle_entries';
  static const String settingsBoxName = 'user_settings';
  static const String chatBoxName = 'chat_messages';

  static Box<CycleEntry> get _cycleBox => Hive.box<CycleEntry>(cycleBoxName);
  static Box<UserSettings> get _settingsBox => Hive.box<UserSettings>(settingsBoxName);
  static Box<ChatMessage> get _chatBox => Hive.box<ChatMessage>(chatBoxName);

  /// Call once in main() before runApp.
  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(CycleEntryAdapter());
    Hive.registerAdapter(UserSettingsAdapter());
    Hive.registerAdapter(ChatMessageAdapter());

    await Hive.openBox<CycleEntry>(cycleBoxName);
    await Hive.openBox<UserSettings>(settingsBoxName);
    await Hive.openBox<ChatMessage>(chatBoxName);
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

  // ---------- Settings ----------

  static UserSettings getSettings() {
    return _settingsBox.get('settings') ?? UserSettings();
  }

  static Future<void> saveSettings(UserSettings settings) async {
    await _settingsBox.put('settings', settings);
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
    await AuthService.clearPin();
    await _settingsBox.clear();
    await _settingsBox.put('settings', UserSettings());
  }
}
