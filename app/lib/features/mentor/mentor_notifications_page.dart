import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/sru_branding.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/models.dart';

class MentorNotificationsPage extends ConsumerWidget {
  const MentorNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(mentorNotificationsProvider);
    final mentees = ref.watch(mentorStudentsProvider).valueOrNull ?? [];

    return PageBody(
      title: 'Mentor Notification Center',
      subtitle: 'Real-time alerts on mentee task submissions, POTD completions, admin updates & mentee reminders',
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.done_all_rounded, size: 18),
          label: const Text('Mark All Read'),
          onPressed: () async {
            final list = notificationsAsync.valueOrNull ?? [];
            final unread = list.where((n) => !n.isRead).toList();
            if (unread.isEmpty) return;
            final db = ref.read(firestoreProvider);
            final batch = db.batch();
            for (final n in unread) {
              batch.update(db.doc('notifications/${n.id}'), {'isRead': true});
            }
            await batch.commit();
            if (context.mounted) showSnack(context, 'All notifications marked as read');
          },
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          icon: const Icon(Icons.notifications_active_rounded, size: 18),
          label: const Text('Notify Mentees'),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => _NotifyMenteesDialog(mentees: mentees),
          ),
        ),
      ],
      child: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e),
        data: (list) => list.isEmpty
            ? const AppCard(
                child: EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications yet',
                  message:
                      'You will receive real-time alerts whenever your mentees solve POTDs, submit tasks, or when Admin assigns bulk problems.',
                ),
              )
            : AppCard(
                padding: EdgeInsets.zero,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final n = list[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      tileColor: n.isRead ? Colors.white : SruColors.surfaceBlue.withOpacity(0.35),
                      leading: CircleAvatar(
                        backgroundColor: n.isRead ? const Color(0xFFF3F4F6) : SruColors.primary,
                        foregroundColor: n.isRead ? SruColors.textSecondary : Colors.white,
                        child: Icon(_typeIcon(n.type), size: 20),
                      ),
                      title: Text(
                        n.title,
                        style: TextStyle(
                          fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                          color: SruColors.textPrimary,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 3),
                          Text(n.message, style: const TextStyle(fontSize: 13)),
                          if (n.createdAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd MMM yyyy, hh:mm a').format(n.createdAt!),
                              style: const TextStyle(fontSize: 11, color: SruColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                      trailing: n.isRead
                          ? const Icon(Icons.check_circle_outline, size: 18, color: Colors.grey)
                          : TextButton(
                              onPressed: () => ref
                                  .read(firestoreProvider)
                                  .doc('notifications/${n.id}')
                                  .update({'isRead': true}),
                              child: const Text('Mark read'),
                            ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'POTD_SOLVED':
        return Icons.local_fire_department_rounded;
      case 'TASK_ASSIGNED':
        return Icons.playlist_add_check_rounded;
      case 'COMPLAINT_UPDATE':
        return Icons.shield_outlined;
      default:
        return Icons.notifications_rounded;
    }
  }
}

class _NotifyMenteesDialog extends ConsumerStatefulWidget {
  final List<StudentProfile> mentees;
  const _NotifyMenteesDialog({required this.mentees});

  @override
  ConsumerState<_NotifyMenteesDialog> createState() => _NotifyMenteesDialogState();
}

class _NotifyMenteesDialogState extends ConsumerState<_NotifyMenteesDialog> {
  String _targetUid = 'ALL';
  final _title = TextEditingController(text: 'Coding Milestone & POTD Reminder');
  final _message = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _message.text.trim().isEmpty) {
      showSnack(context, 'Enter title and message', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final db = ref.read(firestoreProvider);
      final targets = _targetUid == 'ALL'
          ? widget.mentees
          : widget.mentees.where((m) => m.uid == _targetUid).toList();
      final batch = db.batch();
      for (final s in targets) {
        final refDoc = db.collection('notifications').doc();
        batch.set(refDoc, {
          'userId': s.uid,
          'title': _title.text.trim(),
          'message': _message.text.trim(),
          'type': 'MENTOR_ALERT',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'Notification sent to ${targets.length} mentee(s)!');
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
      title: const Text('Send Notification to Mentees'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _targetUid,
              decoration: const InputDecoration(labelText: 'Recipient'),
              items: [
                DropdownMenuItem(value: 'ALL', child: Text('All My Mentees (${widget.mentees.length})')),
                ...widget.mentees.map(
                  (s) => DropdownMenuItem(value: s.uid, child: Text('${s.name} (${s.studentCode})')),
                ),
              ],
              onChanged: (v) => setState(() => _targetUid = v ?? 'ALL'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Notification Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Please complete today\'s Problem of the Day and update your LeetCode links...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _busy ? null : _send,
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('Send Alert'),
        ),
      ],
    );
  }
}
