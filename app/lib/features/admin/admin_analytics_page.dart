import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/progress.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/providers.dart';

class AdminAnalyticsPage extends ConsumerWidget {
  const AdminAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(adminStudentsProvider);
    final submissions = ref.watch(adminSubmissionsProvider);
    return PageBody(
      title: 'Analytics',
      subtitle: 'Programme-wide insights and progress overview',
      actions: [
        IconButton(
          tooltip: 'Recompute Stats',
          icon: const Icon(Icons.refresh),
          onPressed: () async {
            try {
              await ref.read(apiProvider).recomputeStats();
              if (context.mounted) showSnack(context, 'Stats recomputed!');
            } catch (e) {
              if (context.mounted) showSnack(context, e.toString(), error: true);
            }
          },
        ),
      ],
      child: students.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(adminStudentsProvider)),
        data: (studentList) {
          final total = studentList.length;
          final progresses = studentList.map((s) => s.progress);
          final completed = progresses.fold<int>(0, (s, p) => s + p.completed);
          final overdue = progresses.fold<int>(0, (s, p) => s + p.overdue);
          final pending = progresses.fold<int>(0, (s, p) => s + p.pending);
          final reviewing = progresses.fold<int>(0, (s, p) => s + p.awaitingReview);
          final avgPct = Progress.average(progresses);

          // Bucket students into progress bands
          final bands = <String, int>{'0–25%': 0, '26–50%': 0, '51–75%': 0, '76–100%': 0};
          for (final p in progresses) {
            if (p.percentage <= 25) bands['0–25%'] = bands['0–25%']! + 1;
            else if (p.percentage <= 50) bands['26–50%'] = bands['26–50%']! + 1;
            else if (p.percentage <= 75) bands['51–75%'] = bands['51–75%']! + 1;
            else bands['76–100%'] = bands['76–100%']! + 1;
          }

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StatGrid(children: [
              StatCard(icon: Icons.groups_outlined, label: 'Total Students', value: '$total'),
              StatCard(icon: Icons.check_circle_outline, label: 'Tasks Completed', value: '$completed', color: const Color(0xFF15803D)),
              StatCard(icon: Icons.rate_review_outlined, label: 'Awaiting Review', value: '$reviewing', color: const Color(0xFFB45309)),
              StatCard(icon: Icons.warning_amber_rounded, label: 'Overdue Tasks', value: '$overdue', color: const Color(0xFFB91C1C)),
              StatCard(icon: Icons.trending_up, label: 'Avg Completion', value: '$avgPct%', color: const Color(0xFF7E22CE)),
            ]),
            const SizedBox(height: 32),
            Text('Progress Distribution', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Students grouped by completion percentage', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 220,
                  child: total == 0
                      ? const Center(child: Text('No student data yet'))
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: (bands.values.reduce((a, b) => a > b ? a : b) + 1).toDouble(),
                            barGroups: bands.entries.toList().asMap().entries.map((e) {
                              final idx = e.key;
                              final entry = e.value;
                              return BarChartGroupData(x: idx, barRods: [
                                BarChartRodData(
                                  toY: entry.value.toDouble(),
                                  color: [const Color(0xFFB91C1C), const Color(0xFFB45309), const Color(0xFF1D4ED8), const Color(0xFF15803D)][idx],
                                  width: 32,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ]);
                            }).toList(),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, _) {
                                    final labels = bands.keys.toList();
                                    final idx = value.toInt();
                                    return idx >= 0 && idx < labels.length
                                        ? Padding(padding: const EdgeInsets.only(top: 6), child: Text(labels[idx], style: const TextStyle(fontSize: 11)))
                                        : const SizedBox();
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(drawVerticalLine: false),
                            borderData: FlBorderData(show: false),
                          ),
                        ),
                ),
              ]),
            ),
            const SizedBox(height: 32),
            Text('Submission Status Breakdown', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            submissions.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(e),
              data: (subList) {
                final byStatus = <String, int>{'PENDING': 0, 'APPROVED': 0, 'NEEDS_CHANGES': 0};
                for (final s in subList) { byStatus[s.reviewStatus] = (byStatus[s.reviewStatus] ?? 0) + 1; }
                final sectionData = <PieChartSectionData>[
                  if ((byStatus['PENDING'] ?? 0) > 0)
                    PieChartSectionData(value: byStatus['PENDING']!.toDouble(), title: 'Pending\n${byStatus['PENDING']}', color: const Color(0xFFB45309), radius: 80, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  if ((byStatus['APPROVED'] ?? 0) > 0)
                    PieChartSectionData(value: byStatus['APPROVED']!.toDouble(), title: 'Approved\n${byStatus['APPROVED']}', color: const Color(0xFF15803D), radius: 80, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  if ((byStatus['NEEDS_CHANGES'] ?? 0) > 0)
                    PieChartSectionData(value: byStatus['NEEDS_CHANGES']!.toDouble(), title: 'Changes\n${byStatus['NEEDS_CHANGES']}', color: const Color(0xFFC2410C), radius: 80, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ];
                return AppCard(
                  padding: const EdgeInsets.all(20),
                  child: sectionData.isEmpty
                      ? const EmptyState(title: 'No submissions yet')
                      : SizedBox(
                          height: 220,
                          child: PieChart(PieChartData(sections: sectionData, centerSpaceRadius: 40, sectionsSpace: 3)),
                        ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text('Task Status Overview', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                _StatRow('Completed', completed, total == 0 ? 0 : completed / (completed + overdue + pending + reviewing) * 100, const Color(0xFF15803D)),
                _StatRow('Pending / In Progress', pending, total == 0 ? 0 : pending / (completed + overdue + pending + reviewing) * 100, const Color(0xFF1D4ED8)),
                _StatRow('Awaiting Review', reviewing, total == 0 ? 0 : reviewing / (completed + overdue + pending + reviewing) * 100, const Color(0xFFB45309)),
                _StatRow('Overdue', overdue, total == 0 ? 0 : overdue / (completed + overdue + pending + reviewing) * 100, const Color(0xFFB91C1C)),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final int count;
  final double pct;
  final Color color;
  const _StatRow(this.label, this.count, this.pct, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        SizedBox(width: 180, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: pct / 100, minHeight: 8, backgroundColor: const Color(0xFFECEEF5), color: color),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 64, child: Text('$count (${pct.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
