import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/models.dart';

class AdminSubmissionsPage extends ConsumerStatefulWidget {
  const AdminSubmissionsPage({super.key});

  @override
  ConsumerState<AdminSubmissionsPage> createState() => _AdminSubmissionsPageState();
}

class _AdminSubmissionsPageState extends ConsumerState<AdminSubmissionsPage> {
  String _filter = 'ALL'; // ALL | PENDING | APPROVED | NEEDS_CHANGES

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(adminSubmissionsProvider);
    return PageBody(
      title: 'Submissions',
      subtitle: 'All student assignment submissions across the programme',
      actions: [
        IconButton(tooltip: 'Refresh', onPressed: () => ref.invalidate(adminSubmissionsProvider), icon: const Icon(Icons.refresh)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['ALL', 'PENDING', 'APPROVED', 'NEEDS_CHANGES'].map((f) {
                final active = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f == 'ALL' ? 'All' : f.toLowerCase().replaceAll('_', ' ').replaceFirst('n', 'N')),
                    selected: active,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          all.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(adminSubmissionsProvider)),
            data: (list) {
              final filtered = _filter == 'ALL' ? list : list.where((s) => s.reviewStatus == _filter).toList();
              return filtered.isEmpty
                  ? const AppCard(child: EmptyState(title: 'No submissions found'))
                  : AppCard(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) => _SubmissionTile(submission: filtered[i]),
                      ),
                    );
            },
          ),
        ],
      ),
    );
  }
}

class _SubmissionTile extends ConsumerWidget {
  final Submission submission;
  const _SubmissionTile({required this.submission});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = submission;
    final c = statusColor(s.reviewStatus);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      title: Text(s.taskTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 4),
        Text('By ${s.studentName} (${s.studentCode}) • submitted ${fmtDateTime(s.submittedAt)}'),
        const SizedBox(height: 4),
        Wrap(spacing: 8, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(99)),
            child: Text(s.reviewStatus, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          if (s.revision > 1) Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.purple.withOpacity(.12), borderRadius: BorderRadius.circular(99)),
            child: Text('Rev ${s.revision}', style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ]),
      ]),
      isThreeLine: true,
      trailing: OutlinedButton(
        onPressed: () => showDialog(context: context, builder: (_) => _SubmissionDetailDialog(submission: s, ref: ref)),
        child: const Text('View'),
      ),
    );
  }
}

class _SubmissionDetailDialog extends StatelessWidget {
  final Submission submission;
  final WidgetRef ref;
  const _SubmissionDetailDialog({required this.submission, required this.ref});

  @override
  Widget build(BuildContext context) {
    final s = submission;
    return AlertDialog(
      title: Text(s.taskTitle),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('By ${s.studentName} (${s.studentCode})', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Submitted: ${fmtDateTime(s.submittedAt)} • Revision: ${s.revision}'),
            const Divider(height: 24),
            const Text('Understanding:', style: TextStyle(fontWeight: FontWeight.w600)),
            Text(s.understanding),
            const SizedBox(height: 8),
            const Text('Approach:', style: TextStyle(fontWeight: FontWeight.w600)),
            Text(s.approach),
            const SizedBox(height: 8),
            Text('Time: ${s.timeComplexity} | Space: ${s.spaceComplexity}', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (s.solutionUrl != null && s.solutionUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Solution URL:', style: TextStyle(fontWeight: FontWeight.w600)),
              InkWell(
                onTap: () => launchUrl(Uri.parse(s.solutionUrl!)),
                child: Text(s.solutionUrl!, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
              ),
            ],
            if (s.mentorFeedback != null && s.mentorFeedback!.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Mentor Feedback:', style: TextStyle(fontWeight: FontWeight.w600)),
              Text(s.mentorFeedback!),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}
