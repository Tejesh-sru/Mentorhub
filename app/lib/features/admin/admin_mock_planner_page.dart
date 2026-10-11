import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/providers.dart';
import '../../models/cssp_models.dart';
import '../../models/models.dart';
import '../mentor/student_detail_page.dart';

class AdminMockPlannerPage extends ConsumerStatefulWidget {
  const AdminMockPlannerPage({super.key});

  @override
  ConsumerState<AdminMockPlannerPage> createState() => _AdminMockPlannerPageState();
}

class _AdminMockPlannerPageState extends ConsumerState<AdminMockPlannerPage> {
  String? _selectedBatchId;
  String _selectedWeekId = 'W1';
  String? _selectedMentorUid; // null = all mentors
  String _filterStatus = 'ALL';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(adminBatchesStreamProvider);
    final mentorsAsync = ref.watch(adminMentorsProvider);
    final studentsAsync = ref.watch(adminStudentsProvider);

    return PageBody(
      title: 'Admin Mock Interview Planner',
      subtitle: 'Schedule, monitor, and coordinate weekly mock interviews across all mentors and mentees',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.invalidate(adminBatchesStreamProvider);
            ref.invalidate(adminMentorsProvider);
            ref.invalidate(adminStudentsProvider);
            if (_selectedBatchId != null) {
              ref.invalidate(csspBatchMocksProvider(_selectedBatchId!));
            }
          },
        ),
      ],
      child: batchesAsync.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        error: (e, _) => ErrorView(e),
        data: (batches) {
          if (batches.isEmpty) {
            return const AppCard(child: EmptyState(title: 'No batches available', message: 'Create a batch first.'));
          }

          final effectiveBatchId = _selectedBatchId ?? batches.first.id;
          final weeksAsync = ref.watch(csspWeeksProvider(effectiveBatchId));
          final batchMocksAsync = ref.watch(csspBatchMocksProvider(effectiveBatchId));

          return weeksAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ErrorView(e),
            data: (weeks) {
              final activeWeek = weeks.firstWhere((w) => w.weekId == _selectedWeekId, orElse: () => weeks.first);

              return mentorsAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                error: (e, _) => ErrorView(e),
                data: (allMentors) {
                  final batchMentors = allMentors.where((m) => m.batchId == effectiveBatchId).toList();
                  final mentorMap = {for (var m in allMentors) m.uid: m};

                  return studentsAsync.when(
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                    error: (e, _) => ErrorView(e),
                    data: (allStudents) {
                      final batchStudents = allStudents.where((s) => s.batchId == effectiveBatchId).toList();

                      return batchMocksAsync.when(
                        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
                        error: (e, _) => ErrorView(e),
                        data: (allMocks) {
                          final weekMocks = {
                            for (var m in allMocks.where((m) => m.weekId == _selectedWeekId)) m.juniorUid: m
                          };

                          // Filter students by selected mentor, search query, status
                          final visibleStudents = batchStudents.where((s) {
                            if (_selectedMentorUid != null && _selectedMentorUid!.isNotEmpty) {
                              if (s.mentorId != _selectedMentorUid) return false;
                            }
                            if (_searchQuery.isNotEmpty) {
                              final q = _searchQuery.toLowerCase();
                              final matchName = s.name.toLowerCase().contains(q);
                              final matchCode = s.studentCode.toLowerCase().contains(q);
                              if (!matchName && !matchCode) return false;
                            }
                            final mock = weekMocks[s.uid];
                            final st = mock?.status ?? 'NOT_PLANNED';
                            if (_filterStatus == 'SCHEDULED') return st == 'SCHEDULED';
                            if (_filterStatus == 'COMPLETED') return st == 'COMPLETED';
                            if (_filterStatus == 'MISSED') return st == 'MISSED';
                            if (_filterStatus == 'NOT_PLANNED') return st == 'NOT_PLANNED';
                            return true;
                          }).toList();

                          final scheduledCount = batchStudents.where((s) => weekMocks[s.uid]?.status == 'SCHEDULED').length;
                          final completedCount = batchStudents.where((s) => weekMocks[s.uid]?.status == 'COMPLETED').length;
                          final missedCount = batchStudents.where((s) => weekMocks[s.uid]?.status == 'MISSED').length;
                          final notPlannedCount = batchStudents.length - scheduledCount - completedCount - missedCount;

                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // ── Batch & Mentor Filter Bar ──
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 12,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  alignment: WrapAlignment.spaceBetween,
                                  children: [
                                    Row(mainAxisSize: MainAxisSize.min, children: [
                                      const Icon(Icons.collections_bookmark_outlined, size: 20, color: Color(0xFF4F46E5)),
                                      const SizedBox(width: 8),
                                      const Text('Batch: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                      DropdownButton<String>(
                                        value: effectiveBatchId,
                                        underline: const SizedBox(),
                                        items: batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => _selectedBatchId = val);
                                        },
                                      ),
                                    ]),
                                    Row(mainAxisSize: MainAxisSize.min, children: [
                                      const Icon(Icons.engineering_outlined, size: 20, color: Color(0xFF0284C7)),
                                      const SizedBox(width: 8),
                                      const Text('Mentor: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                      DropdownButton<String?>(
                                        value: _selectedMentorUid,
                                        underline: const SizedBox(),
                                        items: [
                                          const DropdownMenuItem(value: null, child: Text('All Mentors')),
                                          ...batchMentors.map((m) => DropdownMenuItem(
                                                value: m.uid,
                                                child: Text('${m.name} (${m.mentorCode})'),
                                              )),
                                        ],
                                        onChanged: (val) => setState(() => _selectedMentorUid = val),
                                      ),
                                    ]),
                                    SizedBox(
                                      width: 240,
                                      child: TextField(
                                        decoration: InputDecoration(
                                          hintText: 'Search mentee name / roll...',
                                          prefixIcon: const Icon(Icons.search, size: 18),
                                          isDense: true,
                                          filled: true,
                                          fillColor: Colors.grey.shade100,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        ),
                                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── Admin Action Banner ──
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const Text(
                                      'Mock Interview Coordination & Planning',
                                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Plan custom mocks, assign evaluators, set meeting links, or auto-schedule all pending students for ${activeWeek.label}.',
                                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                                    ),
                                  ]),
                                ),
                                const SizedBox(width: 12),
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                                    icon: const Icon(Icons.add_circle_outline, size: 18),
                                    label: const Text('Plan Custom Mock'),
                                    onPressed: () => _openCustomMockDialog(
                                      context: context,
                                      batchId: effectiveBatchId,
                                      weeks: weeks,
                                      activeWeek: activeWeek,
                                      allStudents: batchStudents,
                                      allMentors: batchMentors,
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    style: FilledButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
                                    icon: const Icon(Icons.auto_awesome, size: 18),
                                    label: const Text('Batch Auto-Plan'),
                                    onPressed: () => _proposeBatchAutoSchedule(
                                      context: context,
                                      batchId: effectiveBatchId,
                                      students: batchStudents,
                                      weekMocks: weekMocks,
                                      week: activeWeek,
                                    ),
                                  ),
                                ]),
                              ]),
                            ),
                            const SizedBox(height: 16),

                            // ── Metric Stat Cards ──
                            StatGrid(children: [
                              StatCard(icon: Icons.groups_outlined, label: 'Batch Students', value: '${batchStudents.length}'),
                              StatCard(icon: Icons.event_available_rounded, label: 'Scheduled', value: '$scheduledCount', color: const Color(0xFF0284C7)),
                              StatCard(icon: Icons.check_circle_outline, label: 'Completed', value: '$completedCount', color: const Color(0xFF10B981)),
                              StatCard(icon: Icons.cancel_outlined, label: 'Missed', value: '$missedCount', color: const Color(0xFFEF4444)),
                              StatCard(icon: Icons.hourglass_empty_rounded, label: 'Not Planned', value: '$notPlannedCount', color: Colors.grey.shade700),
                            ]),
                            const SizedBox(height: 20),

                            // ── Week Selector ──
                            const Text('Select Week:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: weeks.map((w) {
                                  final selected = w.weekId == _selectedWeekId;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(w.label),
                                      selected: selected,
                                      onSelected: (val) {
                                        if (val) setState(() => _selectedWeekId = w.weekId);
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ── Status Filter Chips ──
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(children: [
                                FilterChip(
                                  label: Text('All (${batchStudents.length})'),
                                  selected: _filterStatus == 'ALL',
                                  onSelected: (_) => setState(() => _filterStatus = 'ALL'),
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: Text('Scheduled ($scheduledCount)'),
                                  selected: _filterStatus == 'SCHEDULED',
                                  onSelected: (_) => setState(() => _filterStatus = 'SCHEDULED'),
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: Text('Completed ($completedCount)'),
                                  selected: _filterStatus == 'COMPLETED',
                                  onSelected: (_) => setState(() => _filterStatus = 'COMPLETED'),
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: Text('Missed ($missedCount)'),
                                  selected: _filterStatus == 'MISSED',
                                  onSelected: (_) => setState(() => _filterStatus = 'MISSED'),
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: Text('Not Planned ($notPlannedCount)'),
                                  selected: _filterStatus == 'NOT_PLANNED',
                                  onSelected: (_) => setState(() => _filterStatus = 'NOT_PLANNED'),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 16),

                            // ── Mentees List ──
                            if (visibleStudents.isEmpty)
                              const AppCard(child: EmptyState(title: 'No students found matching current filters'))
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: visibleStudents.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  final student = visibleStudents[i];
                                  final mock = weekMocks[student.uid];
                                  final mentor = mentorMap[student.mentorId];
                                  final status = mock?.status ?? 'NOT_PLANNED';

                                  final Color statusColor = switch (status) {
                                    'COMPLETED' => const Color(0xFF10B981),
                                    'SCHEDULED' => const Color(0xFF0284C7),
                                    'MISSED' => const Color(0xFFEF4444),
                                    _ => Colors.grey,
                                  };

                                  return Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: status == 'COMPLETED'
                                            ? Colors.green.shade200
                                            : (status == 'SCHEDULED' ? Colors.blue.shade200 : Colors.grey.shade200),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Row(children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: const Color(0xFF4F46E5),
                                            foregroundColor: Colors.white,
                                            child: Text(student.name.isEmpty ? '?' : student.name[0].toUpperCase()),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              Row(children: [
                                                Text(student.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(student.studentCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                                ),
                                              ]),
                                              const SizedBox(height: 4),
                                              Text(
                                                mentor != null ? 'Mentor: ${mentor.name} (${mentor.mentorCode})' : 'Mentor: Unassigned',
                                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                                              ),
                                            ]),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                                          ),
                                        ]),
                                        const SizedBox(height: 12),

                                        // Mock details strip
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.grey.shade200),
                                          ),
                                          child: Wrap(
                                            spacing: 16,
                                            runSpacing: 8,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Row(mainAxisSize: MainAxisSize.min, children: [
                                                const Icon(Icons.event, size: 15, color: Colors.black54),
                                                const SizedBox(width: 6),
                                                Text(
                                                  mock?.scheduledAt != null ? Format.date(mock!.scheduledAt!) : 'No date set',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                                ),
                                              ]),
                                              if (mock?.topic != null && mock!.topic!.isNotEmpty)
                                                Row(mainAxisSize: MainAxisSize.min, children: [
                                                  const Icon(Icons.track_changes_rounded, size: 15, color: Color(0xFF4F46E5)),
                                                  const SizedBox(width: 6),
                                                  Text('Topic: ${mock.topic}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5))),
                                                ]),
                                              if (mock?.durationMinutes != null)
                                                Row(mainAxisSize: MainAxisSize.min, children: [
                                                  const Icon(Icons.timer_outlined, size: 15, color: Colors.black54),
                                                  const SizedBox(width: 6),
                                                  Text('${mock!.durationMinutes} mins', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                                ]),
                                              if (mock?.meetingLink != null && mock!.meetingLink!.isNotEmpty)
                                                InkWell(
                                                  onTap: () => _launchUrl(mock!.meetingLink!),
                                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                                    const Icon(Icons.video_call_rounded, size: 16, color: Color(0xFF0284C7)),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Join Meeting',
                                                      style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                                    ),
                                                  ]),
                                                ),
                                              if (status == 'COMPLETED' && mock?.score10 != null)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                                                  child: Text(
                                                    'Score: ${mock!.score10}/10 • Tech: ${mock.technical5 ?? 0}/5 • Comm: ${mock.communication5 ?? 0}/5',
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 10),

                                        // Action buttons
                                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                          FilledButton.tonalIcon(
                                            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                                            icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                                            label: Text(mock != null && mock.status != 'NOT_PLANNED' ? 'Edit Slot' : 'Plan Custom Mock'),
                                            onPressed: () => _openCustomMockDialog(
                                              context: context,
                                              batchId: effectiveBatchId,
                                              weeks: weeks,
                                              activeWeek: activeWeek,
                                              allStudents: batchStudents,
                                              allMentors: batchMentors,
                                              preselectedStudent: student,
                                              existingMock: mock,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                            icon: const Icon(Icons.rate_review_outlined, size: 16),
                                            label: const Text('Evaluate / Score'),
                                            onPressed: () => _openEvaluateDialog(
                                              context: context,
                                              batchId: effectiveBatchId,
                                              week: activeWeek,
                                              student: student,
                                              existingMock: mock,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            tooltip: 'Full Student Profile',
                                            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(builder: (_) => StudentDetailPage(student: student)),
                                              );
                                            },
                                          ),
                                        ]),
                                      ]),
                                    ),
                                  );
                                },
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openCustomMockDialog({
    required BuildContext context,
    required String batchId,
    required List<WeekConfig> weeks,
    required WeekConfig activeWeek,
    required List<StudentProfile> allStudents,
    required List<MentorProfile> allMentors,
    StudentProfile? preselectedStudent,
    MockInterview? existingMock,
  }) {
    StudentProfile? currentStudent = preselectedStudent ?? (allStudents.isNotEmpty ? allStudents.first : null);
    String selectedWeekId = existingMock?.weekId ?? activeWeek.weekId;
    String? selectedMentorUid = existingMock?.seniorUid ?? (currentStudent?.mentorId ?? (allMentors.isNotEmpty ? allMentors.first.uid : null));
    DateTime scheduledDate = existingMock?.scheduledAt ?? DateTime.now().add(const Duration(days: 1));
    int durationMinutes = existingMock?.durationMinutes ?? 30;
    String status = existingMock?.status ?? 'SCHEDULED';

    final topicCtrl = TextEditingController(text: existingMock?.topic ?? 'DSA & Problem Solving Mock');
    final linkCtrl = TextEditingController(text: existingMock?.meetingLink ?? '');
    final notesCtrl = TextEditingController(text: existingMock?.notes ?? '');

    final presetTopics = [
      'DSA - Arrays & Strings',
      'DSA - Trees & Graphs',
      'Dynamic Programming & Recursion',
      'System Design Basics',
      'Mock HR & Behavioral',
      'Full Comprehensive Coding Mock',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.event_available_rounded, color: Color(0xFF4F46E5)),
              const SizedBox(width: 10),
              Text(existingMock != null ? 'Edit Mock Interview Slot' : 'Schedule Custom Mock Interview'),
            ]),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Student selector
                  if (preselectedStudent != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        const Icon(Icons.person, color: Color(0xFF4F46E5)),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(currentStudent!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Roll: ${currentStudent!.studentCode}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ]),
                      ]),
                    ),
                  ] else ...[
                    const Text('Select Mentee:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: currentStudent?.uid,
                      decoration: InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: allStudents.map((s) => DropdownMenuItem(value: s.uid, child: Text('${s.name} (${s.studentCode})'))).toList(),
                      onChanged: (val) {
                        setDlgState(() {
                          currentStudent = allStudents.firstWhere((s) => s.uid == val);
                          selectedMentorUid = currentStudent?.mentorId ?? selectedMentorUid;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Week & Evaluator Mentor Row
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Week:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: selectedWeekId,
                          decoration: InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: weeks.map((w) => DropdownMenuItem(value: w.weekId, child: Text(w.label))).toList(),
                          onChanged: (val) {
                            if (val != null) setDlgState(() => selectedWeekId = val);
                          },
                        ),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Assigned Mentor:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: selectedMentorUid,
                          decoration: InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: allMentors.map((m) => DropdownMenuItem(value: m.uid, child: Text(m.name))).toList(),
                          onChanged: (val) => setDlgState(() => selectedMentorUid = val),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),

                  // Topic field with quick suggestions
                  const Text('Mock Topic / Focus Area:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: topicCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. DSA - Trees & Graphs',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: presetTopics.map((pt) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(pt, style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setDlgState(() => topicCtrl.text = pt),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Date & Time Picker
                  const Text('Scheduled Date & Time:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_month, size: 20, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          Format.date(scheduledDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Change'),
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: scheduledDate,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (pickedDate != null && context.mounted) {
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(scheduledDate),
                            );
                            if (pickedTime != null) {
                              setDlgState(() {
                                scheduledDate = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            }
                          }
                        },
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),

                  // Duration selector
                  const Text('Duration:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(children: [15, 30, 45, 60].map((d) {
                    final isSel = durationMinutes == d;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$d mins'),
                        selected: isSel,
                        onSelected: (val) {
                          if (val) setDlgState(() => durationMinutes = d);
                        },
                      ),
                    );
                  }).toList()),
                  const SizedBox(height: 14),

                  // Meeting link
                  const Text('Meeting Link / Location:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: linkCtrl,
                    decoration: InputDecoration(
                      hintText: 'https://meet.google.com/xyz or Offline Lab Room',
                      prefixIcon: const Icon(Icons.link, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Mentor notes
                  const Text('Preparation Notes / Instructions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Topics student should prepare beforehand...',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Status dropdown
                  const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'SCHEDULED', child: Text('SCHEDULED')),
                      DropdownMenuItem(value: 'COMPLETED', child: Text('COMPLETED')),
                      DropdownMenuItem(value: 'MISSED', child: Text('MISSED')),
                      DropdownMenuItem(value: 'NOT_PLANNED', child: Text('NOT_PLANNED')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => status = val);
                    },
                  ),
                ]),
              ),
            ),
            actions: [
              if (existingMock != null)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final docId = '${batchId}_${selectedWeekId}_${currentStudent!.uid}';
                    await ref.read(firestoreProvider).collection('mocks').doc(docId).delete();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mock schedule deleted.')));
                    }
                  },
                  child: const Text('Delete Slot'),
                ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (currentStudent == null) return;
                  Navigator.pop(ctx);

                  final payload = {
                    'batchId': batchId,
                    'weekId': selectedWeekId,
                    'juniorUid': currentStudent!.uid,
                    'seniorUid': selectedMentorUid,
                    'scheduledAt': scheduledDate.toIso8601String(),
                    'topic': topicCtrl.text.trim(),
                    'meetingLink': linkCtrl.text.trim(),
                    'durationMinutes': durationMinutes,
                    'notes': notesCtrl.text.trim(),
                    'status': status,
                  };

                  try {
                    await ref.read(apiProvider).scheduleMock(payload);
                  } catch (_) {
                    final docId = '${batchId}_${selectedWeekId}_${currentStudent!.uid}';
                    await ref.read(firestoreProvider).collection('mocks').doc(docId).set({
                      'batchId': batchId,
                      'weekId': selectedWeekId,
                      'juniorUid': currentStudent!.uid,
                      'seniorUid': selectedMentorUid,
                      'scheduledAt': scheduledDate,
                      'topic': topicCtrl.text.trim(),
                      'meetingLink': linkCtrl.text.trim(),
                      'durationMinutes': durationMinutes,
                      'notes': notesCtrl.text.trim(),
                      'status': status,
                      'updatedAt': DateTime.now(),
                    }, SetOptions(merge: true));
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Mock scheduled for ${currentStudent!.name} ($selectedWeekId)!'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                },
                child: const Text('Save & Schedule'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openEvaluateDialog({
    required BuildContext context,
    required String batchId,
    required WeekConfig week,
    required StudentProfile student,
    MockInterview? existingMock,
  }) {
    final score10Ctrl = TextEditingController(text: existingMock?.score10 != null ? '${existingMock!.score10}' : '');
    final technical5Ctrl = TextEditingController(text: existingMock?.technical5 != null ? '${existingMock!.technical5}' : '');
    final communication5Ctrl = TextEditingController(text: existingMock?.communication5 != null ? '${existingMock!.communication5}' : '');
    final problemSolving5Ctrl = TextEditingController(text: existingMock?.problemSolving5 != null ? '${existingMock!.problemSolving5}' : '');
    final recommendationCtrl = TextEditingController(text: existingMock?.recommendation ?? '');
    final notesCtrl = TextEditingController(text: existingMock?.notes ?? '');
    String status = existingMock?.status == 'COMPLETED' ? 'COMPLETED' : 'COMPLETED';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.rate_review_outlined, color: Color(0xFF10B981)),
              const SizedBox(width: 10),
              Text('Evaluate Mock: ${student.name} (${week.label})'),
            ]),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: score10Ctrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Overall Score (0-10)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: technical5Ctrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Technical (0-5)', border: OutlineInputBorder()),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: communication5Ctrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Communication (0-5)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: problemSolving5Ctrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Problem Solving (0-5)', border: OutlineInputBorder()),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: recommendationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Mentor Recommendation / Focus',
                      hintText: 'e.g. Work on edge cases and time complexity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Evaluation Notes / Rubric Breakdown',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final score10 = double.tryParse(score10Ctrl.text.trim()) ?? 0;
                  final tech = double.tryParse(technical5Ctrl.text.trim()) ?? 0;
                  final comm = double.tryParse(communication5Ctrl.text.trim()) ?? 0;
                  final ps = double.tryParse(problemSolving5Ctrl.text.trim()) ?? 0;

                  final payload = {
                    'batchId': batchId,
                    'weekId': week.weekId,
                    'juniorUid': student.uid,
                    'score10': score10,
                    'technical5': tech,
                    'communication5': comm,
                    'problemSolving5': ps,
                    'recommendation': recommendationCtrl.text.trim(),
                    'notes': notesCtrl.text.trim(),
                    'status': status,
                  };

                  try {
                    await ref.read(apiProvider).evaluateMock(payload);
                  } catch (_) {
                    final docId = '${batchId}_${week.weekId}_${student.uid}';
                    await ref.read(firestoreProvider).collection('mocks').doc(docId).set({
                      'batchId': batchId,
                      'weekId': week.weekId,
                      'juniorUid': student.uid,
                      'score10': score10,
                      'technical5': tech,
                      'communication5': comm,
                      'problemSolving5': ps,
                      'recommendation': recommendationCtrl.text.trim(),
                      'notes': notesCtrl.text.trim(),
                      'status': 'COMPLETED',
                      'updatedAt': DateTime.now(),
                    }, SetOptions(merge: true));
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Mock evaluated for ${student.name}!'), backgroundColor: const Color(0xFF10B981)),
                    );
                  }
                },
                child: const Text('Save Evaluation'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _proposeBatchAutoSchedule({
    required BuildContext context,
    required String batchId,
    required List<StudentProfile> students,
    required Map<String, MockInterview> weekMocks,
    required WeekConfig week,
  }) {
    final unassigned = students.where((s) => weekMocks[s.uid]?.status != 'COMPLETED' && weekMocks[s.uid]?.status != 'SCHEDULED').toList();

    if (unassigned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All batch students already scheduled or completed!')));
      return;
    }

    final baseTuesday = week.startsAt.add(const Duration(days: 1));
    final slots = <DateTime>[];
    for (int dayOffset = 0; dayOffset < 3; dayOffset++) {
      final day = baseTuesday.add(Duration(days: dayOffset));
      for (int hour = 16; hour < 18; hour++) {
        slots.add(DateTime(day.year, day.month, day.day, hour, 0));
        slots.add(DateTime(day.year, day.month, day.day, hour, 30));
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Batch Auto-Schedule Slots (${week.label})'),
        content: SizedBox(
          width: 480,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Proposing ${unassigned.length} half-hour slots across Tue–Thu (16:00 to 18:00) for all unassigned students in Batch:'),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ListView.builder(
                itemCount: unassigned.length,
                itemBuilder: (c, idx) {
                  final slotTime = idx < slots.length ? slots[idx] : slots.last.add(Duration(minutes: (idx - slots.length + 1) * 30));
                  return ListTile(
                    dense: true,
                    title: Text(unassigned[idx].name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(unassigned[idx].studentCode),
                    trailing: Text(
                      '${slotTime.day}/${slotTime.month} ${slotTime.hour}:${slotTime.minute == 0 ? "00" : slotTime.minute}',
                      style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              for (int idx = 0; idx < unassigned.length; idx++) {
                final student = unassigned[idx];
                final slotTime = idx < slots.length ? slots[idx] : slots.last.add(Duration(minutes: (idx - slots.length + 1) * 30));
                try {
                  await ref.read(apiProvider).scheduleMock({
                    'batchId': batchId,
                    'weekId': week.weekId,
                    'juniorUid': student.uid,
                    'seniorUid': student.mentorId,
                    'scheduledAt': slotTime.toIso8601String(),
                    'topic': 'DSA Weekly Mock Assessment',
                    'durationMinutes': 30,
                  });
                } catch (_) {
                  final docId = '${batchId}_${week.weekId}_${student.uid}';
                  await ref.read(firestoreProvider).collection('mocks').doc(docId).set({
                    'batchId': batchId,
                    'weekId': week.weekId,
                    'juniorUid': student.uid,
                    'seniorUid': student.mentorId,
                    'status': 'SCHEDULED',
                    'scheduledAt': slotTime,
                    'topic': 'DSA Weekly Mock Assessment',
                    'durationMinutes': 30,
                    'updatedAt': DateTime.now(),
                  }, SetOptions(merge: true));
                }
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Batch auto-scheduled ${unassigned.length} mocks for ${week.label}!'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text('Confirm & Save All Slots'),
          ),
        ],
      ),
    );
  }
}
