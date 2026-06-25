import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_settings.dart';
import '../../services/cycle_repository.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/reminder_scheduler.dart';
import '../../theme/app_theme.dart';
import '../log_entry/log_entry_screen.dart';
import '../profile/edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserSettings _settings;
  final TextEditingController _historySearchController = TextEditingController();
  String _historySearch = '';

  @override
  void initState() {
    super.initState();
    _settings = CycleRepository.getSettings();
  }

  @override
  void dispose() {
    _historySearchController.dispose();
    super.dispose();
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (result == true && mounted) {
      setState(() => _settings = CycleRepository.getSettings());
    }
  }

  Future<void> _toggleLock(bool value) async {
    if (value) {
      // Re-enabling: just flip the flag (PIN already exists from onboarding)
      final hasPin = await AuthService.hasPin();
      if (!hasPin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Set a PIN first from the security menu.')),
          );
        }
        return;
      }
    }
    setState(() => _settings.lockEnabled = value);
    await CycleRepository.saveSettings(_settings);
  }

  Future<void> _selectTheme(String themeId) async {
    ThemeController.instance.select(themeId);
    setState(() => _settings.themeName = themeId);
    await CycleRepository.saveSettings(_settings);
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final available = await AuthService.canCheckBiometrics();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric authentication is not available on this device.')),
          );
        }
        return;
      }
    }
    setState(() => _settings.biometricEnabled = value);
    await CycleRepository.saveSettings(_settings);
  }

  Future<void> _rescheduleReminders() async {
    final entries = CycleRepository.getAllEntries();
    await ReminderScheduler.rescheduleAll(entries);
  }

  /// Master "Reminders" switch. Turning it on asks for OS notification
  /// permission once (if not already granted) — without that, every
  /// individual reminder toggle below would silently do nothing.
  Future<void> _toggleReminders(bool value) async {
    if (value) {
      final granted = await NotificationService.requestPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enable notifications for Bloom in your device settings to use reminders.')),
        );
      }
    }
    setState(() => _settings.remindersEnabled = value);
    await CycleRepository.saveSettings(_settings);
    await _rescheduleReminders();
  }

  Future<void> _togglePeriodReminder(bool value) async {
    setState(() => _settings.periodReminderEnabled = value);
    await CycleRepository.saveSettings(_settings);
    await _rescheduleReminders();
  }

  Future<void> _toggleOvulationReminder(bool value) async {
    setState(() => _settings.ovulationReminderEnabled = value);
    await CycleRepository.saveSettings(_settings);
    await _rescheduleReminders();
  }

  Future<void> _toggleWaterReminder(bool value) async {
    setState(() => _settings.waterReminderEnabled = value);
    await CycleRepository.saveSettings(_settings);
    await _rescheduleReminders();
  }

  Future<void> _adjustWaterGoal(int deltaMl) async {
    setState(() => _settings.waterGoalMl = (_settings.waterGoalMl + deltaMl).clamp(500, 8000).toInt());
    await CycleRepository.saveSettings(_settings);
  }

  /// Entries matching the current History search text — checked against
  /// the date (in a couple of common formats), flow, mood, symptoms, and
  /// notes, so searching "july", "heavy", "cramps", or a note keyword all
  /// find the right entries.
  List<dynamic> _filterHistory(List<dynamic> entries) {
    final query = _historySearch.trim().toLowerCase();
    if (query.isEmpty) return entries;

    return entries.where((e) {
      final dateLong = DateFormat('MMM d, yyyy').format(e.startDate).toLowerCase();
      final dateMonthYear = DateFormat('MMMM yyyy').format(e.startDate).toLowerCase();
      final flow = (e.flow as String).toLowerCase();
      final mood = (e.mood as String?)?.toLowerCase() ?? '';
      final symptoms = (e.symptoms as List<String>).join(' ').toLowerCase();
      final notes = (e.notes as String?)?.toLowerCase() ?? '';

      return dateLong.contains(query) ||
          dateMonthYear.contains(query) ||
          flow.contains(query) ||
          mood.contains(query) ||
          symptoms.contains(query) ||
          notes.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final entries = CycleRepository.getAllEntries();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 24),
          _sectionTitle('Appearance'),
          _buildThemePicker(),
          const SizedBox(height: 20),
          _sectionTitle('Security'),
          _buildSwitchTile('App lock', _settings.lockEnabled, _toggleLock, Icons.lock_outline_rounded),
          _buildSwitchTile('Biometric unlock', _settings.biometricEnabled, _toggleBiometric, Icons.fingerprint_rounded),
          const SizedBox(height: 20),
          _sectionTitle('Cycle Settings'),
          _buildInfoTile('Average cycle length', '${_settings.averageCycleLength} days', Icons.refresh_rounded),
          _buildInfoTile('Average period length', '${_settings.averagePeriodLength} days', Icons.water_drop_outlined),
          const SizedBox(height: 20),
          _sectionTitle('Reminders'),
          _buildSwitchTile('Reminders', _settings.remindersEnabled, _toggleReminders, Icons.notifications_outlined),
          if (_settings.remindersEnabled) ...[
            _buildSwitchTile(
              'Period reminder (2 days before)',
              _settings.periodReminderEnabled,
              _togglePeriodReminder,
              Icons.calendar_today_rounded,
              indent: true,
            ),
            _buildSwitchTile(
              'Ovulation reminder',
              _settings.ovulationReminderEnabled,
              _toggleOvulationReminder,
              Icons.egg_alt_rounded,
              indent: true,
            ),
            _buildSwitchTile(
              'Water intake reminder',
              _settings.waterReminderEnabled,
              _toggleWaterReminder,
              Icons.water_drop_rounded,
              indent: true,
            ),
            _buildWaterGoalTile(),
          ],
          const SizedBox(height: 20),
          _sectionTitle('History (${entries.length} entries)'),
          if (entries.isNotEmpty) _buildHistorySearchBar(),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No periods logged yet.', style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            _buildHistoryList(entries),
        ],
      ),
    );
  }

  Widget _buildHistorySearchBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _historySearchController,
        onChanged: (value) => setState(() => _historySearch = value),
        decoration: InputDecoration(
          hintText: 'Search by date, flow, mood, symptom...',
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
          suffixIcon: _historySearch.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () {
                    _historySearchController.clear();
                    setState(() => _historySearch = '');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  /// Shows the 5 most recent entries when there's no search text. As soon
  /// as the person types something, every matching entry is shown (no
  /// cap) — that's the whole point of letting them search for older ones
  /// instead of scrolling.
  Widget _buildHistoryList(List<dynamic> entries) {
    final filtered = _filterHistory(entries);
    final isSearching = _historySearch.trim().isNotEmpty;
    final visible = isSearching ? filtered : filtered.take(5).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('No entries match "$_historySearch".', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return Column(
      children: [
        ...visible.map((e) => _buildHistoryTile(e)),
        if (!isSearching && entries.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              'Showing 5 most recent · search above to find older entries',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    final hasPhoto = _settings.profileImagePath != null && _settings.profileImagePath!.isNotEmpty;
    final nameText = _settings.userName?.isNotEmpty == true ? _settings.userName! : 'Your Profile';
    final ageText = _settings.age != null ? ' · ${_settings.age} yrs' : '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primaryLight, AppColors.secondaryLight]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            backgroundImage: hasPhoto
                ? (kIsWeb
                    ? NetworkImage(_settings.profileImagePath!)
                    : FileImage(File(_settings.profileImagePath!))) as ImageProvider
                : null,
            child: hasPhoto ? null : const Icon(Icons.person_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '$nameText$ageText',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: _openEditProfile,
            icon: Icon(Icons.edit_rounded, color: AppColors.textPrimary),
            tooltip: 'Edit profile',
          ),
        ],
      ),
    );
  }

  Widget _buildThemePicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a theme',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Changes apply instantly and are saved on this device.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: ThemeCatalog.all.map((palette) {
              final selected = _settings.themeName == palette.id;
              return GestureDetector(
                onTap: () => _selectTheme(palette.id),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.primary,
                        border: Border.all(
                          color: selected ? AppColors.textPrimary : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(color: palette.shadow, blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: selected
                          ? Icon(Icons.check_rounded, color: palette.textOnPrimary, size: 22)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 64,
                      child: Text(
                        palette.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      );

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged, IconData icon, {bool indent = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: 8, left: indent ? 16 : 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, color: indent ? AppColors.secondary : AppColors.primary, size: indent ? 20 : 24),
        title: Text(title, style: indent ? const TextStyle(fontSize: 14) : null),
        value: value,
        activeColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildWaterGoalTile() {
    final liters = (_settings.waterGoalMl / 1000).toStringAsFixed(1);
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.local_drink_outlined, color: AppColors.secondary, size: 20),
          const SizedBox(width: 16),
          Expanded(child: Text('Daily water goal', style: const TextStyle(fontSize: 14))),
          IconButton(
            onPressed: () => _adjustWaterGoal(-250),
            icon: Icon(Icons.remove_circle_outline_rounded, color: AppColors.textSecondary),
            visualDensity: VisualDensity.compact,
          ),
          Text('$liters L', style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            onPressed: () => _adjustWaterGoal(250),
            icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(child: Text(title)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(dynamic entry) {
    final dateStr = DateFormat('MMM d, yyyy').format(entry.startDate);
    final lengthStr = entry.periodLength != null ? '${entry.periodLength} days' : 'Ongoing';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => LogEntryScreen(initialDate: entry.startDate, existingEntry: entry)),
            );
            if (result == true) setState(() {});
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 36,
                  decoration: BoxDecoration(color: AppColors.periodColor, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('$lengthStr · ${entry.flow} flow', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
