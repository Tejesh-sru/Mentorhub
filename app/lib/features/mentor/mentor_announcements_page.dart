import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/providers.dart';

class MentorAnnouncementsPage extends ConsumerWidget {
  const MentorAnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcements = ref.watch(mentorAnnouncementsProvider);
    return PageBody(
      title: 'Announcements',
      subtitle: 'Send updates to your students and see all announcements',
      actions: [
        FilledButton.icon(
          icon: const Icon(Icons.campaign, size: 18),
          label: const Text('New Announcement'),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const _MentorAnnouncementDialog(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(tooltip: 'Refresh', onPressed: () => ref.invalidate(mentorAnnouncementsProvider), icon: const Icon(Icons.refresh)),
      ],
      child: announcements.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(mentorAnnouncementsProvider)),
        data: (list) => list.isEmpty
            ? const AppCard(child: EmptyState(title: 'No announcements yet', icon: Icons.campaign_outlined))
            : AppCard(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final a = list[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEDE9FE),
                        child: Icon(Icons.campaign_outlined, color: Theme.of(context).colorScheme.primary),
                      ),
                      title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SizedBox(height: 4),
                        Text(a.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54)),
                        Text('${a.createdByName} • ${a.createdAt != null ? fmtDateTime(a.createdAt!) : "—"}', style: const TextStyle(fontSize: 12, color: Colors.black38)),
                      ]),
                      isThreeLine: true,
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _MentorAnnouncementDialog extends ConsumerStatefulWidget {
  const _MentorAnnouncementDialog();

  @override
  ConsumerState<_MentorAnnouncementDialog> createState() => _MentorAnnouncementDialogState();
}

class _MentorAnnouncementDialogState extends ConsumerState<_MentorAnnouncementDialog> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (_title.text.trim().length < 3 || _message.text.trim().length < 3) {
      setState(() => _error = 'Title and message are required (min 3 chars)');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      // Backend enforces targetType = MENTOR_STUDENTS for mentor role
      await ref.read(apiProvider).createAnnouncement({
        'title': _title.text.trim(),
        'message': _message.text.trim(),
        'targetType': 'MENTOR_STUDENTS',
      });
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'Announcement sent to your students!');
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
      title: const Text('Announce to Your Students'),
      content: SizedBox(
        width: 480,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(controller: _message, maxLines: 5, decoration: const InputDecoration(labelText: 'Message')),
          const SizedBox(height: 8),
          const Text('This message will be sent to all your assigned students.', style: TextStyle(color: Colors.black54, fontSize: 12)),
        ]),
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
