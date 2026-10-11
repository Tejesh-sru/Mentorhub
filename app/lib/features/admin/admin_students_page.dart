import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sru_branding.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/providers.dart';
import '../../models/models.dart';
import '../shared/bulk_assign_dialog.dart';
import '../shared/mentee_profile_dialog.dart';

class AdminStudentsPage extends ConsumerStatefulWidget {
  const AdminStudentsPage({super.key});

  @override
  ConsumerState<AdminStudentsPage> createState() => _AdminStudentsPageState();
}

class _AdminStudentsPageState extends ConsumerState<AdminStudentsPage> {
  final _searchController = TextEditingController();
  String _query = '';
  String _selectedBatchId = 'ALL';
  String _selectedMentorId = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(adminStudentsProvider);
    final mentorsAsync = ref.watch(adminMentorsProvider);
    final batchesAsync = ref.watch(adminBatchesStreamProvider);

    final mentors = mentorsAsync.valueOrNull ?? [];
    final batches = batchesAsync.valueOrNull ?? [];
    final mentorById = {for (final m in mentors) m.uid: m};
    final batchById = {for (final b in batches) b.id: b.name};

    return PageBody(
      title: 'Students (${studentsAsync.valueOrNull?.length ?? 0})',
      subtitle: 'Search students across all 4 batches, inspect mentee profiles & progress analysis, or bulk assign problems',
      actions: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
          icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
          label: const Text('Bulk Assign Problems'),
          onPressed: () => showBulkProblemAssignDialog(context, isAdmin: true),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('Add Student'),
          onPressed: (batches.isNotEmpty)
              ? () => showDialog(
                    context: context,
                    builder: (_) => _StudentDialog(batches: batches, mentors: mentors),
                  )
              : null,
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(adminStudentsProvider),
          icon: const Icon(Icons.refresh, color: SruColors.primary),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search & Batch/Mentor Filter Card ──
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded),
                          hintText: 'Search by Student Name, Roll No (e.g. 2403A51015), Branch, or Mentor...',
                          isDense: true,
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedMentorId,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Mentor',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'ALL', child: Text('All Mentors (42)')),
                          ...mentors
                              .where((m) => _selectedBatchId == 'ALL' || m.batchId == _selectedBatchId)
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m.uid,
                                  child: Text('${m.name} (${m.mentorCode})', overflow: TextOverflow.ellipsis),
                                ),
                              ),
                        ],
                        onChanged: (v) => setState(() => _selectedMentorId = v ?? 'ALL'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Batch Filter Pills (All + 4 Batches G6-B1..G6-B4)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('All Batches (${studentsAsync.valueOrNull?.length ?? 0})'),
                      selected: _selectedBatchId == 'ALL',
                      onSelected: (_) => setState(() {
                        _selectedBatchId = 'ALL';
                        _selectedMentorId = 'ALL';
                      }),
                    ),
                    ...batches.map((b) {
                      final count = (studentsAsync.valueOrNull ?? []).where((s) => s.batchId == b.id).length;
                      return ChoiceChip(
                        label: Text('${b.name} ($count)'),
                        selected: _selectedBatchId == b.id,
                        onSelected: (_) => setState(() {
                          _selectedBatchId = b.id;
                          _selectedMentorId = 'ALL';
                        }),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Filtered Students List ──
          studentsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(adminStudentsProvider)),
            data: (allStudents) {
              final filtered = allStudents.where((s) {
                if (_selectedBatchId != 'ALL' && s.batchId != _selectedBatchId) return false;
                if (_selectedMentorId != 'ALL' && s.mentorId != _selectedMentorId) return false;
                if (_query.isNotEmpty) {
                  final m = s.mentorId != null ? mentorById[s.mentorId!] : null;
                  final mName = (m?.name ?? s.mentorName ?? '').toLowerCase();
                  final mCode = (m?.mentorCode ?? s.mentorCode ?? '').toLowerCase();
                  final bName = (batchById[s.batchId] ?? s.batchName ?? '').toLowerCase();
                  final match = s.name.toLowerCase().contains(_query) ||
                      s.studentCode.toLowerCase().contains(_query) ||
                      (s.branch ?? '').toLowerCase().contains(_query) ||
                      mName.contains(_query) ||
                      mCode.contains(_query) ||
                      bName.contains(_query);
                  if (!match) return false;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return const AppCard(
                  child: EmptyState(
                    title: 'No matching students found',
                    message: 'Try clearing the search query or changing the batch/mentor filter.',
                  ),
                );
              }

              return AppCard(
                padding: EdgeInsets.zero,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = filtered[i];
                    return _StudentTile(
                      student: s,
                      mentors: mentors,
                      mentor: s.mentorId != null ? mentorById[s.mentorId!] : null,
                      batchName: batchById[s.batchId] ?? s.batchName ?? s.batchId,
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StudentTile extends ConsumerStatefulWidget {
  final StudentProfile student;
  final List<MentorProfile> mentors;
  final MentorProfile? mentor;
  final String batchName;

  const _StudentTile({
    required this.student,
    required this.mentors,
    required this.mentor,
    required this.batchName,
  });

  @override
  ConsumerState<_StudentTile> createState() => _StudentTileState();
}

class _StudentTileState extends ConsumerState<_StudentTile> {
  bool _loading = false;

  Future<void> _resetPassword() async {
    setState(() => _loading = true);
    try {
      await ref.read(apiProvider).resetUserPassword(widget.student.uid);
      if (mounted) showSnack(context, 'Password reset successfully!');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reassignMentor() async {
    final batchMentors = widget.mentors.where((m) => m.batchId == widget.student.batchId).toList();
    String? selectedMentor = widget.student.mentorId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reassign Mentor'),
        content: StatefulBuilder(
          builder: (_, setStateInner) => DropdownButtonFormField<String?>(
            value: selectedMentor,
            decoration: const InputDecoration(labelText: 'Mentor'),
            items: [
              const DropdownMenuItem(value: null, child: Text('No mentor')),
              ...batchMentors.map((m) => DropdownMenuItem(value: m.uid, child: Text('${m.name} (${m.mentorCode})'))),
            ],
            onChanged: (v) {
              setStateInner(() => selectedMentor = v);
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reassign')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      await ref.read(apiProvider).updateStudentMentor(widget.student.uid, selectedMentor);
      if (mounted) showSnack(context, 'Mentor updated!');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final mentorLabel = widget.mentor != null
        ? '${widget.mentor!.name} (${widget.mentor!.mentorCode})'
        : (s.mentorName != null ? '${s.mentorName} (${s.mentorCode ?? ""})' : 'Unassigned');

    return ListTile(
      onTap: () => showMenteeProfileDialog(
        context,
        student: s,
        mentor: widget.mentor,
        batchName: widget.batchName,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: CircleAvatar(
        backgroundColor: SruColors.primary,
        foregroundColor: Colors.white,
        child: Text(
          s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      title: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: SruColors.surfaceBlue,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              s.studentCode,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: SruColors.primary),
            ),
          ),
          if (s.branch != null && s.branch!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                s.branch!,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SruColors.textSecondary),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.batchName,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'Mentor: $mentorLabel  •  Tasks: ${s.progress.completed}/${s.progress.assigned}  •  POTD: ${s.potdCount} 🔥 (${s.milestone})',
          style: const TextStyle(fontSize: 12, color: SruColors.textSecondary, fontWeight: FontWeight.w500),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.analytics_outlined, size: 16),
            label: const Text('Profile & Analysis'),
            onPressed: () => showMenteeProfileDialog(
              context,
              student: s,
              mentor: widget.mentor,
              batchName: widget.batchName,
            ),
          ),
          const SizedBox(width: 4),
          _loading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'profile') {
                      showMenteeProfileDialog(
                        context,
                        student: s,
                        mentor: widget.mentor,
                        batchName: widget.batchName,
                      );
                    }
                    if (v == 'reset') _resetPassword();
                    if (v == 'reassign') _reassignMentor();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'profile',
                      child: Row(children: [Icon(Icons.person_search_rounded, size: 18), SizedBox(width: 8), Text('Mentee Profile & Analysis')]),
                    ),
                    PopupMenuItem(
                      value: 'reassign',
                      child: Row(children: [Icon(Icons.swap_horiz, size: 18), SizedBox(width: 8), Text('Reassign Mentor')]),
                    ),
                    PopupMenuItem(
                      value: 'reset',
                      child: Row(children: [Icon(Icons.lock_reset, size: 18), SizedBox(width: 8), Text('Reset Password')]),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

class _StudentDialog extends ConsumerStatefulWidget {
  final List<Batch> batches;
  final List<MentorProfile> mentors;
  const _StudentDialog({required this.batches, required this.mentors});

  @override
  ConsumerState<_StudentDialog> createState() => _StudentDialogState();
}

class _StudentDialogState extends ConsumerState<_StudentDialog> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  String? _batchId;
  String? _mentorId;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.batches.isNotEmpty) _batchId = widget.batches.first.id;
  }

  List<MentorProfile> get _batchMentors => widget.mentors.where((m) => m.batchId == _batchId).toList();

  Future<void> _submit() async {
    if (_code.text.trim().isEmpty || _name.text.trim().isEmpty || _email.text.trim().isEmpty || _batchId == null) {
      setState(() => _error = 'All required fields must be filled');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).createStudent({
        'studentCode': _code.text.trim(),
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'batchId': _batchId,
        'mentorId': _mentorId,
      });
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'Student created successfully!');
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Student'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            Row(children: [
              Expanded(child: TextField(controller: _code, decoration: const InputDecoration(labelText: 'Student ID (e.g. 2403A51015)'))),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _batchId,
                  decoration: const InputDecoration(labelText: 'Batch'),
                  items: widget.batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (v) => setState(() {
                    _batchId = v;
                    _mentorId = null;
                  }),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full Name')),
            const SizedBox(height: 12),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _mentorId,
              decoration: const InputDecoration(labelText: 'Assign Mentor'),
              items: [
                const DropdownMenuItem(value: null, child: Text('No mentor')),
                ..._batchMentors.map((m) => DropdownMenuItem(value: m.uid, child: Text('${m.name} (${m.mentorCode})'))),
              ],
              onChanged: (v) => setState(() => _mentorId = v),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Create'),
        ),
      ],
    );
  }
}
