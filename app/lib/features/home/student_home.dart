import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/sru_branding.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/providers.dart';
import '../../models/cssp_models.dart';
import '../../models/models.dart';

class StudentHome extends ConsumerWidget {
  const StudentHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final profile = ref.watch(myStudentProfileProvider);

    return PageBody(
      title: 'Student Dashboard',
      subtitle: 'SR University CSSP Mentoring • Track daily problem solving, submissions, and mentor reviews',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── SRU Student Welcome Banner ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [SruColors.navy, SruColors.royal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: SruColors.navy.withOpacity(0.3),
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
                    Text(
                      'Welcome, ${user?.name.split(' ').first ?? 'Student'}! 🎓',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Consistency is key. Pick your next coding problem, implement the optimal approach, and submit with complexity analysis.',
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
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.code_rounded, color: Colors.white, size: 30),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── CSSP Quick Actions Grid ──
        Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(
            width: 240,
            child: _ActionTile(
              title: 'Problem of the Day 🔥',
              subtitle: 'Solve Daily LeetCode & Unlock Milestones',
              icon: Icons.local_fire_department_rounded,
              color: const Color(0xFFEA580C),
              onTap: () => context.go('/student/potd'),
            ),
          ),
          SizedBox(
            width: 240,
            child: _ActionTile(
              title: 'Complaint Box 🔒',
              subtitle: 'Confidential Report to Admin',
              icon: Icons.lock_person_outlined,
              color: const Color(0xFF7C3AED),
              onTap: () => context.go('/student/complaints'),
            ),
          ),
          SizedBox(
            width: 220,
            child: _ActionTile(
              title: 'Portfolio Links',
              subtitle: '6 Handles & Résumé',
              icon: Icons.link_rounded,
              color: const Color(0xFF10B981),
              onTap: () => context.go('/student/links'),
            ),
          ),
          SizedBox(
            width: 220,
            child: _ActionTile(
              title: 'Mock Interviews',
              subtitle: 'Scores & Rubrics',
              icon: Icons.rate_review_outlined,
              color: SruColors.red,
              onTap: () => context.go('/student/mocks'),
            ),
          ),
        ]),
        const SizedBox(height: 24),

        profile.when(
          loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => ErrorView(e),
          data: (p) {
            if (p == null) return const EmptyState(title: 'Profile not found');
            final pr = p.progress;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Student Identity, Mentor, & POTD Milestone Banner
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SruColors.blueBorder, width: 1.4),
                ),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: SruColors.primary,
                          foregroundColor: Colors.white,
                          child: Text(
                            p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p.name} (${p.studentCode})',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: SruColors.textPrimary),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Batch: ${(p.batchName?.isNotEmpty ?? false) ? p.batchName! : p.batchId} • Branch: ${p.branch ?? "CSE"} • Mentor: ${p.mentorName ?? "Assigned"} (${p.mentorCode ?? ""})',
                              style: const TextStyle(fontSize: 12, color: SruColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFED7AA)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department_rounded, color: Color(0xFFEA580C), size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'POTD Count: ${p.potdCount}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF9A3412)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: SruColors.surfaceBlue,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: SruColors.primary.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.emoji_events_rounded, color: SruColors.primary, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Milestone: ${p.milestone}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: SruColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StatGrid(children: [
                StatCard(icon: Icons.local_fire_department_rounded, label: 'POTD Solved Count', value: '${p.potdCount}', color: const Color(0xFFEA580C)),
                StatCard(icon: Icons.emoji_events_rounded, label: 'Current Milestone', value: p.milestone, color: SruColors.primary),
                StatCard(icon: Icons.assignment_outlined, label: 'Assigned Tasks', value: '${pr.assigned}', color: const Color(0xFF4F46E5)),
                StatCard(icon: Icons.check_circle_outline, label: 'Completed Tasks', value: '${pr.completed}', color: const Color(0xFF10B981)),
              ]),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Task Completion Progress (${pr.completed} of ${pr.assigned} approved)',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '${pr.percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0D9488)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ProgressLine(pr.percentage),
                ]),
              ),
            ]);
          },
        ),
        const SizedBox(height: 32),
        const Row(
          children: [
            Icon(Icons.terminal_rounded, color: Color(0xFF0D9488), size: 20),
            SizedBox(width: 8),
            Text('Assigned Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          ],
        ),
        const SizedBox(height: 14),
        const AssignmentList(),
      ]),
    );
  }
}

class StudentTasksPage extends StatelessWidget {
  const StudentTasksPage({super.key});

