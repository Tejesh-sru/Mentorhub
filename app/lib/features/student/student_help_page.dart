import 'package:flutter/material.dart';
import '../../core/widgets.dart';

class StudentHelpPage extends StatelessWidget {
  const StudentHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageBody(
      title: 'Programme Guidelines & Help',
      subtitle: 'Complete guidelines for CSSP weekly submissions, mentor live verifications, and mock interviews',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _HelpSection(
          title: '1. 12-Week LeetCode Targets',
          icon: Icons.track_changes_rounded,
          color: const Color(0xFF4F46E5),
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text(
              'The programme defines a 12-week schedule beginning 05 October 2026. Weekly cumulative targets are configured as follows:',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 10),
            Text('• Week 1: 98 cumulative problems\n'
                '• Week 2: 111 cumulative problems\n'
                '• Week 3: 141 cumulative problems\n'
                '• Week 4: 156 cumulative problems\n'
                '• Week 5: 170 cumulative problems\n'
                '• Week 6: 184 cumulative problems\n'
                '• Weeks 7–12: 207 cumulative problems',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.5)),
            SizedBox(height: 10),
            Text(
              'Note: Batch administrators may configure adjusted targets. Comparisons always use the selected week\'s configured target.',
              style: TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        _HelpSection(
          title: '2. Live Verification Workflow',
          icon: Icons.verified_user_outlined,
          color: const Color(0xFF10B981),
          content: const Text(
            'Submitting a weekly count does not mark your milestone verified. '
            'Your assigned Senior Mentor conducts a live review session where you demonstrate your solved problems and explain your approach live. '
            'The Senior explicitly records your verified count, seriousness rating (High/Medium/Low), and dated remarks in Firestore. '
            'A week is marked "Target Met" ONLY if verified count >= that week\'s cumulative target. Pending or awaiting review submissions never count as verified.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        const SizedBox(height: 16),

        _HelpSection(
          title: '3. Mock Interviews & Rubrics',
          icon: Icons.rate_review_outlined,
          color: const Color(0xFF0284C7),
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text(
              'Weekly mock interviews are scheduled (typically in Tue–Thu half-hour slots). Four independent assessments are scored:',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 8),
            Text('• Overall Mock Score: 0 to 10 scale\n'
                '• Technical Criteria: 0 to 5 scale\n'
                '• Communication Criteria: 0 to 5 scale\n'
                '• Problem Solving Criteria: 0 to 5 scale',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.5)),
            SizedBox(height: 8),
            Text(
              'These criteria are treated as separate assessments and not automatically summed into the overall score. Missed mocks can be rescheduled with your Senior Mentor.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        _HelpSection(
          title: '4. Six Profile Links Requirement',
          icon: Icons.link_rounded,
          color: const Color(0xFF7C3AED),
          content: const Text(
            'All juniors must link 6 verified profile links: LeetCode, Codeforces, HackerRank, LinkedIn, GitHub, and Résumé (PDF). '
            'Links must be valid HTTP/HTTPS URLs. Seniors and Admins monitor missing links on their dashboards.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
      ]),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.title, required this.icon, required this.color, required this.content});
  final String title;
  final IconData icon;
  final Color color;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        const SizedBox(height: 12),
        content,
      ]),
    );
  }
}
