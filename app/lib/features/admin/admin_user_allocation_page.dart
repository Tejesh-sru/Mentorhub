import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/providers.dart';
import '../../models/models.dart';

class AdminUserAllocationPage extends ConsumerStatefulWidget {
  const AdminUserAllocationPage({super.key});

  @override
  ConsumerState<AdminUserAllocationPage> createState() => _AdminUserAllocationPageState();
}

class _AdminUserAllocationPageState extends ConsumerState<AdminUserAllocationPage> {
  String? _selectedBatchId;
  String _search = '';
  String? _filterMentorId;

  Future<void> _reassignMentor(BuildContext context, StudentProfile student, List<MentorProfile> mentors) async {
    String? selectedMentorId = student.mentorId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Assign Senior Mentor: ${student.name}'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Roll Number: ${student.studentCode}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedMentorId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Select Senior Mentor',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('Unassigned / None')),
                ...mentors.map((m) => DropdownMenuItem<String>(
                      value: m.uid,
                      child: Text('${m.name} (${m.mentorCode})'),
                    )),
              ],
              onChanged: (val) => setDialogState(() => selectedMentorId = val),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  try {
                    await ref.read(apiProvider).updateStudentMentor(student.uid, selectedMentorId);
                  } catch (_) {
                    // Direct Firestore fallback
                    await ref.read(firestoreProvider).collection('students').doc(student.uid).update({
                      'mentorId': selectedMentorId,
                    });
                  }
                  ref.invalidate(adminStudentsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mentor assignment updated!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                }
              },
              child: const Text('Save Assignment'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(adminBatchesStreamProvider);
    final mentorsAsync = ref.watch(adminMentorsProvider);
    final studentsAsync = ref.watch(adminStudentsProvider);

    return PageBody(
      title: 'User Allocation & Mentoring Pairs',
      subtitle: 'Allocate and manage Senior Mentor assignments for juniors within assigned batches',
      child: batchesAsync.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        error: (e, _) => ErrorView(e),
        data: (batches) {
          if (batches.isEmpty) return const AppCard(child: EmptyState(title: 'No batches found'));

          _selectedBatchId ??= batches.first.id;
          final batchId = _selectedBatchId!;

          return mentorsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ErrorView(e),
            data: (mentors) {
              final batchMentors = mentors.where((m) => m.batchId == batchId).toList();
              final mentorMap = {for (var m in mentors) m.uid: m};

              return studentsAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                error: (e, _) => ErrorView(e),
                data: (students) {
                  final batchStudents = students.where((s) => s.batchId == batchId).toList();

                  final filtered = batchStudents.where((s) {
                    if (_filterMentorId != null && s.mentorId != _filterMentorId) return false;
                    if (_search.isNotEmpty) {
                      final q = _search.toLowerCase();
                      return s.name.toLowerCase().contains(q) || s.studentCode.toLowerCase().contains(q);
                    }
                    return true;
                  }).toList();

                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // ── Controls Card ──
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text('Batch: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          DropdownButton<String>(
                            value: batchId,
                            items: batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _selectedBatchId = v;
                                  _filterMentorId = null;
                                });
                              }
                            },
                          ),
                        ]),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text('Filter by Senior: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          DropdownButton<String?>(
                            value: _filterMentorId,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Mentors')),
                              ...batchMentors.map((m) => DropdownMenuItem(value: m.uid, child: Text(m.name))),
                            ],
                            onChanged: (v) => setState(() => _filterMentorId = v),
                          ),
                        ]),
                        SizedBox(
                          width: 260,
                          height: 38,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search junior by name / roll...',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (v) => setState(() => _search = v),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // ── Allocation Metrics Summary ──
                    Row(children: [
                      Text('${filtered.length} Juniors allocated in batch',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const Spacer(),
                      Text('${batchMentors.length} Senior Mentors',
                          style: const TextStyle(fontSize: 13, color: Colors.black54)),
                    ]),
                    const SizedBox(height: 10),

                    // ── Juniors Table ──
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final s = filtered[i];
                          final assignedMentor = s.mentorId != null ? mentorMap[s.mentorId] : null;

                          return ListTile(
                            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Text('Roll: ${s.studentCode} • Email: ${s.email}'),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: assignedMentor != null ? Colors.blue.shade50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  assignedMentor != null ? 'Senior: ${assignedMentor.name}' : 'Unassigned',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: assignedMentor != null ? Colors.blue.shade800 : Colors.red.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => _reassignMentor(context, s, batchMentors),
                                child: const Text('Reassign', style: TextStyle(fontSize: 12)),
                              ),
                            ]),
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
      ),
    );
  }
}
