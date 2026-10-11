import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/models.dart';
import '../shared/bulk_assign_dialog.dart';

class MentorTasksPage extends ConsumerWidget {
  const MentorTasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(mentorTasksProvider);
    final mentor = ref.watch(myMentorProfileProvider).valueOrNull;

    return PageBody(
      title: 'Coding Tasks & Bulk Problem Assign',
      subtitle: 'Assign multiple coding problems at once to your mentees or track batch problem sets',
      actions: [
        FilledButton.icon(
          icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
          label: const Text('Bulk Assign Problems'),
          onPressed: () => showBulkProblemAssignDialog(
            context,
            isAdmin: false,
            mentorUid: mentor?.uid,
            mentorBatchId: mentor?.batchId,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(mentorTasksProvider),
          icon: const Icon(Icons.refresh, color: Colors.white),
        ),
      ],
      child: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(mentorTasksProvider)),
        data: (list) => list.isEmpty
            ? AppCard(
                child: EmptyState(
                  icon: Icons.playlist_add_rounded,
                  title: 'No tasks assigned yet',
                  message: 'Click "Bulk Assign Problems" above to assign multiple coding problems at once to your mentees.',
                  action: FilledButton.icon(
                    icon: const Icon(Icons.playlist_add_check_rounded),
                    label: const Text('Bulk Assign Problems Now'),
                    onPressed: () => showBulkProblemAssignDialog(
                      context,
                      isAdmin: false,
                      mentorUid: mentor?.uid,
                      mentorBatchId: mentor?.batchId,
                    ),
                  ),
                ),
              )
            : AppCard(
                padding: EdgeInsets.zero,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => _TaskTile(task: list[i]),
                ),
              ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final t = task;
    final deadlinePassed = t.deadline.isBefore(DateTime.now());
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DifficultyBadge(t.difficulty),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(.1), borderRadius: BorderRadius.circular(99)),
            child: Text(t.platform, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          Text('${t.topic} • due ${fmtDate(t.deadline)} (${timeUntil(t.deadline)})',
              style: TextStyle(fontSize: 13, color: deadlinePassed ? const Color(0xFFB91C1C) : Colors.black54)),
        ]),
      ),
      trailing: OutlinedButton.icon(
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('Open'),
        onPressed: t.problemUrl.isNotEmpty ? () => launchUrl(Uri.parse(t.problemUrl)) : null,
      ),
      onTap: t.description != null && t.description!.isNotEmpty
          ? () => showDialog(context: context, builder: (_) => _TaskDetailDialog(task: t))
          : null,
    );
  }
}

class _TaskDetailDialog extends StatelessWidget {
  final Task task;
  const _TaskDetailDialog({required this.task});

  @override
  Widget build(BuildContext context) {
    final t = task;
    return AlertDialog(
      title: Text(t.title),
      content: SizedBox(
        width: 500,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: 8, children: [DifficultyBadge(t.difficulty), StatusChip(t.platform)]),
          const SizedBox(height: 12),
          Text('Topic: ${t.topic}'),
          Text('Deadline: ${fmtDate(t.deadline)}'),
          if (t.description != null && t.description!.isNotEmpty) ...[
            const Divider(height: 20),
            const Text('Description:', style: TextStyle(fontWeight: FontWeight.w600)),
            Text(t.description!),
          ],
          const SizedBox(height: 12),
          const Text('Problem URL:', style: TextStyle(fontWeight: FontWeight.w600)),
          InkWell(
            onTap: () => launchUrl(Uri.parse(t.problemUrl)),
            child: Text(t.problemUrl, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
