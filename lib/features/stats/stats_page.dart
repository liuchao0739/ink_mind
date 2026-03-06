import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/reading_stats.dart';
import '../../data/repositories/stats_repository.dart';

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository();
});

final recentStatsProvider =
    FutureProvider<List<ReadingStats>>((ref) async {
  final repo = ref.watch(statsRepositoryProvider);
  return repo.loadRecentStats(days: 14);
});

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(recentStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('阅读画像'),
      ),
      body: statsAsync.when(
        data: (stats) {
          if (stats.isEmpty) {
            return const Center(
              child: Text('还没有阅读记录，开始第一章阅读之旅吧～'),
            );
          }

          final reversed = stats.reversed.toList();
          final maxMinutes =
              reversed.map((e) => e.minutes).fold<int>(0, (a, b) => a > b ? a : b);

          final totalMinutes =
              reversed.fold<int>(0, (sum, e) => sum + e.minutes);
          final totalBooks =
              reversed.fold<int>(0, (sum, e) => sum + e.booksRead);
          final categories = <String, int>{};
          for (final s in reversed) {
            for (final c in s.mainCategories) {
              categories.update(c, (v) => v + 1, ifAbsent: () => 1);
            }
          }

          final favCategory = categories.entries.isEmpty
              ? '暂未形成偏好'
              : categories.entries
                  .reduce((a, b) => a.value >= b.value ? a : b)
                  .key;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '最近 ${reversed.length} 天，你累计阅读约 $totalMinutes 分钟，涉猎 $totalBooks 次章节，最常看的类别是：$favCategory。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: true),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= reversed.length) {
                                return const SizedBox.shrink();
                              }
                              final label =
                                  reversed[index].dateString.substring(5);
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  label,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      barGroups: [
                        for (var i = 0; i < reversed.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: reversed[i].minutes.toDouble(),
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary,
                              ),
                            ],
                          ),
                      ],
                      maxY: (maxMinutes > 0 ? maxMinutes : 10).toDouble(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('加载阅读统计失败：$error'),
        ),
      ),
    );
  }
}

