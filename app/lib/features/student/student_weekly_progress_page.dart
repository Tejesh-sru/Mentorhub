import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sru_branding.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/providers.dart';
import '../../models/cssp_models.dart';

class StudentWeeklyProgressPage extends ConsumerStatefulWidget {
  const StudentWeeklyProgressPage({super.key});

  @override
  ConsumerState<StudentWeeklyProgressPage> createState() => _StudentWeeklyProgressPageState();
}

class _StudentWeeklyProgressPageState extends ConsumerState<StudentWeeklyProgressPage> {
  String _selectedWeekId = 'W1';
  final _countCtrl = TextEditingController();
  final _problemNameCtrl = TextEditingController();
  final _problemUrlCtrl = TextEditingController();
  final _approachCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _countCtrl.dispose();
    _problemNameCtrl.dispose();
    _problemUrlCtrl.dispose();
    _approachCtrl.dispose();
    super.dispose();
  }

  void _populateForm(WeeklySubmission? sub) {
    if (sub != null) {
      _countCtrl.text = sub.claimedCount > 0 ? '${sub.claimedCount}' : '';
      _problemNameCtrl.text = sub.problemName ?? '';
      _problemUrlCtrl.text = sub.problemUrl ?? '';
      _approachCtrl.text = sub.approach ?? '';
    } else {
      _countCtrl.clear();
      _problemNameCtrl.clear();
      _problemUrlCtrl.clear();
      _approachCtrl.clear();
    }
  }

  Future<void> _submitProgress(String batchId, String uid) async {
    final count = int.tryParse(_countCtrl.text.trim());
    if (count == null || count < 0) {
      setState(() => _error = 'Please enter a valid cumulative LeetCode solved count (0 or greater).');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final payload = {
        'batchId': batchId,
        'weekId': _selectedWeekId,
        'juniorUid': uid,
        'claimedCount': count,
        'problemName': _problemNameCtrl.text.trim().isEmpty ? null : _problemNameCtrl.text.trim(),
        'problemUrl': _problemUrlCtrl.text.trim().isEmpty ? null : _problemUrlCtrl.text.trim(),
        'approach': _approachCtrl.text.trim().isEmpty ? null : _approachCtrl.text.trim(),
      };

      try {
        await ref.read(apiProvider).submitWeeklyProgress(payload);
      } catch (_) {
        // Direct Firestore fallback for client resilience
        final docId = '${batchId}_${_selectedWeekId}_$uid';
        await ref.read(firestoreProvider).collection('submissions').doc(docId).set({
          'batchId': batchId,
          'weekId': _selectedWeekId,
          'juniorUid': uid,
          'studentId': uid,
          'claimedCount': count,
          'problemName': _problemNameCtrl.text.trim().isEmpty ? null : _problemNameCtrl.text.trim(),
          'problemUrl': _problemUrlCtrl.text.trim().isEmpty ? null : _problemUrlCtrl.text.trim(),
          'approach': _approachCtrl.text.trim().isEmpty ? null : _approachCtrl.text.trim(),
          'status': 'AWAITING_REVIEW',
          'submittedAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Weekly progress for $_selectedWeekId submitted! Awaiting Senior Mentor review.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Submission failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final studentAsync = ref.watch(myStudentProfileProvider);
    final batchId = user?.batchId ?? 'default';

    final weeksAsync = ref.watch(csspWeeksProvider(batchId));
    final submissionsAsync = ref.watch(csspStudentSubmissionsProvider(user?.uid ?? ''));

    return PageBody(
      title: 'Submit Weekly Progress',
      subtitle: 'Submit cumulative LeetCode count and optional explainable problem for weekly review',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header Card ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [SruColors.navy, SruColors.royal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text(
                  '12-Week LeetCode Milestone Tracking',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Seniors verify learning through live explanation. Claims remain "Awaiting Review" until verified.',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            const CircleAvatar(
              backgroundColor: Colors.white24,
              radius: 24,
              child: Icon(Icons.show_chart_rounded, color: Colors.white, size: 28),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        weeksAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
          error: (e, _) => ErrorView(e),
          data: (weeks) {
            final activeWeek = weeks.firstWhere(
              (w) => w.weekId == _selectedWeekId,
              orElse: () => weeks.first,
            );

            return submissionsAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
              error: (e, _) => ErrorView(e),
              data: (submissions) {
                final currentSub = submissions.where((s) => s.weekId == _selectedWeekId).firstOrNull;

                // Sync form controllers on week change
                // Only if not currently editing
                if (_countCtrl.text.isEmpty && currentSub != null) {
                  _populateForm(currentSub);
                }

                final bool isVerified = currentSub?.verificationStatus == 'VERIFIED';
                final bool isDoubtful = currentSub?.verificationStatus == 'DOUBTFUL';
                final bool isPending = currentSub != null && currentSub.status == 'AWAITING_REVIEW';

                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // ── Week Selector Pills ──
                  const Text('Select Mentoring Week:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: weeks.map((w) {
                        final selected = w.weekId == _selectedWeekId;
                        final weekSub = submissions.where((s) => s.weekId == w.weekId).firstOrNull;
                        final subStatus = weekSub?.verificationStatus ?? (weekSub != null ? 'PENDING' : 'NONE');

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(w.label),
                              const SizedBox(width: 6),
                              if (subStatus == 'VERIFIED')
                                const Icon(Icons.check_circle, size: 14, color: Colors.green)
                              else if (subStatus == 'DOUBTFUL')
                                const Icon(Icons.error_outline, size: 14, color: Colors.red)
                              else if (subStatus == 'PENDING')
                                const Icon(Icons.hourglass_top, size: 14, color: Colors.orange),
                            ]),
                            selected: selected,
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _selectedWeekId = w.weekId;
                                  _error = null;
                                });
                                final newSub = submissions.where((s) => s.weekId == w.weekId).firstOrNull;
                                _populateForm(newSub);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Selected Week Status Card ──
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('${activeWeek.label} Overview', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isVerified
                                ? Colors.green.shade50
                                : (isDoubtful ? Colors.red.shade50 : (isPending ? Colors.orange.shade50 : Colors.grey.shade100)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isVerified
                                  ? Colors.green
                                  : (isDoubtful ? Colors.red : (isPending ? Colors.orange : Colors.grey)),
                            ),
                          ),
                          child: Text(
                            isVerified
                                ? 'Verified'
                                : (isDoubtful ? 'Doubtful Review' : (isPending ? 'Awaiting Review' : 'Not Submitted')),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isVerified
                                  ? Colors.green.shade800
                                  : (isDoubtful ? Colors.red.shade800 : (isPending ? Colors.orange.shade800 : Colors.black54)),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: _MiniMetric(
                            label: 'Mentoring Week',
                            value: activeWeek.label,
                            icon: Icons.calendar_month_outlined,
                            color: SruColors.navy,
                          ),
                        ),
                        Expanded(
                          child: _MiniMetric(
                            label: 'Your Claimed Total',
                            value: currentSub != null ? '${currentSub.claimedCount}' : 'None',
                            icon: Icons.edit_note_rounded,
                            color: SruColors.cyan,
                          ),
                        ),
                        Expanded(
                          child: _MiniMetric(
                            label: 'Verified Count',
                            value: currentSub?.verifiedCount != null ? '${currentSub!.verifiedCount}' : 'Pending',
                            icon: Icons.verified_outlined,
                            color: isVerified ? Colors.green : Colors.grey,
                          ),
                        ),
                      ]),
                      if (currentSub?.remarks != null && currentSub!.remarks!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Row(children: [
                            const Icon(Icons.comment_outlined, size: 16, color: Colors.brown),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Senior Remark: "${currentSub.remarks}" (Seriousness: ${currentSub.seriousness ?? 'N/A'})',
                                style: const TextStyle(fontSize: 12, color: Colors.brown, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // ── Progress Submission Form ──
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Submit / Update Claim for ${activeWeek.label}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter your latest cumulative total problems solved on LeetCode. You may also specify one problem you solved to explain live to your senior mentor.',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                        ),
                      TextField(
                        controller: _countCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Cumulative LeetCode Total Count *',
                          hintText: 'e.g. 115 (must be >= 0)',
                          helperText: 'Enter total problems solved as of ${activeWeek.label}',
                          prefixIcon: const Icon(Icons.numbers_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _problemNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Explainable Problem Name (Optional)',
                          hintText: 'e.g. 3Sum / Longest Palindromic Substring',
                          prefixIcon: const Icon(Icons.code_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _problemUrlCtrl,
                        decoration: InputDecoration(
                          labelText: 'Problem URL (Optional)',
                          hintText: 'https://leetcode.com/problems/...',
                          prefixIcon: const Icon(Icons.link_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _approachCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Approach & Solution Explanation (Optional)',
                          hintText: 'Briefly explain algorithm, time/space complexity O(N)...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _submitting ? null : () => _submitProgress(batchId, user?.uid ?? ''),
                          icon: _submitting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send_rounded),
                          label: Text(_submitting ? 'Submitting...' : 'Submit Progress for Review'),
                        ),
                      ),
                    ]),
                  ),
                ]);
              },
            );
          },
        ),
      ]),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value, required this.icon, required this.color});
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SruColors.blueBorder, width: 1.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x061E40AF),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
      ]),
    );
  }
}
