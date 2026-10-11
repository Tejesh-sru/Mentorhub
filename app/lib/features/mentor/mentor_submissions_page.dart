import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/models.dart';
import '../home/mentor_home.dart'; // re-use ReviewDialog

class MentorSubmissionsPage extends ConsumerStatefulWidget {
  const MentorSubmissionsPage({super.key});

  @override
  ConsumerState<MentorSubmissionsPage> createState() => _MentorSubmissionsPageState();
}

class _MentorSubmissionsPageState extends ConsumerState<MentorSubmissionsPage> {
  String _filter = 'PENDING'; // PENDING | APPROVED | NEEDS_CHANGES | ALL

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(mentorSubmissionsAllProvider);
    return PageBody(
      title: 'Submissions',
      subtitle: 'All submissions from your students',
      actions: [
        IconButton(tooltip: 'Refresh', onPressed: () => ref.invalidate(mentorSubmissionsAllProvider), icon: const Icon(Icons.refresh)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['PENDING', 'APPROVED', 'NEEDS_CHANGES', 'ALL'].map((f) {
                final active = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f == 'ALL' ? 'All' : f == 'NEEDS_CHANGES' ? 'Needs Changes' : f[0] + f.substring(1).toLowerCase()),
                    selected: active,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: Theme.of(context).colorScheme.primary.withOpacity(.15),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          all.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(mentorSubmissionsAllProvider)),
            data: (list) {
              final filtered = _filter == 'ALL' ? list : list.where((s) => s.reviewStatus == _filter).toList();
              return filtered.isEmpty
                  ? AppCard(child: EmptyState(title: 'No ${_filter == 'ALL' ? '' : _filter.toLowerCase()} submissions', icon: Icons.inbox_outlined))
                  : AppCard(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) => _SubmissionRow(submission: filtered[i]),
                      ),
                    );
            },
          ),
        ],
      ),
    );
  }
}

class _SubmissionRow extends ConsumerWidget {
  final Submission submission;
  const _SubmissionRow({required this.submission});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = submission;
    final c = statusColor(s.reviewStatus);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      title: Text(s.taskTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 4),
        Text('By ${s.studentName} (${s.studentCode}) • ${fmtDateTime(s.submittedAt)}'),
        const SizedBox(height: 4),
        Wrap(spacing: 8, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(99)),
            child: Text(s.reviewStatus == 'NEEDS_CHANGES' ? 'Needs Changes' : s.reviewStatus[0] + s.reviewStatus.substring(1).toLowerCase(),
                style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          if (s.revision > 1) Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.purple.withOpacity(.12), borderRadius: BorderRadius.circular(99)),
            child: Text('Rev ${s.revision}', style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ]),
      ]),
      isThreeLine: true,
      trailing: s.reviewStatus == 'PENDING'
          ? FilledButton.icon(
              onPressed: () => showDialog(context: context, builder: (_) => ReviewDialog(submission: s, ref: ref)),
              icon: const Icon(Icons.rate_review, size: 18),
              label: const Text('Review'),
            )
          : OutlinedButton(
              onPressed: () => showDialog(context: context, builder: (_) => _DetailDialog(s)),
              child: const Text('View'),
            ),
    );
  }
}

class _DetailDialog extends StatelessWidget {
  final Submission s;
  const _DetailDialog(this.s);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(s.taskTitle),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('By ${s.studentName} (${s.studentCode})', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Submitted ${fmtDateTime(s.submittedAt)} • Rev ${s.revision}'),
              const Divider(height: 20),
              const Text('Understanding:', style: TextStyle(fontWeight: FontWeight.w600)),
              Text(s.understanding),
              const SizedBox(height: 8),
              const Text('Approach:', style: TextStyle(fontWeight: FontWeight.w600)),
              Text(s.approach),
              const SizedBox(height: 8),
              Text('Time: ${s.timeComplexity}  Space: ${s.spaceComplexity}'),
              if (s.mentorFeedback != null && s.mentorFeedback!.isNotEmpty) ...[
                const Divider(height: 20),
                const Text('Your Feedback:', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(s.mentorFeedback!),
              ],
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      );
}
