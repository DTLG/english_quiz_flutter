import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum _RangeFilter { week, month }

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  final _client = Supabase.instance.client;
  late Future<_ProgressData> _dataFuture;
  String _userId = '';

  _RangeFilter _range = _RangeFilter.week;
  String _selectedCategory = 'all';

  Future<void> _ensureUserId() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      _userId = currentUser.id;
      return;
    }
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('uk');
    _dataFuture = _initAndLoad();
  }

  Future<_ProgressData> _initAndLoad({bool onlyRecent = true}) async {
    if (_userId.isEmpty) {
      await _ensureUserId();
    }
    if (_userId.isEmpty) {
      return const _ProgressData(
        entries: [],
        categories: ['all'],
        hasMore: false,
        allEntries: [],
      );
    }
    return _loadData(onlyRecent: onlyRecent);
  }

  Future<_ProgressData> _loadData({bool onlyRecent = true}) async {
    DateTime? cutoff;
    if (onlyRecent && _range == _RangeFilter.week) {
      cutoff = DateTime.now().subtract(const Duration(days: 6));
    } else if (onlyRecent && _range == _RangeFilter.month) {
      cutoff = DateTime.now().subtract(const Duration(days: 29));
    }

    final response = await _client
        .schema('english_quiz')
        .from('daily_results')
        .select(
          'day, category, correct_count, wrong_count, best_streak, session_count',
        )
        .filter('user_id', 'eq', _userId)
        .order('day');

    final entries =
        (response as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(
              (row) => _DailyResult(
                day: DateTime.parse(row['day'] as String),
                category: (row['category'] as String?) ?? 'all',
                correct: row['correct_count'] as int? ?? 0,
                wrong: row['wrong_count'] as int? ?? 0,
                bestStreak: row['best_streak'] as int? ?? 0,
                sessions: row['session_count'] as int? ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => a.day.compareTo(b.day));

    final filteredEntries = cutoff == null
        ? entries
        : entries.where((entry) => !entry.day.isBefore(cutoff!)).toList();

    final categories = <String>{'all'}
      ..addAll(
        filteredEntries.map((e) => e.category).where((c) => c.isNotEmpty),
      );

    return _ProgressData(
      entries: filteredEntries,
      categories: categories.toList(),
      hasMore: filteredEntries.length < entries.length,
      allEntries: entries,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _dataFuture = _initAndLoad();
    });
    await _dataFuture;
  }

  List<_DailyResult> _filteredRecords(List<_DailyResult> data) {
    final cutoff = _range == _RangeFilter.week
        ? DateTime.now().subtract(const Duration(days: 6))
        : DateTime.now().subtract(const Duration(days: 29));

    final filtered = data.where((entry) {
      final matchesCategory =
          _selectedCategory == 'all' || entry.category == _selectedCategory;
      return matchesCategory &&
          entry.day.isAfter(cutoff.subtract(const Duration(days: 1)));
    }).toList();

    if (_selectedCategory == 'all') {
      return _combineByDay(filtered);
    }

    filtered.sort((a, b) => a.day.compareTo(b.day));
    return filtered;
  }

  List<_DailyResult> _combineByDay(List<_DailyResult> entries) {
    final grouped = <DateTime, _DailyResult>{};
    for (final entry in entries) {
      final key = DateTime(entry.day.year, entry.day.month, entry.day.day);
      grouped.update(
        key,
        (current) => current.combine(entry),
        ifAbsent: () => entry.copyForAggregation(key),
      );
    }

    final aggregated =
        grouped.entries.map((e) => e.value.copyWith(day: e.key)).toList()
          ..sort((a, b) => a.day.compareTo(b.day));
    return aggregated;
  }

  double _averageAccuracy(List<_DailyResult> data) {
    final totals = data.fold<int>(0, (sum, e) => sum + e.total);
    final correct = data.fold<int>(0, (sum, e) => sum + e.correct);
    if (totals == 0) return 0;
    return correct / totals;
  }

  int _bestStreak(List<_DailyResult> data) =>
      data.fold<int>(0, (max, e) => math.max(max, e.bestStreak));

  List<BarChartGroupData> _buildChartData(List<_DailyResult> data) {
    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final record = entry.value;
      final percentage = record.total == 0
          ? 0.0
          : record.correct / record.total;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: percentage * 100,
            color: _accuracyColor(percentage),
            width: 16,
            borderRadius: BorderRadius.circular(4),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 100,
              color: Colors.grey.shade200,
            ),
          ),
        ],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Мій прогрес'), centerTitle: true),
      body: FutureBuilder<_ProgressData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Не вдалося завантажити прогрес',
                style: theme.textTheme.titleMedium,
              ),
            );
          }

          final rawData = snapshot.data!;
          final filtered = _filteredRecords(rawData.entries);

          final accuracy = _averageAccuracy(filtered);
          final totalAnswers = filtered.fold<int>(0, (sum, e) => sum + e.total);
          final bestStreak = _bestStreak(filtered);
          final chartData = _buildChartData(filtered);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _HeaderSection(
                  range: _range,
                  onRangeChanged: (value) => setState(() => _range = value),
                  category: _selectedCategory,
                  categories: rawData.categories,
                  onCategoryChanged: (value) =>
                      setState(() => _selectedCategory = value),
                ),
                _KpiGrid(
                  accuracy: accuracy,
                  totalAnswers: totalAnswers,
                  bestStreak: bestStreak,
                ),
                _ChartCard(chartData: chartData, records: filtered),
                _HistoryList(
                  records: filtered,
                  hasMore: rawData.hasMore,
                  onLoadAll: () {
                    setState(() {
                      _dataFuture = _initAndLoad(onlyRecent: false);
                    });
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.range,
    required this.onRangeChanged,
    required this.category,
    required this.categories,
    required this.onCategoryChanged,
  });

  final _RangeFilter range;
  final ValueChanged<_RangeFilter> onRangeChanged;
  final String category;
  final List<String> categories;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Мій Прогрес',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            range == _RangeFilter.week
                ? 'Статистика за останні 7 днів'
                : 'Статистика за останні 30 днів',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _RangeChip(
                label: 'Тиждень',
                active: range == _RangeFilter.week,
                onTap: () => onRangeChanged(_RangeFilter.week),
              ),
              const SizedBox(width: 8),
              _RangeChip(
                label: 'Місяць',
                active: range == _RangeFilter.month,
                onTap: () => onRangeChanged(_RangeFilter.month),
              ),
              const Spacer(),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: category,
                    items: categories
                        .map(
                          (cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(
                              cat == 'all'
                                  ? 'Усі категорії'
                                  : cat.toUpperCase(),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onCategoryChanged(value);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active ? const Color(0xFF5E60CE) : const Color(0xFFE9ECEF),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.accuracy,
    required this.totalAnswers,
    required this.bestStreak,
  });

  final double accuracy;
  final int totalAnswers;
  final int bestStreak;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Середня точність',
                  value: '${(accuracy * 100).round()}%',
                  subtitle: 'Середнє за період',
                  color: Colors.indigo.shade50,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  title: 'Всього відповідей',
                  value: '$totalAnswers',
                  subtitle: 'Сума за період',
                  color: Colors.blue.shade50,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Найкращий стрік',
                  value: '$bestStreak 🔥',
                  subtitle: 'Правильних відповідей поспіль',
                  color: Colors.orange.shade50,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.chartData, required this.records});

  final List<BarChartGroupData> chartData;
  final List<_DailyResult> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (chartData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              'Немає даних для графіка',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
      );
    }

    final formatter = DateFormat.MMMd('uk');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Активність та успішність',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: 100,
                  minY: 0,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      tooltipPadding: const EdgeInsets.all(8),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final record = records[groupIndex];
                        return BarTooltipItem(
                          '${formatter.format(record.day)}\n'
                          'Правильно: ${record.correct}\n'
                          'Помилок: ${record.wrong}',
                          theme.textTheme.bodyMedium!,
                        );
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 25,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}%',
                          style: theme.textTheme.bodySmall,
                        ),
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= records.length) {
                            return const SizedBox.shrink();
                          }
                          final day = DateFormat.E(
                            'uk',
                          ).format(records[index].day);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              day,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: chartData,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.records,
    required this.hasMore,
    required this.onLoadAll,
  });

  final List<_DailyResult> records;
  final bool hasMore;
  final VoidCallback onLoadAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat.yMMMEd('uk');
    final items = records.reversed.toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Деталі по днях',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((record) {
            final accuracy = record.total == 0
                ? 0.0
                : record.correct / record.total;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatter.format(record.day),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Відповідей: ${record.total} (${record.wrong} помилок)\n'
                          'Сесій: ${record.sessions}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: accuracy,
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _accuracyColor(accuracy),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(accuracy * 100).round()}%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.indigo.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (hasMore) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onLoadAll,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Показати всю статистику'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressData {
  const _ProgressData({
    required this.entries,
    required this.categories,
    required this.hasMore,
    required this.allEntries,
  });

  final List<_DailyResult> entries;
  final List<String> categories;
  final bool hasMore;
  final List<_DailyResult> allEntries;
}

