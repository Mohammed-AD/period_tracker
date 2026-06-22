import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_settings.dart';
import '../../services/cycle_repository.dart';
import '../home/home_screen.dart';
import '../../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  DateTime? _lastPeriodDate;
  int _cycleLength = 28;
  int _periodLength = 5;

  void _next() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _back() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    final settings = CycleRepository.getSettings();
    settings.onboardingComplete = true;
    settings.lastPeriodStartManual = _lastPeriodDate;
    settings.averageCycleLength = _cycleLength;
    settings.averagePeriodLength = _periodLength;
    await CycleRepository.saveSettings(settings);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildProgressDots(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _LastPeriodPage(
                    selectedDate: _lastPeriodDate,
                    onSelect: (d) => setState(() => _lastPeriodDate = d),
                  ),
                  _CycleLengthPage(
                    cycleLength: _cycleLength,
                    onChanged: (v) => setState(() => _cycleLength = v),
                  ),
                  _PeriodLengthPage(
                    periodLength: _periodLength,
                    onChanged: (v) => setState(() => _periodLength = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _back,
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _currentPage == 0 && _lastPeriodDate == null
                        ? null
                        : _next,
                    child: Text(_currentPage == 2 ? "Let's Start" : 'Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.primaryLight,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _LastPeriodPage extends StatelessWidget {
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelect;
  const _LastPeriodPage({required this.selectedDate, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('When did your last period start?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'This helps us start predicting your cycle right away.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: now,
              );
              if (picked != null) onSelect(picked);
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    selectedDate != null
                        ? DateFormat('EEEE, MMM d, yyyy').format(selectedDate!)
                        : 'Select a date',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleLengthPage extends StatelessWidget {
  final int cycleLength;
  final ValueChanged<int> onChanged;
  const _CycleLengthPage({required this.cycleLength, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Average cycle length?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            "Days from one period's start to the next. Don't worry, we'll refine this as you log.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('$cycleLength days',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          Slider(
            value: cycleLength.toDouble(),
            min: 18,
            max: 45,
            divisions: 27,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.primaryLight,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}

class _PeriodLengthPage extends StatelessWidget {
  final int periodLength;
  final ValueChanged<int> onChanged;
  const _PeriodLengthPage({required this.periodLength, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Average period length?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'How many days does your period usually last?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('$periodLength days',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          Slider(
            value: periodLength.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.primaryLight,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}
