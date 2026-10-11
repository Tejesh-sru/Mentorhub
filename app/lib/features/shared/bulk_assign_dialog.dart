import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/sru_branding.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/models.dart';

void showBulkProblemAssignDialog(
  BuildContext context, {
  required bool isAdmin,
  String? mentorUid,
  String? mentorBatchId,
}) {
  showDialog(
    context: context,
    builder: (_) => BulkProblemAssignDialog(
      isAdmin: isAdmin,
      mentorUid: mentorUid,
      mentorBatchId: mentorBatchId,
    ),
  );
}

class _DraftProblem {
  final TextEditingController title;
  final TextEditingController url;
  final TextEditingController topic;
  String platform;
  String difficulty;

  _DraftProblem({
    String titleText = '',
    String urlText = '',
    String topicText = 'Arrays & Hashing',
    this.platform = 'LEETCODE',
    this.difficulty = 'MEDIUM',
  })  : title = TextEditingController(text: titleText),
        url = TextEditingController(text: urlText),
        topic = TextEditingController(text: topicText);

  void dispose() {
    title.dispose();
    url.dispose();
    topic.dispose();
  }
}

class BulkProblemAssignDialog extends ConsumerStatefulWidget {
  final bool isAdmin;
  final String? mentorUid;
  final String? mentorBatchId;

  const BulkProblemAssignDialog({
    super.key,
    required this.isAdmin,
    this.mentorUid,
    this.mentorBatchId,
  });

  @override
  ConsumerState<BulkProblemAssignDialog> createState() => _BulkProblemAssignDialogState();
}

class _BulkProblemAssignDialogState extends ConsumerState<BulkProblemAssignDialog> {
  final List<_DraftProblem> _rows = [
    _DraftProblem(
      titleText: 'Two Sum',
      urlText: 'https://leetcode.com/problems/two-sum/',
      topicText: 'Arrays & Hash Map',
      platform: 'LEETCODE',
      difficulty: 'EASY',
    ),
    _DraftProblem(
      titleText: 'Longest Substring Without Repeating Characters',
      urlText: 'https://leetcode.com/problems/longest-substring-without-repeating-characters/',
      topicText: 'Sliding Window',
      platform: 'LEETCODE',
      difficulty: 'MEDIUM',
    ),
  ];

