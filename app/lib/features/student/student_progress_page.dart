import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';

class StudentProgressPage extends ConsumerWidget {
  const StudentProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myStudentProfileProvider);
    final assignments = ref.watch(myAssignmentsProvider);
    return PageBody(
      title: 'My Progress',
      subtitle: 'Track your achievements and progress over time',
      actions: [
        IconButton(tooltip: 'Refresh', onPressed: () { ref.invalidate(myStudentProfileProvider); ref.invalidate(myAssignmentsProvider); }, icon: const Icon(Icons.refresh)),
      ],
      child: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e),
        data: (p) {
          if (p == null) return const AppCard(child: EmptyState(title: 'Profile not found'));
          final pr = p.progress;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StatGrid(children: [
              StatCard(icon: Icons.assignment_outlined, label: 'Assigned', value: '${pr.assigned}'),
              StatCard(icon: Icons.check_circle_outline, label: 'Completed', value: '${pr.completed}', color: const Color(0xFF15803D)),
              StatCard(icon: Icons.hourglass_bottom, label: 'In Progress', value: '${pr.pending}', color: const Color(0xFF1D4ED8)),
              StatCard(icon: Icons.rate_review_outlined, label: 'Awaiting Review', value: '${pr.awaitingReview}', color: const Color(0xFFB45309)),
              if (pr.overdue > 0) StatCard(icon: Icons.warning_amber_rounded, label: 'Overdue', value: '${pr.overdue}', color: const Color(0xFFB91C1C)),
            ]),
            const SizedBox(height: 24),
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Overall Completion', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('${pr.completed} of ${pr.assigned} tasks approved', style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 16),
                ProgressLine(pr.percentage),
              ]),
            ),
            const SizedBox(height: 24),
            Text('Task Status Breakdown', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(20),
              child: pr.assigned == 0
                  ? const EmptyState(title: 'No tasks assigned yet')
                  : SizedBox(
                      height: 220,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 44,
                          sections: [
                            if (pr.completed > 0) PieChartSectionData(value: pr.completed.toDouble(), title: 'Done\n${pr.completed}', color: const Color(0xFF15803D), radius: 75, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            if (pr.pending > 0) PieChartSectionData(value: pr.pending.toDouble(), title: 'Pending\n${pr.pending}', color: const Color(0xFF1D4ED8), radius: 75, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            if (pr.awaitingReview > 0) PieChartSectionData(value: pr.awaitingReview.toDouble(), title: 'Review\n${pr.awaitingReview}', color: const Color(0xFFB45309), radius: 75, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            if (pr.overdue > 0) PieChartSectionData(value: pr.overdue.toDouble(), title: 'Overdue\n${pr.overdue}', color: const Color(0xFFB91C1C), radius: 75, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            Text('Task History', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            assignments.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(e),
              data: (list) {
                final done = list.where((a) => a.status == 'APPROVED').toList();
                return AppCard(
                  child: done.isEmpty
                      ? const EmptyState(title: 'No completed tasks yet', message: 'Keep going! Complete your first task to see your history.')
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: done.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final a = done[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              leading: const CircleAvatar(backgroundColor: Color(0xFFDCFCE7), child: Icon(Icons.check, color: Color(0xFF15803D))),
                              title: Text(a.taskTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${a.topic} • ${a.platform} • reviewed ${a.reviewedAt != null ? fmtDate(a.reviewedAt!) : "—"}'),
                            );
                          },
                        ),
                );
              },
            ),
          ]);
        },
      ),
    );
  }
}
