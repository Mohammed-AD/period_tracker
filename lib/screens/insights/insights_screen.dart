import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/cycle_repository.dart';
import '../../services/cycle_analyzer.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => InsightsScreenState();
}

class InsightsScreenState extends State<InsightsScreen> {
  late CycleAnalyzer _analyzer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final entries = CycleRepository.getAllEntries();
    _analyzer = CycleAnalyzer(entries);
  }

  /// Called from HomeScreen whenever the Insights tab becomes the selected
  /// tab. Needed because tabs live inside an IndexedStack (kept alive, not
  /// recreated on switch) — without this, initState()'s data only ever
  /// reflects whatever was logged before this screen was first built, even
  /// after the user adds entries on the Calendar tab and switches back.
  void reload() {
    if (!mounted) return;
    setState(_load);
  }

  Color _statusColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.healthy:
        return AppColors.healthy;
      case HealthStatus.attention:
        return AppColors.attention;
      case HealthStatus.concern:
        return AppColors.concern;
      case HealthStatus.insufficientData:
        return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final insight = _analyzer.analyze();
    final statusColor = _statusColor(insight.status);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Insights')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => setState(_load),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            _buildStatusCard(insight, statusColor),
            const SizedBox(height: 20),
            if (insight.status != HealthStatus.insufficientData) ...[
              _buildStatsRow(),
              const SizedBox(height: 20),
              _buildCycleChart(),
              const SizedBox(height: 20),
              _buildPeriodLengthBarChart(),
              const SizedBox(height: 20),
            ],
            if (insight.details.isNotEmpty) _buildDetailsCard(insight),
            const SizedBox(height: 16),
            _buildRecommendationsCard(insight),
            const SizedBox(height: 20),
            _buildDisclaimer(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(HealthInsight insight, Color color) {
    return GlassCard(
      gradientColors: [color.withOpacity(0.22), color.withOpacity(0.06)],
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(insight.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(insight.summary, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final avgCycle = _analyzer.averageCycleLength;
    final avgPeriod = _analyzer.averagePeriodLength;
    final next = _analyzer.predictedNextPeriodStart;

    return Row(
      children: [
        Expanded(child: _statCard('Avg Cycle', avgCycle != null ? '${avgCycle.toStringAsFixed(0)}d' : '—')),
        const SizedBox(width: 12),
        Expanded(child: _statCard('Avg Period', avgPeriod != null ? '${avgPeriod.toStringAsFixed(0)}d' : '—')),
        const SizedBox(width: 12),
        Expanded(child: _statCard('Next', next != null ? '${next.day}/${next.month}' : '—')),
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

  Widget _buildCycleChart() {
    final lengths = _analyzer.cycleLengths;
    if (lengths.length < 2) return const SizedBox.shrink();

    final spots = <FlSpot>[
      for (int i = 0; i < lengths.length; i++) FlSpot(i.toDouble(), lengths[i].toDouble()),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
      height: 200,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: [
        BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 6)),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Text('Cycle Length Trend', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: AppColors.primaryLight.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodLengthBarChart() {
    final lengths = _analyzer.periodLengths;
    if (lengths.length < 2) return const SizedBox.shrink();

    // Most recent few periods read clearer as bars than the whole history.
    final recent = lengths.length > 8 ? lengths.sublist(lengths.length - 8) : lengths;
    final maxLength = recent.reduce((a, b) => a > b ? a : b).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
      height: 200,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: [
        BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, 6)),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Text('Period Length History', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxLength + 2,
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (value, meta) {
                        final indexFromEnd = recent.length - value.toInt();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            indexFromEnd == 1 ? 'Latest' : '-${indexFromEnd - 1}',
                            style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (int i = 0; i < recent.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: recent[i].toDouble(),
                          color: AppColors.periodColor,
                          width: 16,
                          borderRadius: BorderRadius.circular(6),
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

  Widget _buildDetailsCard(HealthInsight insight) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: [
        BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 6)),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What I noticed', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...insight.details.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 6, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(d, style: Theme.of(context).textTheme.bodyMedium)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(HealthInsight insight) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text('Recommendations', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          ...insight.recommendations.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $r', style: Theme.of(context).textTheme.bodyMedium),
              )),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        'These insights are based on simple pattern rules from your own logged data — not a medical diagnosis. Always consult a doctor for medical concerns.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
      ),
    );
  }
}