  @override
  Widget build(BuildContext context) => const PageBody(
        title: 'My Tasks',
        subtitle: 'Solve problems on the coding platform, then submit your explanation and code',
        child: AssignmentList(),
      );
}

class AssignmentList extends ConsumerWidget {
  const AssignmentList({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref, Assignment a) async {
    try {
      await ref.read(apiProvider).startAssignment(a.id);
      if (context.mounted) showSnack(context, 'Marked "${a.taskTitle}" as in progress! 🚀');
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, e.message, error: true);
    }
  }

  void _submit(BuildContext context, WidgetRef ref, Assignment a) {
    showDialog(context: context, builder: (c) => SubmitDialog(assignment: a, ref: ref));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(myAssignmentsProvider);
    return list.when(
      loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(myAssignmentsProvider)),
      data: (items) => items.isEmpty
          ? const AppCard(child: EmptyState(title: 'No tasks yet! 🎉', message: 'Your mentor will assign tasks soon.'))
          : AppCard(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, i) {
                  final a = items[i];
                  final isDone = a.status == 'COMPLETED';
                  final isOverdue = a.deadline.isBefore(DateTime.now()) && !isDone;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                a.taskTitle,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusChip(a.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (a.taskDescription != null && a.taskDescription!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              a.taskDescription!,
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                          ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                a.platform,
                                style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0891B2).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                a.topic,
                                style: const TextStyle(color: Color(0xFF0891B2), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                            StatusChip(a.difficulty),
                            Text(
                              '• Due ${fmtDate(a.deadline)} (${timeUntil(a.deadline)})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w500,
                                color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (a.problemUrl.isNotEmpty)
                              InkWell(
                                onTap: () => launchUrl(Uri.parse(a.problemUrl), mode: LaunchMode.externalApplication),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.open_in_new, size: 14, color: Color(0xFF0D9488)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Open Problem Statement',
                                      style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.w700, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            const Spacer(),
                            if (a.status == 'ASSIGNED')
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _start(context, ref, a),
                                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                label: const Text('Start Task', style: TextStyle(fontSize: 12)),
                              ),
                            if (a.status == 'IN_PROGRESS' || a.status == 'NEEDS_CHANGES' || a.status == 'NEEDS_REVISION')
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D9488),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _submit(context, ref, a),
                                icon: const Icon(Icons.upload_file_rounded, size: 16),
                                label: const Text('Submit Solution', style: TextStyle(fontSize: 12)),
                              ),
                            if (a.status == 'SUBMITTED')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.hourglass_bottom, size: 14, color: Color(0xFFD97706)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Under Review',
                                      style: TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                          ],
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

class SubmitDialog extends StatefulWidget {
  final Assignment assignment;
  final WidgetRef ref;
  const SubmitDialog({super.key, required this.assignment, required this.ref});

  @override
  State<SubmitDialog> createState() => _SubmitDialogState();
}

class _SubmitDialogState extends State<SubmitDialog> {
  final _understanding = TextEditingController();
  final _approach = TextEditingController();
  final _time = TextEditingController();
  final _space = TextEditingController();
  final _url = TextEditingController();
  final _code = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    if (_approach.text.trim().isEmpty) {
      showSnack(context, 'Please enter your approach.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.ref.read(apiProvider).submitAssignment({
        'assignmentId': widget.assignment.id,
        'understanding': _understanding.text,
        'approach': _approach.text,
        'timeComplexity': _time.text,
        'spaceComplexity': _space.text,
        'solutionUrl': _url.text,
        'code': _code.text,
      });
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'Successfully submitted ${widget.assignment.taskTitle}!');
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Submit Solution: ${widget.assignment.taskTitle}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _understanding,
                decoration: const InputDecoration(
                  labelText: 'Understanding of the Problem',
                  hintText: 'Briefly explain constraints and input/output...',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _approach,
                decoration: const InputDecoration(
                  labelText: 'Algorithm & Approach',
                  hintText: 'e.g. Used Hash Map to achieve O(N) lookup...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _time,
                    decoration: const InputDecoration(labelText: 'Time Complexity', hintText: 'e.g. O(N)'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _space,
                    decoration: const InputDecoration(labelText: 'Space Complexity', hintText: 'e.g. O(1)'),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'Solution / Submission URL',
                  hintText: 'https://leetcode.com/submissions/...',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _code,
                decoration: const InputDecoration(
                  labelText: 'Solution Code',
                  hintText: '// Paste your code here...',
                ),
                maxLines: 7,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Submit Solution'),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SruColors.blueBorder, width: 1.4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C1E40AF),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
