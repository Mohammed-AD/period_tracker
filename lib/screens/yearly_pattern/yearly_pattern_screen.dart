import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/cycle_repository.dart';
import '../../services/yearly_pattern_service.dart';
import '../../theme/app_theme.dart';
import 'widgets/mini_month_calendar.dart';

enum _ViewMode { graph, calendar }

class YearlyPatternScreen extends StatefulWidget {
  const YearlyPatternScreen({super.key});

  @override
  State<YearlyPatternScreen> createState() => YearlyPatternScreenState();
}

class YearlyPatternScreenState extends State<YearlyPatternScreen> {
  _ViewMode _mode = _ViewMode.graph;
  late int _selectedYear;
  late List<int> _availableYears;
  late YearlyPatternData _data;

  static const _monthShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final entries = CycleRepository.getAllEntries();
    _availableYears = YearlyPatternData.availableYears(entries);
    _selectedYear = _availableYears.first;
    _data = YearlyPatternData.compute(entries, _selectedYear);
  }

  /// Called from HomeScreen when this tab is selected, so newly logged
  /// entries from other tabs show up (this screen lives in an
  /// IndexedStack and is otherwise only built once).
  void reload() {
    if (!mounted) return;
    setState(_load);
  }

  void _changeYear(int delta) {
    final idx = _availableYears.indexOf(_selectedYear);
    final newIdx = idx - delta; // years list is newest-first
    if (newIdx < 0 || newIdx >= _availableYears.length) return;
    setState(() {
      _selectedYear = _availableYears[newIdx];
      _data = YearlyPatternData.compute(CycleRepository.getAllEntries(), _selectedYear);
    });
  }

  @override
  Widget build(BuildContext context) {
    final idx = _availableYears.indexOf(_selectedYear);
    final canGoOlder = idx < _availableYears.length - 1;
    final canGoNewer = idx > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yearly Pattern'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => setState(_load),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _buildYearSelector(canGoOlder, canGoNewer),
            const SizedBox(height: 16),
            _buildModeToggle(),
            const SizedBox(height: 20),
            if (!_data.hasData)
              _buildEmptyState()
            else ...[
              _buildSummaryRow(),
              const SizedBox(height: 20),
              if (_mode == _ViewMode.graph) ..._buildGraphView() else _buildCalendarView(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildYearSelector(bool canGoOlder, bool canGoNewer) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: canGoOlder ? () => _changeYear(-1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
          color: AppColors.primaryDark,
        ),
        Text(
          '$_selectedYear',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        IconButton(
          onPressed: canGoNewer ? () => _changeYear(1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
          color: AppColors.primaryDark,
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: _toggleButton('Graph', Icons.show_chart_rounded, _ViewMode.graph)),
          Expanded(child: _toggleButton('Calendar', Icons.calendar_view_month_rounded, _ViewMode.calendar)),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, IconData icon, _ViewMode mode) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected ? [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            'No periods logged in $_selectedYear yet.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      children: [
        Expanded(child: _statCard('Periods', '${_data.totalPeriodsLogged}')),
        const SizedBox(width: 12),
        Expanded(child: _statCard('Avg Cycle', _data.avgCycleLength != null ? '${_data.avgCycleLength!.toStringAsFixed(0)}d' : '—')),
        const SizedBox(width: 12),
        Expanded(child: _statCard('Avg Period', _data.avgPeriodLength != null ? '${_data.avgPeriodLength!.toStringAsFixed(0)}d' : '—')),
      ],
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  List<Widget> _buildGraphView() {
    return [
      _buildPeriodDaysBarChart(),
      const SizedBox(height: 20),
      _buildCycleLengthLineChart(),
      const SizedBox(height: 20),
      _buildPieCard(
        title: 'Flow Distribution',
        data: _data.flowDistribution,
        colors: _flowColors(_data.flowDistribution.keys.toList()),
        emptyText: 'Log your flow intensity to see this breakdown.',
        unit: 'days',
      ),
      const SizedBox(height: 20),
      _buildPieCard(
        title: 'Symptom Frequency',
        data: _data.symptomDistribution,
        colors: _palette,
        emptyText: 'Log symptoms with your periods to see this breakdown.',
        unit: 'times',
      ),
      const SizedBox(height: 20),
      _buildPieCard(
        title: 'Mood Distribution',
        data: _data.moodDistribution,
        colors: _palette,
        emptyText: 'Log your mood with your periods to see this breakdown.',
        unit: 'times',
      ),
    ];
  }

  // Shared color palette used for the symptom / mood pie charts — cycles
  // through theme colors so each slice stays distinct and on-brand.
  List<Color> get _palette => [
        AppColors.primary,
        AppColors.secondary,
        AppColors.accent,
        AppColors.fertileColor,
        AppColors.attention,
        AppColors.ovulationColor,
        AppColors.predictedColor,
        AppColors.concern,
        AppColors.healthy,
        AppColors.primaryDark,
      ];

  // Flow gets its own palette — graded shades of the app's period color so
  // "Heavy" reads visually heavier than "Spotting" at a glance.
  List<Color> _flowColors(List<String> keys) {
    const order = ['Spotting', 'Light', 'Medium', 'Heavy'];
    const opacities = [0.35, 0.55, 0.8, 1.0];
    return keys.map((k) {
      final idx = order.indexWhere((o) => o.toLowerCase() == k.toLowerCase());
      final opacity = idx >= 0 ? opacities[idx] : 0.6;
      return AppColors.periodColor.withOpacity(opacity);
    }).toList();
  }

  Widget _buildPeriodDaysBarChart() {
    final stats = _data.monthlyStats;
    final maxDays = stats.map((s) => s.periodDays).fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = (maxDays < 5 ? 5 : maxDays + 2).toDouble();
    final gridInterval = maxY > 12 ? 4.0 : 2.0;
    final currentMonthIndex = (_selectedYear == DateTime.now().year) ? DateTime.now().month - 1 : -1;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
      height: 250,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 12),
            child: Text('Period Days by Month', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceEvenly,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: gridInterval,
                  getDrawingHorizontalLine: (value) => FlLine(color: AppColors.divider, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primaryDark,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                      '${rod.toY.toInt()} ${rod.toY.toInt() == 1 ? "day" : "days"}',
                      const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: gridInterval,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i > 11) return const SizedBox.shrink();
                        final isCurrent = i == currentMonthIndex;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _monthShort[i],
                            style: TextStyle(
                              fontSize: 9,
                              color: isCurrent ? AppColors.primaryDark : AppColors.textSecondary,
                              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < 12; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: stats[i].periodDays.toDouble(),
                          width: 14,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                          gradient: stats[i].periodDays > 0
                              ? LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [AppColors.periodColor, AppColors.periodColor.withOpacity(0.65)],
                                )
                              : null,
                          color: stats[i].periodDays > 0 ? null : AppColors.divider,
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxY,
                            color: AppColors.cardBackground,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleLengthLineChart() {
    final stats = _data.monthlyStats;
    final spots = <FlSpot>[
      for (int i = 0; i < 12; i++)
        if (stats[i].avgCycleLength != null) FlSpot(i.toDouble(), stats[i].avgCycleLength!),
    ];

    if (spots.length < 2) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
        child: Text(
          'Log a couple more periods this year to see your cycle-length trend across the year.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    final values = spots.map((s) => s.y).toList();
    final dataMin = values.reduce((a, b) => a < b ? a : b);
    final dataMax = values.reduce((a, b) => a > b ? a : b);
    final pad = ((dataMax - dataMin) < 4 ? 4 : (dataMax - dataMin) * 0.25);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Text('Cycle Length Trend (Full Year)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                // Always span the whole Jan-Dec range, even when only a
                // couple of months have data, so the trend reads against
                // the full year instead of zooming into just the points
                // that exist.
                minX: 0,
                maxX: 11,
                minY: (dataMin - pad).clamp(0.0, double.infinity),
                maxY: dataMax + pad,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: AppColors.divider, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i > 11) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_monthShort[i], style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.secondary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: AppColors.secondaryLight.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieCard({
    required String title,
    required Map<String, int> data,
    required List<Color> colors,
    required String emptyText,
    required String unit,
  }) {
    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(emptyText, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 140,
                width: 140,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 28,
                    sections: [
                      for (int i = 0; i < entries.length; i++)
                        PieChartSectionData(
                          value: entries[i].value.toDouble(),
                          color: colors[i % colors.length],
                          radius: 46,
                          title: '${((entries[i].value / total) * 100).round()}%',
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < entries.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${entries[i].key} (${entries[i].value} $unit)',
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 12,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, i) => MiniMonthCalendar(
        year: _selectedYear,
        month: i + 1,
        periodDaysFlow: _data.periodDaysFlow,
      ),
    );
  }
}