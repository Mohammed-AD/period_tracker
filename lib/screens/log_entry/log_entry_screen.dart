import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/cycle_entry.dart';
import '../../services/cycle_repository.dart';
import '../../theme/app_theme.dart';

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

    if (widget.existingEntry != null) {
      await CycleRepository.updateEntry(entry);
    } else {
      await CycleRepository.addEntry(entry);
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    if (widget.existingEntry == null) return;
    await CycleRepository.deleteEntry(widget.existingEntry!.id);
    if (mounted) Navigator.of(context).pop(true);
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
          Wrap(
            spacing: 8,
            children: FlowOptions.all.map((f) {
              final selected = _flow == f;
              return ChoiceChip(
                label: Text(f),
                selected: selected,
                onSelected: (_) => setState(() => _flow = f),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.cardBackground,
                labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary),
              );
            }).toList(),
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
          Wrap(
            spacing: 8,
            children: MoodOptions.all.map((m) {
              final selected = _mood == m;
              return ChoiceChip(
                label: Text(m),
                selected: selected,
                onSelected: (_) => setState(() => _mood = selected ? null : m),
                selectedColor: AppColors.accent,
                backgroundColor: AppColors.cardBackground,
                labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary),
              );
            }).toList(),
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