  final _csvController = TextEditingController();
  bool _pasteMode = false;
  String _selectedBatchId = 'ALL';
  String _selectedMentorFilter = 'ALL';
  DateTime _deadline = DateTime.now().add(const Duration(days: 7));
  bool _submitting = false;
  String? _statusText;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _csvController.dispose();
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _rows.add(_DraftProblem());
    });
  }

  void _loadPresetPack() {
    setState(() {
      for (final r in _rows) {
        r.dispose();
      }
      _rows.clear();
      _rows.addAll([
        _DraftProblem(
          titleText: 'Two Sum',
          urlText: 'https://leetcode.com/problems/two-sum/',
          topicText: 'Hash Table',
          platform: 'LEETCODE',
          difficulty: 'EASY',
        ),
        _DraftProblem(
          titleText: 'Valid Parentheses',
          urlText: 'https://leetcode.com/problems/valid-parentheses/',
          topicText: 'Stack',
          platform: 'LEETCODE',
          difficulty: 'EASY',
        ),
        _DraftProblem(
          titleText: 'Container With Most Water',
          urlText: 'https://leetcode.com/problems/container-with-most-water/',
          topicText: 'Two Pointers',
          platform: 'LEETCODE',
          difficulty: 'MEDIUM',
        ),
        _DraftProblem(
          titleText: '3Sum',
          urlText: 'https://leetcode.com/problems/3sum/',
          topicText: 'Two Pointers',
          platform: 'LEETCODE',
          difficulty: 'MEDIUM',
        ),
        _DraftProblem(
          titleText: 'Merge Intervals',
          urlText: 'https://leetcode.com/problems/merge-intervals/',
          topicText: 'Intervals / Sorting',
          platform: 'LEETCODE',
          difficulty: 'MEDIUM',
        ),
      ]);
    });
  }

  void _parseCsvText() {
    final lines = _csvController.text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return;
    setState(() {
      for (final r in _rows) {
        r.dispose();
      }
      _rows.clear();
      for (final line in lines) {
        final parts = line.split(',').map((p) => p.trim()).toList();
        if (parts.isEmpty || parts[0].toLowerCase() == 'title') continue;
        final title = parts[0];
        final url = parts.length > 1 ? parts[1] : '';
        final platform = parts.length > 2 && parts[2].isNotEmpty
            ? parts[2].toUpperCase()
            : (url.contains('codeforces')
                ? 'CODEFORCES'
                : url.contains('hackerrank')
                    ? 'HACKERRANK'
                    : 'LEETCODE');
        final diff = parts.length > 3 && ['EASY', 'MEDIUM', 'HARD'].contains(parts[3].toUpperCase())
            ? parts[3].toUpperCase()
            : 'MEDIUM';
        final topic = parts.length > 4 && parts[4].isNotEmpty ? parts[4] : 'DSA Practice';
        _rows.add(_DraftProblem(
          titleText: title,
          urlText: url,
          topicText: topic,
          platform: platform,
          difficulty: diff,
        ));
      }
      _pasteMode = false;
    });
  }

  Future<void> _assignBulk(List<StudentProfile> targetStudents) async {
    final validProblems = _rows
        .where((r) => r.title.text.trim().isNotEmpty && r.url.text.trim().isNotEmpty)
        .toList();
    if (validProblems.isEmpty) {
      showSnack(context, 'Add at least 1 problem with Title and URL', error: true);
      return;
    }
    if (targetStudents.isEmpty) {
      showSnack(context, 'No students match the selected target filter', error: true);
      return;
    }

    setState(() {
      _submitting = true;
      _statusText = 'Assigning ${validProblems.length} problems to ${targetStudents.length} students...';
    });

    try {
      final db = ref.read(firestoreProvider);
      final now = Timestamp.now();
      final deadlineTs = Timestamp.fromDate(_deadline);

      // 1. Create Task docs
      final createdTasks = <Map<String, dynamic>>[];
      for (final p in validProblems) {
        final taskRef = db.collection('tasks').doc();
        final taskData = {
          'title': p.title.text.trim(),
          'description': 'Solve ${p.title.text.trim()} (${p.topic.text.trim()})',
          'platform': p.platform,
          'problemUrl': p.url.text.trim(),
          'difficulty': p.difficulty,
          'topic': p.topic.text.trim().isEmpty ? 'DSA' : p.topic.text.trim(),
          'batchId': _selectedBatchId == 'ALL' ? (widget.mentorBatchId ?? 'g6_b1') : _selectedBatchId,
          'deadline': deadlineTs,
          'createdAt': now,
        };
        await taskRef.set(taskData);
        createdTasks.add({'id': taskRef.id, ...taskData});
      }

      // 2. Create Assignment docs and update Student stats in chunks
      WriteBatch batch = db.batch();
      int ops = 0;
      final notifiedMentors = <String>{};

      for (final stu in targetStudents) {
        for (final t in createdTasks) {
          final asgId = '${t['id']}_${stu.uid}';
          batch.set(db.doc('assignments/$asgId'), {
            'taskId': t['id'],
            'studentId': stu.uid,
            'mentorId': stu.mentorId,
            'batchId': stu.batchId,
            'status': 'ASSIGNED',
            'reminded': false,
            'deadline': deadlineTs,
            'taskTitle': t['title'],
            'taskDescription': t['description'],
            'platform': t['platform'],
            'problemUrl': t['problemUrl'],
            'difficulty': t['difficulty'],
            'topic': t['topic'],
            'studentName': stu.name,
            'studentCode': stu.studentCode,
            'assignedAt': now,
          });
          ops++;
          if (ops >= 380) {
            await batch.commit();
            batch = db.batch();
            ops = 0;
          }
        }

        final newAssigned = (stu.stats['ASSIGNED'] ?? 0) + createdTasks.length;
        final updatedStats = Map<String, int>.from(stu.stats);
        updatedStats['ASSIGNED'] = newAssigned;
        batch.update(db.doc('students/${stu.uid}'), {'stats': updatedStats});
        ops++;
        if (stu.mentorId != null && stu.mentorId!.isNotEmpty) {
          notifiedMentors.add(stu.mentorId!);
        }
        if (ops >= 380) {
          await batch.commit();
          batch = db.batch();
          ops = 0;
        }
      }

      // 3. Notify Mentors about the bulk assignment
      for (final mUid in notifiedMentors) {
        final nRef = db.collection('notifications').doc();
        batch.set(nRef, {
          'userId': mUid,
          'title': 'Bulk Coding Problems Assigned (${createdTasks.length})',
          'message':
              '${createdTasks.length} new problems (${createdTasks.map((e) => e['title']).take(3).join(", ")}) assigned with deadline ${DateFormat('dd MMM yyyy').format(_deadline)}.',
          'type': 'TASK_ASSIGNED',
          'isRead': false,
          'createdAt': now,
        });
        ops++;
        if (ops >= 380) {
          await batch.commit();
          batch = db.batch();
          ops = 0;
        }
      }

      if (ops > 0) {
        await batch.commit();
      }

      if (mounted) {
        Navigator.pop(context);
        showSnack(
          context,
          'Assigned ${createdProblemsCount(createdTasks)} problems to ${targetStudents.length} mentees!',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _statusText = null;
        });
        showSnack(context, 'Failed: $e', error: true);
      }
    }
  }

  int createdProblemsCount(List<Map<String, dynamic>> l) => l.length;

  @override
  Widget build(BuildContext context) {
    final batches = ref.watch(adminBatchesStreamProvider).valueOrNull ?? [];
    final mentors = ref.watch(adminMentorsProvider).valueOrNull ?? [];
    final allStudents = widget.isAdmin
        ? (ref.watch(adminStudentsProvider).valueOrNull ?? [])
        : (ref.watch(mentorStudentsProvider).valueOrNull ?? []);

    final targetStudents = allStudents.where((s) {
      if (!widget.isAdmin) return true;
      if (_selectedBatchId != 'ALL' && s.batchId != _selectedBatchId) return false;
      if (_selectedMentorFilter != 'ALL' && s.mentorId != _selectedMentorFilter) return false;
      return true;
    }).toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 960,
        height: 760,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                color: SruColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.playlist_add_check_circle_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bulk Problem Assignment',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          widget.isAdmin
                              ? 'Assign multiple coding problems at once across batches or mentor groups'
                              : 'Assign multiple coding problems at once to all your assigned mentees',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Target & Deadline Bar
            Container(
              width: double.infinity,
              color: SruColors.surfaceBlue.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.isAdmin) ...[
                    SizedBox(
                      width: 190,
                      child: DropdownButtonFormField<String>(
                        value: _selectedBatchId,
                        decoration: const InputDecoration(
                          labelText: 'Target Batch',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'ALL', child: Text('All 4 Batches')),
                          ...batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                        ],
                        onChanged: (v) => setState(() {
                          _selectedBatchId = v ?? 'ALL';
                          _selectedMentorFilter = 'ALL';
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 250,
                      child: DropdownButtonFormField<String>(
                        value: _selectedMentorFilter,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Mentor',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'ALL', child: Text('All Mentors')),
                          ...mentors
                              .where((m) => _selectedBatchId == 'ALL' || m.batchId == _selectedBatchId)
                              .map((m) => DropdownMenuItem(
                                    value: m.uid,
                                    child: Text('${m.name} (${m.mentorCode})', overflow: TextOverflow.ellipsis),
                                  )),
                        ],
                        onChanged: (v) => setState(() => _selectedMentorFilter = v ?? 'ALL'),
                      ),
                    ),
                  ],
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: Text('Deadline: ${DateFormat('dd MMM yyyy').format(_deadline)}'),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _deadline,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 180)),
                      );
                      if (d != null) setState(() => _deadline = d);
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SruColors.primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Target: ${targetStudents.length} Mentees',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: SruColors.primary, fontSize: 13),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _loadPresetPack,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: const Text('Load 5-Problem Pack'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _pasteMode = !_pasteMode),
                    icon: Icon(_pasteMode ? Icons.table_rows_rounded : Icons.paste_rounded, size: 16),
                    label: Text(_pasteMode ? 'Back to Table' : 'Paste CSV Lines'),
                  ),
                ],
              ),
            ),

            // Body: either CSV paste or multi-row editor
            Expanded(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: _pasteMode
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Paste one problem per line: Title, URL, Platform (LEETCODE/CODEFORCES/HACKERRANK), Difficulty (EASY/MEDIUM/HARD), Topic',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: TextField(
                              controller: _csvController,
                              maxLines: null,
                              expands: true,
                              decoration: const InputDecoration(
                                hintText:
                                    'Two Sum, https://leetcode.com/problems/two-sum/, LEETCODE, EASY, Hash Table\nHouse Robber, https://leetcode.com/problems/house-robber/, LEETCODE, MEDIUM, DP',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _parseCsvText,
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Parse Lines into Problem List'),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.separated(
                              itemCount: _rows.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final r = _rows[i];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: SruColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: SruColors.primary,
                                        child: Text(
                                          '${i + 1}',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 3,
                                        child: TextField(
                                          controller: r.title,
                                          decoration: const InputDecoration(
                                            labelText: 'Problem Title',
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 4,
                                        child: TextField(
                                          controller: r.url,
                                          decoration: const InputDecoration(
                                            labelText: 'Problem URL',
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 130,
                                        child: DropdownButtonFormField<String>(
                                          value: r.platform,
                                          decoration: const InputDecoration(labelText: 'Platform', isDense: true),
                                          items: const [
                                            DropdownMenuItem(value: 'LEETCODE', child: Text('LeetCode')),
                                            DropdownMenuItem(value: 'CODEFORCES', child: Text('Codeforces')),
                                            DropdownMenuItem(value: 'HACKERRANK', child: Text('HackerRank')),
                                            DropdownMenuItem(value: 'GFG', child: Text('GeeksforGeeks')),
                                          ],
                                          onChanged: (v) => setState(() => r.platform = v ?? 'LEETCODE'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 115,
                                        child: DropdownButtonFormField<String>(
                                          value: r.difficulty,
                                          decoration: const InputDecoration(labelText: 'Difficulty', isDense: true),
                                          items: const [
                                            DropdownMenuItem(value: 'EASY', child: Text('Easy')),
                                            DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                                            DropdownMenuItem(value: 'HARD', child: Text('Hard')),
                                          ],
                                          onChanged: (v) => setState(() => r.difficulty = v ?? 'MEDIUM'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: TextField(
                                          controller: r.topic,
                                          decoration: const InputDecoration(
                                            labelText: 'Topic',
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        tooltip: 'Remove Row',
                                        onPressed: _rows.length <= 1
                                            ? null
                                            : () => setState(() {
                                                  final removed = _rows.removeAt(i);
                                                  removed.dispose();
                                                }),
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _addRow,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add Another Problem Row'),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                border: Border(top: BorderSide(color: SruColors.border)),
              ),
              child: Row(
                children: [
                  if (_statusText != null)
                    Expanded(
                      child: Text(
                        _statusText!,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: SruColors.primary),
                      ),
                    )
                  else
                    Expanded(
                      child: Text(
                        'Ready to assign ${_rows.length} problem(s) to ${targetStudents.length} student(s).',
                        style: const TextStyle(color: SruColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  TextButton(
                    onPressed: _submitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _submitting ? null : () => _assignBulk(targetStudents),
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text('Assign All (${_rows.length} Problems)'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