class _DailyResult {
  _DailyResult({
    required this.day,
    required this.category,
    required this.correct,
    required this.wrong,
    required this.bestStreak,
    required this.sessions,
  });

  final DateTime day;
  final String category;
  final int correct;
  final int wrong;
  final int bestStreak;
  final int sessions;

  int get total => correct + wrong;

  _DailyResult combine(_DailyResult other) {
    return _DailyResult(
      day: day,
      category: 'all',
      correct: correct + other.correct,
      wrong: wrong + other.wrong,
      bestStreak: math.max(bestStreak, other.bestStreak),
      sessions: sessions + other.sessions,
    );
  }

  _DailyResult copyWith({
    DateTime? day,
    String? category,
    int? correct,
    int? wrong,
    int? bestStreak,
    int? sessions,
  }) {
    return _DailyResult(
      day: day ?? this.day,
      category: category ?? this.category,
      correct: correct ?? this.correct,
      wrong: wrong ?? this.wrong,
      bestStreak: bestStreak ?? this.bestStreak,
      sessions: sessions ?? this.sessions,
    );
  }

  _DailyResult copyForAggregation(DateTime truncatedDay) {
    return _DailyResult(
      day: truncatedDay,
      category: 'all',
      correct: correct,
      wrong: wrong,
      bestStreak: bestStreak,
      sessions: sessions,
    );
  }
}

Color _accuracyColor(double percentage) {
  if (percentage >= 0.8) return Colors.green.shade600;
  if (percentage >= 0.5) return Colors.indigo.shade400;
  return Colors.orangeAccent.shade200;
}
