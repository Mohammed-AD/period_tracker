import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/cycle_entry.dart';
import '../../services/cycle_repository.dart';
import '../../services/reminder_scheduler.dart';
import '../../theme/app_theme.dart';
import '../../widgets/flow_intensity_selector.dart';
import '../../widgets/mood_emoji_selector.dart';
import '../../widgets/success_overlay.dart';

class LogEntryScreen extends StatefulWidget {
  final DateTime initialDate;
  final CycleEntry? existingEntry;

  const LogEntryScreen({super.key, required this.initialDate, this.existingEntry});

  @override
  State<LogEntryScreen> createState() => _LogEntryScreenState();
}

class _LogEntryScreenState extends State<LogEntryScreen> {
  late DateTime _startDate;
  DateTime? _endDate;
  String _flow = 'Medium';
  String? _mood;
  final Set<String> _symptoms = {};
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null) {
      final e = widget.existingEntry!;
      _startDate = e.startDate;
      _endDate = e.endDate;
      _flow = e.flow;
      _mood = e.mood;
      _symptoms.addAll(e.symptoms);
      _notesController.text = e.notes ?? '';
    } else {
      _startDate = widget.initialDate;
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime(2030, 12, 31),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate)) _endDate = null;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    final entry = widget.existingEntry ??
        CycleEntry(id: const Uuid().v4(), startDate: _startDate);

    entry.startDate = _startDate;
    entry.endDate = _endDate;
    entry.flow = _flow;
    entry.mood = _mood;
    entry.symptoms = _symptoms.toList();
    entry.notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

    try {
      if (widget.existingEntry != null) {
        await CycleRepository.updateEntry(entry);
      } else {
        await CycleRepository.addEntry(entry);
      }
    } catch (e) {
      // The actual save failed — this one we DO surface, since silently
      // doing nothing here is exactly the bug we're fixing.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
      return;
    }

    HapticFeedback.mediumImpact();
    // Reminder scheduling is a side effect of saving, not a precondition —
    // see _rescheduleReminders for why this can never block the save above.
    await _rescheduleReminders();

    if (mounted) await SuccessOverlay.show(context, message: 'Period logged!');
    if (mounted) Navigator.of(context).pop(true);
  }

  /// A new/edited period entry shifts the predicted next period and
  /// ovulation date, so any already-scheduled reminders need to move with
  /// it. Wrapped in try/catch deliberately: scheduling a reminder is a
  /// side effect of saving, never a precondition for it. If the OS
  /// declines to schedule a notification (missing permission, OEM battery
  /// restrictions, etc.) that must never block or roll back the entry
  /// that was already saved successfully.
  Future<void> _rescheduleReminders() async {
    try {
      final entries = CycleRepository.getAllEntries();
      await ReminderScheduler.rescheduleAll(entries);
    } catch (e) {
      debugPrint('Reminder scheduling failed (non-fatal): $e');
    }
  }

  Future<void> _delete() async {
    if (widget.existingEntry == null) return;
    final confirmed = await _confirm(
      title: 'Delete this entry?',
      message: 'This period entry will be permanently removed. This can\'t be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;

    try {
      await CycleRepository.deleteEntry(widget.existingEntry!.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
      return;
    }
    HapticFeedback.mediumImpact();
    await _rescheduleReminders();
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Small reusable yes/no confirmation dialog for destructive actions —
  /// keeps a single consistent look instead of writing showDialog
  /// boilerplate inline.
  Future<bool> _confirm({required String title, required String message, required String confirmLabel}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel, style: TextStyle(color: AppColors.concern, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.existingEntry != null ? 'Edit Entry' : 'Log Period'),
        actions: [
          if (widget.existingEntry != null)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: AppColors.concern),
              tooltip: 'Delete entry',
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _sectionTitle('Dates'),
          Row(
            children: [
              Expanded(child: _dateTile('Start date', _startDate, () => _pickDate(isStart: true))),
              const SizedBox(width: 12),
              Expanded(
                  child: _dateTile('End date (optional)', _endDate, () => _pickDate(isStart: false))),
            ],
          ),
          const SizedBox(height: 24),
          _sectionTitle('Flow'),
          FlowIntensitySelector(
            selected: _flow,
            onChanged: (f) => setState(() => _flow = f),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Symptoms'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SymptomOptions.all.map((s) {
              final selected = _symptoms.contains(s);
              return FilterChip(
                label: Text(s),
                selected: selected,
                onSelected: (sel) => setState(() {
                  sel ? _symptoms.add(s) : _symptoms.remove(s);
                }),
                selectedColor: AppColors.secondary,
                backgroundColor: AppColors.cardBackground,
                labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary),
                checkmarkColor: Colors.white,
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Mood'),
          MoodEmojiSelector(
            selected: _mood,
            onChanged: (m) => setState(() => _mood = m),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Notes'),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Anything else you want to remember...'),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Save Entry'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      );

  Widget _dateTile(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              date != null ? DateFormat('MMM d, yyyy').format(date) : 'Ongoing',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
