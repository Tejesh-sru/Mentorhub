import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/cssp_models.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentMocksPage extends ConsumerWidget {
  const StudentMocksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final batchId = user?.batchId ?? 'default';

    final weeksAsync = ref.watch(csspWeeksProvider(batchId));
    final mocksAsync = ref.watch(csspStudentMocksProvider(user?.uid ?? ''));

    return PageBody(
      title: 'Mock Interview Feedback & Results',
      subtitle: 'View scheduled mock interviews, rubrics scores, and actionable mentor recommendations',
      child: weeksAsync.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        error: (e, _) => ErrorView(e),
        data: (weeks) {
          return mocksAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ErrorView(e),
            data: (mocks) {
              final mockMap = {for (var m in mocks) m.weekId: m};

              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Info banner explaining the rubric
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Weekly mocks assess live problem solving. Scores are evaluated independently: Overall /10, Technical /5, Communication /5, and Problem Solving /5.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF1E1B4B)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: weeks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final week = weeks[index];
                    final mock = mockMap[week.weekId];

                    final status = mock?.status ?? 'NOT_PLANNED';
                    final isCompleted = status == 'COMPLETED';
                    final isScheduled = status == 'SCHEDULED';
                    final isMissed = status == 'MISSED';

                    final Color statusColor = switch (status) {
                      'COMPLETED' => const Color(0xFF10B981),
                      'SCHEDULED' => const Color(0xFF0284C7),
                      'MISSED' => const Color(0xFFEF4444),
                      _ => Colors.grey,
                    };

                    final String statusLabel = switch (status) {
                      'COMPLETED' => 'Completed',
                      'SCHEDULED' => 'Scheduled',
                      'MISSED' => 'Missed (Rescheduling)',
                      _ => 'Not Planned',
                    };

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: isCompleted ? Colors.green.shade200 : Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text('${week.label} Mock Interview',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ]),
                          if (mock?.scheduledAt != null) ...[
                            const SizedBox(height: 6),
                            Row(children: [
                              const Icon(Icons.event, size: 14, color: Colors.black54),
                              const SizedBox(width: 4),
                              Text(
                                'Scheduled Time: ${Format.date(mock!.scheduledAt!)}',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ]),
                          ],
                          const SizedBox(height: 12),

                          if (isCompleted) ...[
                            Row(children: [
                              Expanded(
                                child: _ScorePill(
                                  label: 'Overall Score',
                                  score: '${mock?.score10?.toStringAsFixed(1) ?? "—"}/10',
                                  color: const Color(0xFF4F46E5),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _ScorePill(
                                  label: 'Technical',
                                  score: '${mock?.technical5?.toStringAsFixed(1) ?? "—"}/5',
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _ScorePill(
                                  label: 'Communication',
                                  score: '${mock?.communication5?.toStringAsFixed(1) ?? "—"}/5',
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _ScorePill(
                                  label: 'Problem Solving',
                                  score: '${mock?.problemSolving5?.toStringAsFixed(1) ?? "—"}/5',
                                  color: const Color(0xFF7C3AED),
                                ),
                              ),
                            ]),
                            if (mock?.recommendation != null && mock!.recommendation!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                                child: Row(children: [
                                  const Icon(Icons.thumb_up_alt_outlined, size: 16, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Recommendation: ${mock.recommendation}',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade900),
                                    ),
                                  ),
                                ]),
                              ),
                            ],
                            if (mock?.notes != null && mock!.notes!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                  'Mentor Notes: ${mock.notes}',
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                              ),
                            ],
                          ] else if (isScheduled) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  const Icon(Icons.alarm, color: Colors.blue, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      mock?.topic != null && mock!.topic!.isNotEmpty
                                          ? 'Topic: ${mock.topic}'
                                          : 'Your mock interview is scheduled. Prepare to explain your approaches live.',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                                    ),
                                  ),
                                  if (mock?.durationMinutes != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(6)),
                                      child: Text('${mock!.durationMinutes} min', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                                    ),
                                ]),
                                if (mock?.notes != null && mock!.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Mentor Preparation Guidance: ${mock.notes}',
                                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                                  ),
                                ],
                                if (mock?.meetingLink != null && mock!.meetingLink!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.video_call_rounded, size: 18),
                                    label: const Text('Join Live Mock Meeting'),
                                    onPressed: () async {
                                      final uri = Uri.tryParse(mock.meetingLink!.trim());
                                      if (uri != null) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      }
                                    },
                                  ),
                                ],
                              ]),
                            ),
                          ] else if (isMissed) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                              child: const Row(children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This mock was missed. Contact your Senior Mentor to reschedule.',
                                    style: TextStyle(fontSize: 12, color: Colors.red),
                                  ),
                                ),
                              ]),
                            ),
                          ] else ...[
                            Text('No mock scheduled yet for this week.',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                          ],
                        ]),
                      ),
                    );
                  },
                ),
              ]);
            },
          );
        },
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.label, required this.score, required this.color});
  final String label, score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.black54), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(score, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      ]),
    );
  }
}
