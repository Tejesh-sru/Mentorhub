import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/sru_branding.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/providers.dart';
import '../../models/models.dart';

Future<void> openExternalUrl(BuildContext context, String rawUrl, {String? label}) async {
  var cleaned = rawUrl.trim();
  if (cleaned.isEmpty) return;
  if (cleaned.startsWith('https:/') && !cleaned.startsWith('https://')) {
    cleaned = cleaned.replaceFirst('https:/', 'https://');
  } else if (cleaned.startsWith('http:/') && !cleaned.startsWith('http://')) {
    cleaned = cleaned.replaceFirst('http:/', 'http://');
  } else if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
    cleaned = 'https://$cleaned';
  }
  final uri = Uri.tryParse(cleaned);
  if (uri != null) {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (launched) return;
  }
  await Clipboard.setData(ClipboardData(text: cleaned));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${label ?? "Link"} copied to clipboard: $cleaned')),
    );
  }
}

void showMenteeProfileDialog(
  BuildContext context, {
  required StudentProfile student,
  MentorProfile? mentor,
  String? batchName,
}) {
  showDialog(
    context: context,
    builder: (_) => MenteeProfileDialog(
      student: student,
      mentor: mentor,
      batchName: batchName,
    ),
  );
}

class MenteeProfileDialog extends ConsumerStatefulWidget {
  final StudentProfile student;
  final MentorProfile? mentor;
  final String? batchName;

  const MenteeProfileDialog({
    super.key,
    required this.student,
    this.mentor,
    this.batchName,
  });

  @override
  ConsumerState<MenteeProfileDialog> createState() => _MenteeProfileDialogState();
}

