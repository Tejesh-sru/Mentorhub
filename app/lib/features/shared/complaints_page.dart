import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/sru_branding.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/app_user.dart';
import '../../models/models.dart';

class ComplaintsPage extends ConsumerStatefulWidget {
  const ComplaintsPage({super.key});

  @override
  ConsumerState<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends ConsumerState<ComplaintsPage> {
  String _roleFilter = 'ALL'; // ALL, STUDENT, MENTOR, OPEN

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isAdmin = user?.role == UserRole.admin || user?.role == UserRole.superAdmin;
    final isStudent = user?.role == UserRole.student;

    final complaintsAsync = isAdmin
        ? ref.watch(adminComplaintsProvider)
        : ref.watch(myComplaintsProvider);

    return PageBody(
      title: isAdmin
          ? 'Confidential Complaints & Escalations'
          : isStudent
              ? 'Confidential Complaint Box'
              : 'Mentor Complaint & Escalation Box',
      subtitle: isAdmin
          ? 'Review confidential student complaints (against trainers/mentors) and mentor escalations'
          : isStudent
              ? '100% Confidential • Visible ONLY to You (Mentee) and Chief Admin (Hidden from Trainers & Mentors)'
              : 'Direct escalation channel to Chief Admin • Visible only to you and Admin',
      actions: [
        if (!isAdmin)
          FilledButton.icon(
            icon: const Icon(Icons.lock_person_rounded, size: 18),
            label: Text(isStudent ? 'New Confidential Complaint' : 'Submit Complaint to Admin'),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => _NewComplaintDialog(isStudent: isStudent),
            ),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confidentiality Notice Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SruColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield_rounded, color: Color(0xFFB45309), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAdmin
                            ? 'Strict Privacy Enforcement Active'
                            : 'End-to-End Confidential Channel to University Admin',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isAdmin
                            ? 'Student complaints against Trainers or Mentors are isolated to the Student and Admin. Mentor complaints are isolated to the Mentor and Admin.'
                            : isStudent
                                ? 'If you report an issue regarding a Trainer or Mentor, only you and the Admin can view this ticket and its resolution.'
                                : 'Your complaint goes directly to the Programme Admin for resolution.',
                        style: const TextStyle(fontSize: 12, color: SruColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ALL', label: Text('All')),
                      ButtonSegment(value: 'STUDENT', label: Text('Mentee')),
                      ButtonSegment(value: 'MENTOR', label: Text('Mentor')),
                      ButtonSegment(value: 'OPEN', label: Text('Open')),
                    ],
                    selected: {_roleFilter},
                    onSelectionChanged: (s) => setState(() => _roleFilter = s.first),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          complaintsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorView(e),
            data: (all) {
              final list = all.where((c) {
                if (!isAdmin) return true;
                if (_roleFilter == 'STUDENT') return c.authorRole == 'STUDENT';
                if (_roleFilter == 'MENTOR') return c.authorRole == 'MENTOR';
                if (_roleFilter == 'OPEN') return c.status != 'RESOLVED';
                return true;
              }).toList();

              if (list.isEmpty) {
                return AppCard(
                  child: EmptyState(
                    icon: Icons.verified_user_outlined,
                    title: 'No complaints found',
                    message: isAdmin
                        ? 'No confidential student or mentor complaints match the current filter.'
                        : 'You haven\'t submitted any confidential complaints yet.',
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _ComplaintCard(
                  complaint: list[i],
                  isAdmin: isAdmin,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ComplaintCard extends ConsumerWidget {
  final Complaint complaint;
  final bool isAdmin;

  const _ComplaintCard({required this.complaint, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = complaint;
    final isResolved = c.status == 'RESOLVED';

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
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 12, color: Color(0xFFB91C1C)),
                    SizedBox(width: 4),
                    Text(
                      'CONFIDENTIAL',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFB91C1C)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: c.authorRole == 'STUDENT' ? const Color(0xFFDBEAFE) : const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${c.authorRole}: ${c.authorName} (${c.authorCode})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: c.authorRole == 'STUDENT' ? SruColors.primary : const Color(0xFF6D28D9),
                  ),
                ),
              ),
              Chip(
                label: Text('Regarding ${c.targetType}: ${c.targetName}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                visualDensity: VisualDensity.compact,
              ),
              StatusBadge(c.status),
              if (c.createdAt != null)
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(c.createdAt!),
                  style: const TextStyle(fontSize: 11, color: SruColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            c.subject,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: SruColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            c.description,
            style: const TextStyle(fontSize: 13, color: SruColors.textSecondary, height: 1.45),
          ),
          if (c.adminReply != null && c.adminReply!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.admin_panel_settings_rounded, size: 16, color: Color(0xFF047857)),
                      SizedBox(width: 6),
                      Text(
                        'Admin Official Response:',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF047857)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(c.adminReply!, style: const TextStyle(fontSize: 13, color: Color(0xFF065F46))),
                ],
              ),
            ),
          ],
          if (isAdmin) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.reply_rounded, size: 16),
                  label: Text(isResolved ? 'Update Reply' : 'Reply & Resolve'),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _AdminReplyComplaintDialog(complaint: c),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NewComplaintDialog extends ConsumerStatefulWidget {
  final bool isStudent;
  const _NewComplaintDialog({required this.isStudent});

  @override
  ConsumerState<_NewComplaintDialog> createState() => _NewComplaintDialogState();
}

class _NewComplaintDialogState extends ConsumerState<_NewComplaintDialog> {
  String _targetType = 'TRAINER';
  final _targetName = TextEditingController();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _targetName.dispose();
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subject.text.trim().isEmpty || _description.text.trim().isEmpty) {
      showSnack(context, 'Please fill in the subject and description', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final db = ref.read(firestoreProvider);
      final user = ref.read(currentUserProvider).valueOrNull;
      final stuProfile = widget.isStudent ? ref.read(myStudentProfileProvider).valueOrNull : null;
      final menProfile = !widget.isStudent ? ref.read(myMentorProfileProvider).valueOrNull : null;

      await db.collection('complaints').add({
        'authorUid': user?.uid ?? '',
        'authorName': stuProfile?.name ?? menProfile?.name ?? user?.name ?? 'User',
        'authorCode': stuProfile?.studentCode ?? menProfile?.mentorCode ?? '',
        'authorRole': widget.isStudent ? 'STUDENT' : 'MENTOR',
        'batchId': stuProfile?.batchId ?? menProfile?.batchId ?? user?.batchId,
        'targetType': _targetType,
        'targetName': _targetName.text.trim().isEmpty ? _targetType : _targetName.text.trim(),
        'subject': _subject.text.trim(),
        'description': _description.text.trim(),
        'isConfidential': true,
        'status': 'OPEN',
        'adminReply': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'Confidential complaint submitted directly to Admin.');
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
      title: Text(widget.isStudent ? 'New Confidential Complaint' : 'Submit Escalation to Admin'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _targetType,
                decoration: const InputDecoration(labelText: 'Complaint Regarding'),
                items: widget.isStudent
                    ? const [
                        DropdownMenuItem(value: 'TRAINER', child: Text('Trainer / Lab Instructor')),
                        DropdownMenuItem(value: 'MENTOR', child: Text('Senior Mentor')),
                        DropdownMenuItem(value: 'PROGRAMME', child: Text('Programme / Batch Schedule')),
                        DropdownMenuItem(value: 'TECHNICAL', child: Text('Portal / Technical Issue')),
                      ]
                    : const [
                        DropdownMenuItem(value: 'TRAINER', child: Text('Trainer / Lab Coordination')),
                        DropdownMenuItem(value: 'STUDENT', child: Text('Mentee Non-Responsiveness')),
                        DropdownMenuItem(value: 'PROGRAMME', child: Text('Batch / Schedule Escalation')),
                      ],
                onChanged: (v) => setState(() => _targetType = v ?? 'TRAINER'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _targetName,
                decoration: InputDecoration(
                  labelText: _targetType == 'TRAINER'
                      ? 'Trainer Name / Session Details'
                      : _targetType == 'MENTOR'
                          ? 'Mentor Name / Roll No'
                          : 'Target Name / Reference',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subject,
                decoration: const InputDecoration(labelText: 'Complaint Subject *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Detailed Description (Confidential to Admin) *',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: const Icon(Icons.lock_rounded, size: 16),
          label: const Text('Submit Confidentially'),
        ),
      ],
    );
  }
}

class _AdminReplyComplaintDialog extends ConsumerStatefulWidget {
  final Complaint complaint;
  const _AdminReplyComplaintDialog({required this.complaint});

  @override
  ConsumerState<_AdminReplyComplaintDialog> createState() => _AdminReplyComplaintDialogState();
}

class _AdminReplyComplaintDialogState extends ConsumerState<_AdminReplyComplaintDialog> {
  late final TextEditingController _reply;
  late String _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reply = TextEditingController(text: widget.complaint.adminReply ?? '');
    _status = widget.complaint.status == 'OPEN' ? 'RESOLVED' : widget.complaint.status;
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final db = ref.read(firestoreProvider);
      await db.doc('complaints/${widget.complaint.id}').update({
        'status': _status,
        'adminReply': _reply.text.trim(),
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      // Notify the complaint author (Student or Mentor)
      await db.collection('notifications').add({
        'userId': widget.complaint.authorUid,
        'title': 'Confidential Complaint Updated (${_status})',
        'message': 'Admin responded to "${widget.complaint.subject}": ${_reply.text.trim()}',
        'type': 'COMPLAINT_UPDATE',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'Response sent confidentially to ${widget.complaint.authorName}.');
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
      title: Text('Respond to ${widget.complaint.authorName}'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'OPEN', child: Text('OPEN')),
                DropdownMenuItem(value: 'IN_REVIEW', child: Text('IN REVIEW')),
                DropdownMenuItem(value: 'RESOLVED', child: Text('RESOLVED')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'RESOLVED'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reply,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Official Resolution / Response Note',
                hintText: 'Visible only to the person who submitted this complaint...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Save & Notify Author')),
      ],
    );
  }
}
