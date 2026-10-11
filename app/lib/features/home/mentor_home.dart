import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/progress.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/providers.dart';
import '../../models/cssp_models.dart';
import '../../models/models.dart';
import '../mentor/student_detail_page.dart';

class MentorHome extends ConsumerWidget {
  const MentorHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final students = ref.watch(mentorStudentsProvider);

    return PageBody(
      title: 'Mentor Dashboard',
      subtitle: 'Monitor mentee progress, review submissions, and manage tasks',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Modern Welcome Banner ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B365D), Color(0xFF0F3D8C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B365D).withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Welcome back, ${user?.name.split(' ').first ?? 'Mentor'}! 👋',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Keep your mentees motivated with regular reviews, code feedback, and timely task assignments.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 30),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Main Content ──
        students.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(mentorStudentsProvider)),
          data: (list) {
            final avg = Progress.average(list.map((s) => s.progress));
            final pending = list.fold<int>(0, (s, e) => s + e.progress.awaitingReview);
            final overdue = list.fold<int>(0, (s, e) => s + e.progress.overdue);

            final missingLinksCount = list.where((s) =>
                !ProfileLinksHelper.isValidUrl(s.leetcode) ||
                !ProfileLinksHelper.isValidUrl(s.github) ||
                !ProfileLinksHelper.isValidUrl(s.linkedin) ||
                !ProfileLinksHelper.isValidUrl(s.resume)).length;

            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── CSSP Mentor Tracker Metrics Grid ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('CSSP Progress & Verification Metrics',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF1B365D).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text('Allocated: ${list.length} Mentees',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1B365D))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StatGrid(children: [
                StatCard(icon: Icons.groups_rounded, label: 'Total Juniors', value: '${list.length}', color: const Color(0xFF1B365D)),
                StatCard(icon: Icons.hourglass_top_rounded, label: 'Awaiting Review', value: '$pending', color: const Color(0xFFF59E0B)),
                StatCard(icon: Icons.check_circle_outline, label: 'Average Rate', value: '$avg%', color: const Color(0xFF10B981)),
                StatCard(icon: Icons.link_off_rounded, label: 'Missing Links', value: '$missingLinksCount', color: missingLinksCount > 0 ? const Color(0xFFEA580C) : Colors.grey),
              ]),
              const SizedBox(height: 28),

              // Pending Submissions Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.inbox_rounded, color: Color(0xFF1B365D), size: 20),
                      SizedBox(width: 8),
                      Text('Pending Submissions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A))),
                    ],
                  ),
                  if (pending > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$pending Action Required',
                        style: const TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const PendingSubmissionsList(),
              const SizedBox(height: 32),

              // My Students Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.people_outline_rounded, color: Color(0xFF1B365D), size: 20),
                      SizedBox(width: 8),
                      Text('My Assigned Students', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A))),
                    ],
                  ),
                  Text(
                    'Tap any student to view full details',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppCard(
                child: list.isEmpty
                    ? const EmptyState(title: 'No students assigned yet', message: 'Assigned mentees will appear here.')
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, i) {
                          final s = list[i];
                          return InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => StudentDetailPage(student: s)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFF1B365D).withOpacity(0.1),
                                    foregroundColor: const Color(0xFF1B365D),
                                    child: Text(
                                      s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                s.name,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                s.studentCode,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${s.progress.completed}/${s.progress.assigned} done'
                                          '${s.progress.overdue > 0 ? ' • ${s.progress.overdue} overdue' : ''}',
                                          style: TextStyle(
                                            color: s.progress.overdue > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  SizedBox(
                                    width: 140,
                                    child: ProgressLine(s.progress.percentage),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ]);
          },
        ),
      ]),
    );
  }
}

class PendingSubmissionsList extends ConsumerWidget {
  const PendingSubmissionsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(mentorSubmissionsProvider);
    return list.when(
      loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(mentorSubmissionsProvider)),
      data: (items) => items.isEmpty
          ? const AppCard(child: EmptyState(title: 'All caught up! 🎉', message: 'No pending submissions awaiting review.'))
          : AppCard(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, i) {
                  final s = items[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.code_rounded, color: Color(0xFFD97706), size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.taskTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(
                                'By ${s.studentName} (${s.studentCode}) • submitted ${timeUntil(s.submittedAt)}',
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1B365D),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (c) => ReviewDialog(submission: s, ref: ref),
                          ),
                          icon: const Icon(Icons.rate_review_rounded, size: 16),
                          label: const Text('Review', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class ReviewDialog extends StatefulWidget {
  final Submission submission;
  final WidgetRef ref;
  const ReviewDialog({super.key, required this.submission, required this.ref});

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  final _feedback = TextEditingController();
  bool _loading = false;

  Future<void> _review(String decision) async {
    setState(() => _loading = true);
    try {
      await widget.ref.read(apiProvider).reviewSubmission(
            submissionId: widget.submission.id,
            decision: decision,
            feedback: _feedback.text,
          );
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, decision == 'APPROVED' ? 'Submission approved!' : 'Changes requested!');
      }
    } on ApiException catch (e) {
      if (mounted) {
        showSnack(context, e.message, error: true);
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Review Submission: ${s.taskTitle}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: Color(0xFF475569)),
                    const SizedBox(width: 6),
                    Text('${s.studentName} (${s.studentCode})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Approach & Solution Logic:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
              const SizedBox(height: 4),
              Text(s.approach, style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0).withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                child: Text('Time: ${s.timeComplexity}  •  Space: ${s.spaceComplexity}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              if (s.code != null && s.code!.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Code Preview:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(10)),
                  width: double.infinity,
                  child: Text(s.code!, style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 12)),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _feedback,
                decoration: const InputDecoration(labelText: 'Feedback for Student', hintText: 'Write feedback or optimization tips...'),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
          onPressed: _loading ? null : () => _review('NEEDS_CHANGES'),
          child: const Text('Needs Changes'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          onPressed: _loading ? null : () => _review('APPROVED'),
          child: const Text('Approve'),
        ),
      ],
    );
  }
}
