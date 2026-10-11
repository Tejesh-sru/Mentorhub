import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/sru_branding.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/app_user.dart';
import '../../models/models.dart';

class PotdPage extends ConsumerWidget {
  const PotdPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final potdsAsync = ref.watch(potdListProvider);
    final isStudent = user?.role == UserRole.student;
    final isMentorOrAdmin = user?.role == UserRole.mentor || user?.role == UserRole.admin || user?.role == UserRole.superAdmin;

    final myProfile = isStudent ? ref.watch(myStudentProfileProvider).valueOrNull : null;
    final myPotdSubs = isStudent ? (ref.watch(myPotdSubmissionsProvider).valueOrNull ?? []) : <PotdSubmission>[];
    final solvedPotdIds = myPotdSubs.map((s) => s.potdId).toSet();
    final potdCount = myPotdSubs.isNotEmpty ? myPotdSubs.length : (myProfile?.potdCount ?? 0);
    final milestone = computeMilestone(potdCount, myProfile?.progress.completed ?? 0);

    return PageBody(
      title: 'Problem of the Day (POTD)',
      subtitle: 'Daily coding challenge assigned by a Senior Mentor • Accessible to all 4 batches • Unlock profile milestones',
      actions: [
        if (isMentorOrAdmin)
          FilledButton.icon(
            icon: const Icon(Icons.local_fire_department_rounded, size: 18),
            label: const Text('Assign Today\'s POTD'),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const _AssignPotdDialog(),
            ),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Milestone Roadmap Banner ──
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFD97706), size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isStudent
                            ? 'Your POTD Solved Count: $potdCount 🔥  •  Current Milestone: $milestone'
                            : 'Student Milestone Tiers (Reflected on Student & Admin Profiles)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _milestoneTierCard('Rising Coder', '1+ POTD', Icons.trending_up_rounded, const Color(0xFF059669), potdCount >= 1),
                    _milestoneTierCard('Bronze Solver', '3+ POTDs', Icons.military_tech_rounded, const Color(0xFFB45309), potdCount >= 3),
                    _milestoneTierCard('Silver Solver', '7+ POTDs', Icons.workspace_premium_rounded, const Color(0xFF475569), potdCount >= 7),
                    _milestoneTierCard('Gold Solver', '15+ POTDs', Icons.emoji_events_rounded, const Color(0xFFD97706), potdCount >= 15),
                    _milestoneTierCard('Diamond Champion', '30+ POTDs', Icons.diamond_rounded, const Color(0xFF0284C7), potdCount >= 30),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Daily Problems Stream ──
          potdsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorView(e),
            data: (potds) {
              if (potds.isEmpty) {
                return const AppCard(
                  child: EmptyState(
                    icon: Icons.bolt_rounded,
                    title: 'No Problem of the Day posted yet',
                    message: 'A Senior Mentor or Admin can post today\'s Problem of the Day above.',
                  ),
                );
              }
              final todayPotd = potds.first;
              final pastPotds = potds.skip(1).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PotdHeroCard(
                    potd: todayPotd,
                    isToday: true,
                    isStudent: isStudent,
                    isSolved: solvedPotdIds.contains(todayPotd.id),
                    studentProfile: myProfile,
                  ),
                  if (pastPotds.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Previous Daily Challenges',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: SruColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...pastPotds.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PotdHeroCard(
                          potd: p,
                          isToday: false,
                          isStudent: isStudent,
                          isSolved: solvedPotdIds.contains(p.id),
                          studentProfile: myProfile,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _milestoneTierCard(String title, String reqText, IconData icon, Color color, bool unlocked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: unlocked ? color.withOpacity(0.1) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked ? color : SruColors.border,
          width: unlocked ? 1.8 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: unlocked ? color : Colors.grey, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: unlocked ? color : SruColors.textPrimary,
                ),
              ),
              Text(
                reqText,
                style: const TextStyle(fontSize: 11, color: SruColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (unlocked) ...[
            const SizedBox(width: 6),
            Icon(Icons.check_circle_rounded, color: color, size: 16),
          ],
        ],
      ),
    );
  }
}