class _MenteeProfileDialogState extends ConsumerState<MenteeProfileDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _milestoneColor(String milestone) {
    switch (milestone) {
      case 'Diamond Champion':
        return const Color(0xFF0284C7);
      case 'Gold Solver':
        return const Color(0xFFD97706);
      case 'Silver Solver':
        return const Color(0xFF475569);
      case 'Bronze Solver':
        return const Color(0xFFB45309);
      case 'Rising Coder':
        return const Color(0xFF059669);
      default:
        return SruColors.primary;
    }
  }

  IconData _milestoneIcon(String milestone) {
    switch (milestone) {
      case 'Diamond Champion':
        return Icons.diamond_rounded;
      case 'Gold Solver':
        return Icons.emoji_events_rounded;
      case 'Silver Solver':
        return Icons.workspace_premium_rounded;
      case 'Bronze Solver':
        return Icons.military_tech_rounded;
      case 'Rising Coder':
        return Icons.trending_up_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final assignmentsAsync = ref.watch(studentAssignmentsProvider(s.uid));
    final submissionsAsync = ref.watch(studentSubmissionsForMentorProvider(s.uid));
    final potdSubsAsync = ref.watch(studentPotdSubmissionsProvider(s.uid));

    final potdCount = potdSubsAsync.valueOrNull?.length ?? s.potdCount;
    final milestone = computeMilestone(potdCount, s.progress.completed);
    final mColor = _milestoneColor(milestone);
    final mentorLabel = widget.mentor != null
        ? '${widget.mentor!.name} (${widget.mentor!.mentorCode})'
        : (s.mentorName != null ? '${s.mentorName} (${s.mentorCode ?? ""})' : 'Unassigned');
    final bName = widget.batchName ?? s.batchName ?? s.batchId;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 960,
        height: 780,
        child: Column(
          children: [
            // ── Top University Blue Profile Header ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
              decoration: const BoxDecoration(
                color: SruColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: SruColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              s.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            _headerBadge(s.studentCode, Colors.white.withOpacity(0.18), Colors.white),
                            if (s.branch != null && s.branch!.isNotEmpty)
                              _headerBadge(s.branch!, const Color(0xFFDBEAFE), SruColors.primary),
                            _headerBadge('Batch: $bName', const Color(0xFFFEF3C7), const Color(0xFF92400E)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${s.email}  •  Mentor: $mentorLabel',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.88),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Milestone & POTD Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_milestoneIcon(milestone), color: mColor, size: 22),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              milestone.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: mColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                            Text(
                              'POTD Solved: $potdCount 🔥',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: SruColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Close Profile',
                  ),
                ],
              ),
            ),

            // ── Coding Profiles & Analytics Summary Strip ──
            Container(
              width: double.infinity,
              color: SruColors.surfaceBlue.withOpacity(0.45),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Coding profile links
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _platformChip(context, 'LeetCode', s.leetcode, Icons.code_rounded, const Color(0xFFD97706)),
                      _platformChip(context, 'Codeforces', s.codeforce, Icons.leaderboard_rounded, const Color(0xFF2563EB)),
                      _platformChip(context, 'HackerRank', s.hackerrank, Icons.terminal_rounded, const Color(0xFF059669)),
                      _platformChip(context, 'GitHub', s.github, Icons.hub_rounded, const Color(0xFF1F2937)),
                      _platformChip(context, 'LinkedIn', s.linkedin, Icons.business_center_rounded, const Color(0xFF0284C7)),
                      _platformChip(context, 'Resume PDF', s.resume, Icons.description_rounded, const Color(0xFFDC2626)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Task & POTD Analytics KPI Cards
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _miniMetric('Completion', '${s.progress.percentage.toStringAsFixed(0)}%', SruColors.primary),
                      _miniMetric('Tasks Assigned', '${s.progress.assigned}', const Color(0xFF374151)),
                      _miniMetric('Tasks Approved', '${s.progress.completed}', const Color(0xFF059669)),
                      _miniMetric('Pending / Active', '${s.progress.pending}', const Color(0xFFD97706)),
                      _miniMetric('Awaiting Review', '${s.progress.awaitingReview}', const Color(0xFF7C3AED)),
                      _miniMetric('Overdue', '${s.progress.overdue}', const Color(0xFFDC2626)),
                      _miniMetric('POTD Count', '$potdCount Solved', const Color(0xFF0284C7)),
                    ],
                  ),
                ],
              ),
            ),

            // ── Tabs: Assigned Tasks | Submissions & Reviews | POTD History ──
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: SruColors.primary,
                unselectedLabelColor: SruColors.textSecondary,
                indicatorColor: SruColors.primary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                tabs: [
                  Tab(text: 'Assigned Tasks (${assignmentsAsync.valueOrNull?.length ?? 0})'),
                  Tab(text: 'Submissions & Reviews (${submissionsAsync.valueOrNull?.length ?? 0})'),
                  Tab(text: 'POTD Solved ($potdCount)'),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: Container(
                color: Colors.white,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Assigned Tasks
                    assignmentsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => ErrorView(e),
                      data: (list) => list.isEmpty
                          ? const EmptyState(
                              icon: Icons.assignment_outlined,
                              title: 'No tasks assigned yet',
                              message: 'Use Bulk Problem Assign to assign coding problems to this mentee.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(20),
                              itemCount: list.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final a = list[i];
                                return ListTile(
                                  leading: DifficultyBadge(a.difficulty),
                                  title: Text(a.taskTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                    '${a.platform} • ${a.topic} • Due ${DateFormat('dd MMM yyyy').format(a.deadline)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (a.problemUrl.isNotEmpty)
                                        IconButton(
                                          tooltip: 'Open Problem URL',
                                          icon: const Icon(Icons.open_in_new_rounded, size: 18, color: SruColors.primary),
                                          onPressed: () => openExternalUrl(context, a.problemUrl, label: a.taskTitle),
                                        ),
                                      StatusBadge(a.status),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    // Tab 2: Submissions & Direct Code Review
                    submissionsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => ErrorView(e),
                      data: (list) => list.isEmpty
                          ? const EmptyState(
                              icon: Icons.rate_review_outlined,
                              title: 'No task submissions yet',
                              message: 'When this student submits solutions, they appear here for inspection & review.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(20),
                              itemCount: list.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (_, i) => _SubmissionReviewCard(submission: list[i]),
                            ),
                    ),

                    // Tab 3: POTD Solved History
                    potdSubsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => ErrorView(e),
                      data: (list) => list.isEmpty
                          ? const EmptyState(
                              icon: Icons.local_fire_department_outlined,
                              title: 'No Problem of the Day solved yet',
                              message: 'Daily problems solved by this student will be tracked here toward milestones.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(20),
                              itemCount: list.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final p = list[i];
                                return ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFDBEAFE),
                                    child: Icon(Icons.bolt_rounded, color: SruColors.primary),
                                  ),
                                  title: Text(p.potdTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                    'Date: ${p.dateKey}${p.approach != null && p.approach!.isNotEmpty ? " • Approach: ${p.approach}" : ""}',
                                  ),
                                  trailing: p.solutionUrl.isNotEmpty
                                      ? OutlinedButton.icon(
                                          icon: const Icon(Icons.open_in_new_rounded, size: 15),
                                          label: const Text('Open Solution'),
                                          onPressed: () => openExternalUrl(context, p.solutionUrl, label: 'Solution'),
                                        )
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _platformChip(BuildContext context, String label, String? url, IconData icon, Color color) {
    final hasUrl = url != null && url.trim().isNotEmpty;
    return Tooltip(
      message: hasUrl ? 'Open $label ($url)' : '$label not linked',
      child: InkWell(
        onTap: hasUrl ? () => openExternalUrl(context, url, label: label) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: hasUrl ? Colors.white : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: hasUrl ? color.withOpacity(0.4) : SruColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: hasUrl ? color : Colors.grey),
              const SizedBox(width: 6),
              Text(
                hasUrl ? label : '$label (Not linked)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: hasUrl ? SruColors.textPrimary : Colors.grey,
                ),
              ),
              if (hasUrl) ...[
                const SizedBox(width: 4),
                Icon(Icons.open_in_new_rounded, size: 12, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SruColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: SruColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}

class _SubmissionReviewCard extends ConsumerStatefulWidget {
  final Submission submission;
  const _SubmissionReviewCard({required this.submission});

  @override
  ConsumerState<_SubmissionReviewCard> createState() => _SubmissionReviewCardState();
}

class _SubmissionReviewCardState extends ConsumerState<_SubmissionReviewCard> {
  bool _busy = false;

  Future<void> _updateReview(String decision) async {
    setState(() => _busy = true);
    try {
      final db = ref.read(firestoreProvider);
      final s = widget.submission;
      await db.doc('submissions/${s.id}').update({
        'reviewStatus': decision,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      await db.doc('assignments/${s.assignmentId}').update({
        'status': decision,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      // Recompute student stats
      final asgSnap = await db.collection('assignments').where('studentId', isEqualTo: s.studentId).get();
      final stats = <String, int>{
        'ASSIGNED': 0,
        'IN_PROGRESS': 0,
        'SUBMITTED': 0,
        'APPROVED': 0,
        'NEEDS_CHANGES': 0,
        'OVERDUE': 0,
      };
      for (final d in asgSnap.docs) {
        final st = (d.data()['status'] ?? 'ASSIGNED') as String;
        stats[st] = (stats[st] ?? 0) + 1;
      }
      await db.doc('students/${s.studentId}').update({'stats': stats});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SruColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${s.taskTitle} (Rev #${s.revision})',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              StatusBadge(s.reviewStatus),
            ],
          ),
          const SizedBox(height: 6),
          Text('Approach: ${s.approach}', style: const TextStyle(fontSize: 12)),
          Text('Complexity: Time ${s.timeComplexity} • Space ${s.spaceComplexity}',
              style: const TextStyle(fontSize: 12, color: SruColors.textSecondary)),
          if (s.solutionUrl != null && s.solutionUrl!.isNotEmpty) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => openExternalUrl(context, s.solutionUrl!, label: 'Solution URL'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.open_in_new_rounded, size: 14, color: SruColors.link),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Solution URL: ${s.solutionUrl}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: SruColors.link,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (s.reviewStatus != 'APPROVED')
                FilledButton.icon(
                  onPressed: _busy ? null : () => _updateReview('APPROVED'),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Approve'),
                ),
              const SizedBox(width: 8),
              if (s.reviewStatus != 'NEEDS_CHANGES')
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _updateReview('NEEDS_CHANGES'),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Request Changes'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
