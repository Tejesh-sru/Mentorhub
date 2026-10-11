import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/cssp_models.dart';
import '../../models/models.dart';

class AdminReportsPage extends ConsumerStatefulWidget {
  const AdminReportsPage({super.key});

  @override
  ConsumerState<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends ConsumerState<AdminReportsPage> {
  String? _selectedBatchId;
  String _selectedWeekId = 'W1';

  void _exportCsv(
    List<StudentProfile> students,
    List<WeeklySubmission> submissions,
    List<MockInterview> mocks,
    WeekConfig week,
  ) {
    final subMap = {for (var s in submissions.where((s) => s.weekId == week.weekId)) s.juniorUid: s};
    final mockMap = {for (var m in mocks.where((m) => m.weekId == week.weekId)) m.juniorUid: m};

    final buffer = StringBuffer();
    buffer.writeln('Roll No,Student Name,Email,Batch,Week,Configured Target,Claimed Count,Verified Count,Verification Status,Target Met,Seriousness,Remarks,Mock Status,Mock Score (10),Technical (5),Communication (5),Problem Solving (5),Recommendation');

    for (final s in students) {
      final sub = subMap[s.uid];
      final mock = mockMap[s.uid];
      final target = week.targetCumulative;
      final targetMet = sub?.isTargetMet(target) ?? false;

      buffer.writeln(
        '${s.studentCode},"${s.name}",${s.email},${s.batchId},${week.label},$target,'
        '${sub?.claimedCount ?? 0},${sub?.verifiedCount ?? 0},${sub?.verificationStatus ?? "NOT_SUBMITTED"},$targetMet,'
        '${sub?.seriousness ?? "NONE"},"${sub?.remarks ?? ""}",'
        '${mock?.status ?? "NOT_PLANNED"},${mock?.score10 ?? ""},${mock?.technical5 ?? ""},${mock?.communication5 ?? ""},${mock?.problemSolving5 ?? ""},"${mock?.recommendation ?? ""}"',
      );
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Weekly Batch CSV Report copied to clipboard! Ready to paste into Excel or Google Sheets.'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(adminBatchesStreamProvider);
    final studentsAsync = ref.watch(adminStudentsProvider);

    return PageBody(
      title: 'Batch Reports & CSV Export',
      subtitle: 'Batch-level progress dashboards, overdue review queues, weekly milestone summaries, and exportable reports',
      child: batchesAsync.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        error: (e, _) => ErrorView(e),
        data: (batches) {
          if (batches.isEmpty) return const AppCard(child: EmptyState(title: 'No batches found'));

          _selectedBatchId ??= batches.first.id;
          final batchId = _selectedBatchId!;

          final weeksAsync = ref.watch(csspWeeksProvider(batchId));
          final batchSubmissionsAsync = ref.watch(csspBatchSubmissionsProvider(batchId));
          final batchMocksAsync = ref.watch(csspBatchMocksProvider(batchId));

          return studentsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ErrorView(e),
            data: (allStudents) {
              final students = allStudents.where((s) => s.batchId == batchId).toList();

              return weeksAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                error: (e, _) => ErrorView(e),
                data: (weeks) {
                  final activeWeek = weeks.firstWhere((w) => w.weekId == _selectedWeekId, orElse: () => weeks.first);

                  return batchSubmissionsAsync.when(
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                    error: (e, _) => ErrorView(e),
                    data: (submissions) {
                      return batchMocksAsync.when(
                        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                        error: (e, _) => ErrorView(e),
                        data: (mocks) {
                          final subMap = {for (var s in submissions.where((s) => s.weekId == _selectedWeekId)) s.juniorUid: s};

                          final awaitingReviews = submissions.where((s) => s.weekId == _selectedWeekId && s.status == 'AWAITING_REVIEW').length;
                          final verifiedMet = students.where((s) => subMap[s.uid]?.isTargetMet(activeWeek.targetCumulative) ?? false).length;
                          final doubtfulCount = submissions.where((s) => s.weekId == _selectedWeekId && s.verificationStatus == 'DOUBTFUL').length;

                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // ── Filter & Batch Selection ──
                            AppCard(
                              padding: const EdgeInsets.all(18),
                              child: Wrap(spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Text('Batch: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  DropdownButton<String>(
                                    value: batchId,
                                    items: batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                                    onChanged: (v) => setState(() => _selectedBatchId = v),
                                  ),
                                ]),
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Text('Week: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  DropdownButton<String>(
                                    value: _selectedWeekId,
                                    items: weeks.map((w) => DropdownMenuItem(value: w.weekId, child: Text(w.label))).toList(),
                                    onChanged: (v) => setState(() => _selectedWeekId = v ?? 'W1'),
                                  ),
                                ]),
                                FilledButton.icon(
                                  onPressed: () => _exportCsv(students, submissions, mocks, activeWeek),
                                  icon: const Icon(Icons.download_rounded, size: 18),
                                  label: const Text('Export CSV Report'),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 18),

                            // ── Weekly Batch Summary KPI Row ──
                            StatGrid(children: [
                              StatCard(icon: Icons.groups_rounded, label: 'Enrolled Juniors', value: '${students.length}', color: const Color(0xFF4F46E5)),
                              StatCard(icon: Icons.hourglass_top_rounded, label: 'Awaiting Review (Overdue Queue)', value: '$awaitingReviews', color: const Color(0xFFF59E0B)),
                              StatCard(icon: Icons.check_circle_outline, label: 'Target Met (Verified)', value: '$verifiedMet', color: const Color(0xFF10B981)),
                              StatCard(icon: Icons.error_outline_rounded, label: 'Doubtful Reviews', value: '$doubtfulCount', color: const Color(0xFFEF4444)),
                            ]),
                            const SizedBox(height: 24),

                            // ── Weekly Batch Summary Table ──
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('${activeWeek.label} Batch Progress Table (Target: ${activeWeek.targetCumulative})',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              Text('Showing ${students.length} students', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ]),
                            const SizedBox(height: 12),

                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: students.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final s = students[idx];
                                  final sub = subMap[s.uid];
                                  final targetMet = sub?.isTargetMet(activeWeek.targetCumulative) ?? false;
                                  final isVerified = sub?.verificationStatus == 'VERIFIED';
                                  final isDoubtful = sub?.verificationStatus == 'DOUBTFUL';
                                  final isPending = sub != null && sub.status == 'AWAITING_REVIEW';

                                  final statusText = targetMet
                                      ? 'Met ($sub.verifiedCount)'
                                      : (isVerified
                                          ? 'Below ($sub.verifiedCount)'
                                          : (isDoubtful
                                              ? 'Doubtful'
                                              : (isPending ? 'Awaiting Review' : 'Not Submitted')));

                                  final statusColor = targetMet
                                      ? Colors.green
                                      : (isDoubtful ? Colors.red : (isPending ? Colors.orange : Colors.grey));

                                  return ListTile(
                                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    subtitle: Text('Roll: ${s.studentCode} • Claimed: ${sub?.claimedCount ?? 0} • Verified: ${sub?.verifiedCount ?? 0}'),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ]);
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
