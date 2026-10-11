import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sru_branding.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/providers.dart';
import '../../models/models.dart';
import '../shared/mentee_profile_dialog.dart';

class AdminMentorsPage extends ConsumerStatefulWidget {
  const AdminMentorsPage({super.key});

  @override
  ConsumerState<AdminMentorsPage> createState() => _AdminMentorsPageState();
}

class _AdminMentorsPageState extends ConsumerState<AdminMentorsPage> {
  final _searchController = TextEditingController();
  String _query = '';
  String _selectedBatchId = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mentorsAsync = ref.watch(adminMentorsProvider);
    final batchesAsync = ref.watch(adminBatchesStreamProvider);
    final studentsAsync = ref.watch(adminStudentsProvider);

    final batches = batchesAsync.valueOrNull ?? [];
    final allStudents = studentsAsync.valueOrNull ?? [];
    final batchById = {for (final b in batches) b.id: b.name};

    return PageBody(
      title: 'Mentors (${mentorsAsync.valueOrNull?.length ?? 0})',
      subtitle: 'Search mentors by name or roll number, filter by batch, and inspect their assigned mentees',
      actions: [
        FilledButton.icon(
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('Add Mentor'),
          onPressed: batches.isNotEmpty
              ? () => showDialog(context: context, builder: (_) => _MentorDialog(batches: batches))
              : null,
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(adminMentorsProvider),
          icon: const Icon(Icons.refresh, color: SruColors.primary),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search & Batch Filter Card ──
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Search Mentor by Name, Roll No (e.g. 2303A51408), or Email...',
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
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('All Batches (${mentorsAsync.valueOrNull?.length ?? 0})'),
                      selected: _selectedBatchId == 'ALL',
                      onSelected: (_) => setState(() => _selectedBatchId = 'ALL'),
                    ),
                    ...batches.map((b) {
                      final count = (mentorsAsync.valueOrNull ?? []).where((m) => m.batchId == b.id).length;
                      return ChoiceChip(
                        label: Text('${b.name} ($count)'),
                        selected: _selectedBatchId == b.id,
                        onSelected: (_) => setState(() => _selectedBatchId = b.id),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          mentorsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(adminMentorsProvider)),
            data: (allMentors) {
              final filtered = allMentors.where((m) {
                if (_selectedBatchId != 'ALL' && m.batchId != _selectedBatchId) return false;
                if (_query.isNotEmpty) {
                  final bName = (batchById[m.batchId] ?? m.batchName ?? '').toLowerCase();
                  final match = m.name.toLowerCase().contains(_query) ||
                      m.mentorCode.toLowerCase().contains(_query) ||
                      m.email.toLowerCase().contains(_query) ||
                      bName.contains(_query);
                  if (!match) return false;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return const AppCard(
                  child: EmptyState(
                    title: 'No matching mentors found',
                    message: 'Try clearing the search query or changing the batch filter.',
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
                    final m = filtered[i];
                    final assignedMentees = allStudents.where((s) => s.mentorId == m.uid).toList();
                    return _MentorTile(
                      mentor: m,
                      batchName: batchById[m.batchId] ?? m.batchName ?? m.batchId,
                      assignedMentees: assignedMentees,
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

class _MentorTile extends ConsumerStatefulWidget {
  final MentorProfile mentor;
  final String batchName;
  final List<StudentProfile> assignedMentees;

  const _MentorTile({
    required this.mentor,
    required this.batchName,
    required this.assignedMentees,
  });

  @override
  ConsumerState<_MentorTile> createState() => _MentorTileState();
}

class _MentorTileState extends ConsumerState<_MentorTile> {
  bool _loading = false;

  Future<void> _resetPassword() async {
    setState(() => _loading = true);
    try {
      await ref.read(apiProvider).resetUserPassword(widget.mentor.uid);
      if (mounted) showSnack(context, 'Password reset! They will be prompted to set a new one.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMentorMenteesDialog() {
    final m = widget.mentor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${m.name} (${m.mentorCode}) • ${widget.batchName}'),
        content: SizedBox(
          width: 680,
          height: 460,
          child: widget.assignedMentees.isEmpty
              ? const EmptyState(title: 'No mentees assigned', message: 'This mentor has no assigned mentees.')
              : ListView.separated(
                  itemCount: widget.assignedMentees.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = widget.assignedMentees[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: SruColors.primary,
                        foregroundColor: Colors.white,
                        child: Text(s.name.isEmpty ? '?' : s.name[0]),
                      ),
                      title: Text('${s.name} (${s.studentCode})', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${s.branch ?? "CSE"} • Tasks: ${s.progress.completed}/${s.progress.assigned} • POTD: ${s.potdCount} 🔥 (${s.milestone})',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: OutlinedButton(
                        onPressed: () => showMenteeProfileDialog(
                          context,
                          student: s,
                          mentor: m,
                          batchName: widget.batchName,
                        ),
                        child: const Text('Inspect Profile'),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mentor;
    final count = widget.assignedMentees.isNotEmpty ? widget.assignedMentees.length : m.studentCount;

    return ListTile(
      onTap: _showMentorMenteesDialog,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: CircleAvatar(
        backgroundColor: SruColors.primary,
        foregroundColor: Colors.white,
        child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      title: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: SruColors.surfaceBlue,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              m.mentorCode,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: SruColors.primary),
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
          '${m.email}  •  Assigned Mentees: $count',
          style: const TextStyle(fontSize: 12, color: SruColors.textSecondary, fontWeight: FontWeight.w500),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.groups_rounded, size: 16),
            label: Text('Mentees ($count)'),
            onPressed: _showMentorMenteesDialog,
          ),
          const SizedBox(width: 4),
          _loading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'mentees') _showMentorMenteesDialog();
                    if (v == 'reset') _resetPassword();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'mentees',
                      child: Row(children: [Icon(Icons.groups_rounded, size: 18), SizedBox(width: 8), Text('View Assigned Mentees')]),
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

class _MentorDialog extends ConsumerStatefulWidget {
  final List<Batch> batches;
  const _MentorDialog({required this.batches});

  @override
  ConsumerState<_MentorDialog> createState() => _MentorDialogState();
}

class _MentorDialogState extends ConsumerState<_MentorDialog> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  String? _batchId;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.batches.isNotEmpty) _batchId = widget.batches.first.id;
  }

  Future<void> _submit() async {
    if (_code.text.trim().isEmpty || _name.text.trim().isEmpty || _email.text.trim().isEmpty || _batchId == null) {
      setState(() => _error = 'All fields are required');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).createMentor({
        'mentorCode': _code.text.trim(),
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'batchId': _batchId,
      });
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'Mentor created successfully!');
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
      title: const Text('Add Mentor'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            Row(children: [
              Expanded(child: TextField(controller: _code, decoration: const InputDecoration(labelText: 'Mentor Roll No (e.g. 2303A51408)'))),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _batchId,
                  decoration: const InputDecoration(labelText: 'Batch'),
                  items: widget.batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (v) => setState(() => _batchId = v),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full Name')),
            const SizedBox(height: 12),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)')),
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
