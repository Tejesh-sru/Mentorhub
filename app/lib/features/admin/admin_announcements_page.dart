import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/providers.dart';
import '../../models/models.dart';

class AdminAnnouncementsPage extends ConsumerWidget {
  const AdminAnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcements = ref.watch(adminAnnouncementsProvider);
    final batches = ref.watch(adminBatchesStreamProvider);
    final mentors = ref.watch(adminMentorsProvider);
    return PageBody(
      title: 'Announcements',
      subtitle: 'Send updates and view past announcements',
      actions: [
        FilledButton.icon(
          icon: const Icon(Icons.campaign, size: 18),
          label: const Text('New Announcement'),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => _AnnouncementDialog(batches: batches.valueOrNull ?? [], mentors: mentors.valueOrNull ?? [], isAdmin: true),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(tooltip: 'Refresh', onPressed: () => ref.invalidate(adminAnnouncementsProvider), icon: const Icon(Icons.refresh)),
      ],
      child: announcements.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(adminAnnouncementsProvider)),
        data: (list) => list.isEmpty
            ? const AppCard(child: EmptyState(title: 'No announcements yet', icon: Icons.campaign_outlined))
            : AppCard(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => _AnnouncementTile(announcement: list[i]),
                ),
              ),
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  final Announcement announcement;
  const _AnnouncementTile({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEDE9FE),
        child: Icon(Icons.campaign_outlined, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 4),
        Text(a.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 4),
        Text('${a.createdByName} • To: ${a.targetType} • ${a.createdAt != null ? fmtDateTime(a.createdAt!) : "—"}',
            style: const TextStyle(fontSize: 12, color: Colors.black38)),
      ]),
      isThreeLine: true,
      onTap: () => showDialog(context: context, builder: (_) => _AnnouncementDetailDialog(a)),
    );
  }
}

class _AnnouncementDetailDialog extends StatelessWidget {
  final Announcement a;
  const _AnnouncementDetailDialog(this.a);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(a.title),
        content: SizedBox(
          width: 500,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('By ${a.createdByName} (${a.createdByRole})', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Audience: ${a.targetType}${a.batchId != null ? " (batch ${a.batchId})" : ""}'),
            Text('Sent: ${a.createdAt != null ? fmtDateTime(a.createdAt!) : "—"}'),
            const Divider(height: 20),
            Text(a.message),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      );
}

class _AnnouncementDialog extends ConsumerStatefulWidget {
  final List<Batch> batches;
  final List<MentorProfile> mentors;
  final bool isAdmin;
  const _AnnouncementDialog({required this.batches, required this.mentors, required this.isAdmin});

  @override
  ConsumerState<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends ConsumerState<_AnnouncementDialog> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  String _targetType = 'ALL';
  String? _batchId;
  String? _mentorId;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (_title.text.trim().length < 3 || _message.text.trim().length < 3) {
      setState(() => _error = 'Title and message are required (min 3 chars)');
      return;
    }
    if (_targetType == 'MENTOR_STUDENTS' && _mentorId == null) {
      setState(() => _error = 'Select a mentor for this audience');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiProvider).createAnnouncement({
        'title': _title.text.trim(),
        'message': _message.text.trim(),
        'targetType': _targetType,
        if (_batchId != null) 'batchId': _batchId,
        if (_mentorId != null) 'mentorId': _mentorId,
      });
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'Announcement sent!');
      }
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Announcement'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: _message, maxLines: 5, decoration: const InputDecoration(labelText: 'Message')),
            const SizedBox(height: 12),
            if (widget.isAdmin) ...[
              DropdownButtonFormField<String>(
                value: _targetType,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Everyone')),
                  DropdownMenuItem(value: 'MENTORS', child: Text('All Mentors')),
                  DropdownMenuItem(value: 'STUDENTS', child: Text('All Students')),
                  DropdownMenuItem(value: 'MENTOR_STUDENTS', child: Text("A Mentor's Students")),
                ],
                onChanged: (v) => setState(() { _targetType = v!; _mentorId = null; }),
              ),
              const SizedBox(height: 12),
              if (_targetType != 'MENTOR_STUDENTS' && widget.batches.isNotEmpty)
                DropdownButtonFormField<String?>(
                  value: _batchId,
                  decoration: const InputDecoration(labelText: 'Batch (optional — leave empty for all batches)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All batches')),
                    ...widget.batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                  ],
                  onChanged: (v) => setState(() => _batchId = v),
                ),
              if (_targetType == 'MENTOR_STUDENTS')
                DropdownButtonFormField<String?>(
                  value: _mentorId,
                  decoration: const InputDecoration(labelText: 'Mentor *'),
                  items: widget.mentors.map((m) => DropdownMenuItem(value: m.uid, child: Text('${m.name} (${m.mentorCode})'))).toList(),
                  onChanged: (v) => setState(() => _mentorId = v),
                ),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Send'),
        ),
      ],
    );
  }
}