class _PotdHeroCard extends ConsumerWidget {
  final ProblemOfTheDay potd;
  final bool isToday;
  final bool isStudent;
  final bool isSolved;
  final StudentProfile? studentProfile;

  const _PotdHeroCard({
    required this.potd,
    required this.isToday,
    required this.isStudent,
    required this.isSolved,
    this.studentProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isToday ? SruColors.primary : const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: Colors.amber, size: 15),
                    const SizedBox(width: 5),
                    Text(
                      isToday ? 'TODAY\'S PROBLEM • ${potd.dateKey}' : 'DAILY CHALLENGE • ${potd.dateKey}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              DifficultyBadge(potd.difficulty),
              Chip(
                label: Text('${potd.platform} • ${potd.topic}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                avatar: const Icon(Icons.people_alt_outlined, size: 15, color: SruColors.primary),
                label: Text('${potd.solvedCount} Students Solved', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                visualDensity: VisualDensity.compact,
              ),
              if (isSolved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 15),
                      SizedBox(width: 4),
                      Text(
                        'SOLVED & COUNTED IN PROFILE',
                        style: TextStyle(color: Color(0xFF047857), fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            potd.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: SruColors.textPrimary),
          ),
          if (potd.description != null && potd.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              potd.description!,
              style: const TextStyle(fontSize: 14, color: SruColors.textSecondary, height: 1.45),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Assigned by Mentor: ${potd.mentorName}${potd.mentorCode.isNotEmpty ? " (${potd.mentorCode})" : ""}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SruColors.primary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.link_rounded, size: 18),
                label: Text('Problem Link (${potd.platform})'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: potd.problemUrl));
                  showSnack(context, 'Problem link copied: ${potd.problemUrl}');
                },
              ),
              if (isStudent && !isSolved)
                FilledButton.icon(
                  icon: const Icon(Icons.task_alt_rounded, size: 18),
                  label: const Text('Submit POTD Solution & Claim Milestone'),
                  onPressed: studentProfile == null
                      ? null
                      : () => showDialog(
                            context: context,
                            builder: (_) => _SubmitPotdDialog(potd: potd, student: studentProfile!),
                          ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubmitPotdDialog extends ConsumerStatefulWidget {
  final ProblemOfTheDay potd;
  final StudentProfile student;

  const _SubmitPotdDialog({required this.potd, required this.student});

  @override
  ConsumerState<_SubmitPotdDialog> createState() => _SubmitPotdDialogState();
}

class _SubmitPotdDialogState extends ConsumerState<_SubmitPotdDialog> {
  final _url = TextEditingController();
  final _approach = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    _approach.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_url.text.trim().isEmpty) {
      showSnack(context, 'Please enter your solution/submission URL', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final db = ref.read(firestoreProvider);
      final s = widget.student;
      final p = widget.potd;
      final subId = '${p.id}_${s.uid}';
      final subRef = db.doc('potd_submissions/$subId');
      final existing = await subRef.get();

      await subRef.set({
        'potdId': p.id,
        'dateKey': p.dateKey,
        'studentId': s.uid,
        'studentName': s.name,
        'studentCode': s.studentCode,
        'batchId': s.batchId,
        'mentorId': s.mentorId,
        'potdTitle': p.title,
        'solutionUrl': _url.text.trim(),
        'approach': _approach.text.trim(),
        'completedAt': FieldValue.serverTimestamp(),
      });

      if (!existing.exists) {
        final newPotdCount = s.potdCount + 1;
        final newMilestone = computeMilestone(newPotdCount, s.progress.completed);
        await db.doc('students/${s.uid}').update({
          'potdCount': FieldValue.increment(1),
          'potdStreak': FieldValue.increment(1),
          'milestone': newMilestone,
        });
        await db.doc('potd/${p.id}').update({
          'solvedCount': FieldValue.increment(1),
        });

        // Send notification to the student's assigned Mentor
        if (s.mentorId != null && s.mentorId!.isNotEmpty) {
          await db.collection('notifications').add({
            'userId': s.mentorId,
            'title': 'POTD Solved by ${s.name} (${s.studentCode})',
            'message':
                '${s.name} solved "${p.title}" (${p.dateKey})! Total POTDs solved: $newPotdCount • Milestone: $newMilestone.',
            'type': 'POTD_SOLVED',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'POTD solution recorded! Your profile POTD count & milestone have been updated.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, 'Error: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Submit POTD: ${widget.potd.title}'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'Submission / Solution URL *',
                hintText: 'https://leetcode.com/submissions/detail/...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _approach,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Approach & Time Complexity (Optional)',
                hintText: 'Used Kadane\'s algorithm in O(N) time and O(1) space...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Submit & Update Profile'),
        ),
      ],
    );
  }
}

class _AssignPotdDialog extends ConsumerStatefulWidget {
  const _AssignPotdDialog();

  @override
  ConsumerState<_AssignPotdDialog> createState() => _AssignPotdDialogState();
}

class _AssignPotdDialogState extends ConsumerState<_AssignPotdDialog> {
  final _title = TextEditingController();
  final _url = TextEditingController();
  final _topic = TextEditingController(text: 'Dynamic Programming');
  final _desc = TextEditingController();
  String _platform = 'LEETCODE';
  String _difficulty = 'MEDIUM';
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _topic.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _url.text.trim().isEmpty) {
      showSnack(context, 'Enter problem title and URL', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final db = ref.read(firestoreProvider);
      final user = ref.read(currentUserProvider).valueOrNull;
      final mentorProfile = ref.read(myMentorProfileProvider).valueOrNull;
      final dateKey = DateFormat('yyyy-MM-dd').format(_date);

      await db.doc('potd/$dateKey').set({
        'id': dateKey,
        'dateKey': dateKey,
        'title': _title.text.trim(),
        'platform': _platform,
        'problemUrl': _url.text.trim(),
        'difficulty': _difficulty,
        'topic': _topic.text.trim(),
        'description': _desc.text.trim(),
        'mentorId': user?.uid ?? 'admin',
        'mentorName': mentorProfile?.name ?? user?.name ?? 'Senior Mentor',
        'mentorCode': mentorProfile?.mentorCode ?? 'ADMIN',
        'solvedCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'Problem of the Day published for $dateKey!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, 'Failed: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Daily Problem (POTD)'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text('Date: ${DateFormat('yyyy-MM-dd').format(_date)}'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Problem Title (e.g. Trapping Rain Water)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                decoration: const InputDecoration(labelText: 'Problem URL (LeetCode / Codeforces)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _platform,
                      decoration: const InputDecoration(labelText: 'Platform'),
                      items: const [
                        DropdownMenuItem(value: 'LEETCODE', child: Text('LeetCode')),
                        DropdownMenuItem(value: 'CODEFORCES', child: Text('Codeforces')),
                        DropdownMenuItem(value: 'HACKERRANK', child: Text('HackerRank')),
                      ],
                      onChanged: (v) => setState(() => _platform = v ?? 'LEETCODE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _difficulty,
                      decoration: const InputDecoration(labelText: 'Difficulty'),
                      items: const [
                        DropdownMenuItem(value: 'EASY', child: Text('Easy')),
                        DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                        DropdownMenuItem(value: 'HARD', child: Text('Hard')),
                      ],
                      onChanged: (v) => setState(() => _difficulty = v ?? 'MEDIUM'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _topic,
                decoration: const InputDecoration(labelText: 'Topic (e.g. Two Pointers / DP)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Problem Brief / Hint for Students'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Publish POTD to All Students'),
        ),
      ],
    );
  }
}
