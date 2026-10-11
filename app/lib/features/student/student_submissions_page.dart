import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/models.dart';

class StudentSubmissionsPage extends ConsumerWidget {
  const StudentSubmissionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissions = ref.watch(studentSubmissionsProvider);
    return PageBody(
      title: 'My Submissions',
      subtitle: 'Your submitted solutions and mentor feedback',
      actions: [
        IconButton(tooltip: 'Refresh', onPressed: () => ref.invalidate(studentSubmissionsProvider), icon: const Icon(Icons.refresh)),
      ],
      child: submissions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(studentSubmissionsProvider)),
        data: (list) => list.isEmpty
            ? const AppCard(child: EmptyState(title: 'No submissions yet', message: 'Start a task and submit it to see it here.'))
            : AppCard(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => _SubmissionTile(submission: list[i]),
                ),
              ),
      ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  final Submission submission;
  const _SubmissionTile({required this.submission});

  @override
  Widget build(BuildContext context) {
    final s = submission;
    final c = statusColor(s.reviewStatus);
    final hasFeedback = s.mentorFeedback != null && s.mentorFeedback!.isNotEmpty;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      title: Text(s.taskTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 4),
        Text('Submitted ${fmtDateTime(s.submittedAt)}'),
        const SizedBox(height: 4),
        Wrap(spacing: 8, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(99)),
            child: Text(s.reviewStatus == 'NEEDS_CHANGES' ? 'Needs Changes' : s.reviewStatus[0] + s.reviewStatus.substring(1).toLowerCase(),
                style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          if (hasFeedback) Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.indigo.withOpacity(.12), borderRadius: BorderRadius.circular(99)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.comment_outlined, size: 12, color: Colors.indigo),
              SizedBox(width: 4),
              Text('Has feedback', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600, fontSize: 12)),
            ]),
          ),
        ]),
      ]),
      isThreeLine: true,
      onTap: () => showDialog(context: context, builder: (_) => _SubmissionDetailDialog(submission: s)),
    );
  }
}

class _SubmissionDetailDialog extends StatelessWidget {
  final Submission submission;
  const _SubmissionDetailDialog({required this.submission});

  @override
  Widget build(BuildContext context) {
    final s = submission;
    final hasFeedback = s.mentorFeedback != null && s.mentorFeedback!.isNotEmpty;
    return AlertDialog(
      title: Text(s.taskTitle),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Submitted: ${fmtDateTime(s.submittedAt)} • Revision: ${s.revision}',
                style: const TextStyle(color: Colors.black54)),
            const Divider(height: 20),
            const Text('My Understanding:', style: TextStyle(fontWeight: FontWeight.w600)),
            Text(s.understanding),
            const SizedBox(height: 12),
            const Text('My Approach:', style: TextStyle(fontWeight: FontWeight.w600)),
            Text(s.approach),
            const SizedBox(height: 12),
            Text('Time: ${s.timeComplexity}  |  Space: ${s.spaceComplexity}'),
            if (s.solutionUrl != null && s.solutionUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Solution URL:', style: TextStyle(fontWeight: FontWeight.w600)),
              InkWell(
                onTap: () => launchUrl(Uri.parse(s.solutionUrl!)),
                child: Text(s.solutionUrl!, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
              ),
            ],
            if (hasFeedback) ...[
              const Divider(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: statusColor(s.reviewStatus).withOpacity(.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor(s.reviewStatus).withOpacity(.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.rate_review_outlined, color: statusColor(s.reviewStatus), size: 18),
                    const SizedBox(width: 8),
                    Text('Mentor Feedback', style: TextStyle(fontWeight: FontWeight.w700, color: statusColor(s.reviewStatus))),
                  ]),
                  const SizedBox(height: 8),
                  Text(s.mentorFeedback!),
                ]),
              ),
            ],
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
