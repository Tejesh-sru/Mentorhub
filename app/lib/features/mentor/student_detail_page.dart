import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/progress.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/providers.dart';
import '../../models/cssp_models.dart';
import '../../models/models.dart';

// ───────────────────────────── entry point ──────────────────────────────────

/// Full-featured student detail view with profile, coding handles, tasks, and submission reviews.
class StudentDetailPage extends ConsumerStatefulWidget {
  const StudentDetailPage({super.key, required this.student});
  final StudentProfile student;

  @override
  ConsumerState<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends ConsumerState<StudentDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final pr = s.progress;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Flexible(
                child: Text(s.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  s.studentCode,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          Text(s.email, style: TextStyle(fontSize: 12, color: scheme.onPrimary.withOpacity(.75))),
        ]),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Send Notice to Batch',
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () => _showQuickNoticeDialog(context, s),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.person_outline, size: 20), text: 'Profile & Handles'),
            Tab(icon: Icon(Icons.verified_outlined, size: 20), text: 'Live Verification'),
            Tab(icon: Icon(Icons.video_chat_outlined, size: 20), text: 'Mock Interviews'),
            Tab(icon: Icon(Icons.task_alt_outlined, size: 20), text: 'Tasks (Done/Pending)'),
            Tab(icon: Icon(Icons.rate_review_outlined, size: 20), text: 'Submissions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ProfileTab(student: s, progress: pr),
          _LiveVerificationTab(student: s),
          _MockInterviewTab(student: s),
          _TasksTab(student: s),
          _SubmissionsTab(studentId: s.uid),
        ],
      ),
    );
  }

  void _showQuickNoticeDialog(BuildContext context, StudentProfile student) {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send Notice to Batch ${student.batchId}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Daily Review Notice'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Message', hintText: 'Write message or reminder...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || msgCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref.read(apiProvider).createAnnouncement({
                  'title': titleCtrl.text.trim(),
                  'message': msgCtrl.text.trim(),
                  'targetType': 'BATCH',
                  'batchId': student.batchId,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notice sent successfully!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Profile Tab ──────────────────────────────────

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.student, required this.progress});
  final StudentProfile student;
  final Progress progress;

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url.trim());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open link: $url')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid URL: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = student;
    final pr = progress;

    final hasHandles = (s.leetcode?.isNotEmpty ?? false) ||
        (s.codeforce?.isNotEmpty ?? false) ||
        (s.hackerrank?.isNotEmpty ?? false) ||
        (s.github?.isNotEmpty ?? false) ||
        (s.linkedin?.isNotEmpty ?? false) ||
        (s.resume?.isNotEmpty ?? false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Hero card ──
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(children: [
              _AvatarRing(name: s.name, percentage: pr.percentage),
              const SizedBox(width: 22),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
                  const SizedBox(height: 6),
                  _InfoRow(Icons.badge_outlined, s.studentCode),
                  _InfoRow(Icons.email_outlined, s.email),
                  if (s.phone != null && s.phone!.isNotEmpty) _InfoRow(Icons.phone_outlined, s.phone!),
                  _InfoRow(Icons.groups_outlined, 'Batch: ${s.batchId}'),
                  const SizedBox(height: 12),
                  _PerformanceBadge(pr),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // ── Coding Platforms & Handles Section ──
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.code_rounded, color: Color(0xFF4F46E5), size: 20),
                const SizedBox(width: 8),
                const Text('Coding Profiles & Social Handles',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                if (!hasHandles)
                  Text('Not linked yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ]),
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _HandleButton(
                  title: 'LeetCode',
                  url: s.leetcode,
                  icon: Icons.terminal_rounded,
                  brandColor: const Color(0xFFFFA116),
                  onTap: s.leetcode != null ? () => _openUrl(context, s.leetcode!) : null,
                ),
                _HandleButton(
                  title: 'Codeforces',
                  url: s.codeforce,
                  icon: Icons.military_tech_outlined,
                  brandColor: const Color(0xFF1877F2),
                  onTap: s.codeforce != null ? () => _openUrl(context, s.codeforce!) : null,
                ),
                _HandleButton(
                  title: 'HackerRank',
                  url: s.hackerrank,
                  icon: Icons.code,
                  brandColor: const Color(0xFF2EC866),
                  onTap: s.hackerrank != null ? () => _openUrl(context, s.hackerrank!) : null,
                ),
                _HandleButton(
                  title: 'GitHub',
                  url: s.github,
                  icon: Icons.folder_shared_outlined,
                  brandColor: const Color(0xFF24292E),
                  onTap: s.github != null ? () => _openUrl(context, s.github!) : null,
                ),
                _HandleButton(
                  title: 'LinkedIn',
                  url: s.linkedin,
                  icon: Icons.work_outline_rounded,
                  brandColor: const Color(0xFF0A66C2),
                  onTap: s.linkedin != null ? () => _openUrl(context, s.linkedin!) : null,
                ),
                _HandleButton(
                  title: 'Resume (CV)',
                  url: s.resume,
                  icon: Icons.description_outlined,
                  brandColor: const Color(0xFFEA4335),
                  onTap: s.resume != null ? () => _openUrl(context, s.resume!) : null,
                ),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // ── Stats grid ──
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: [
            _StatTile('Total Assigned', '${pr.assigned}', Icons.assignment_outlined, const Color(0xFF4F46E5)),
            _StatTile('Completed (Done)', '${pr.completed}', Icons.check_circle_outline, const Color(0xFF15803D)),
            _StatTile('Pending / Active', '${pr.pending}', Icons.hourglass_bottom_rounded, const Color(0xFF1D4ED8)),
            _StatTile('Awaiting Review', '${pr.awaitingReview}', Icons.rate_review_outlined, const Color(0xFFB45309)),
            _StatTile('Overdue Tasks', '${pr.overdue}', Icons.warning_amber_rounded,
                pr.overdue > 0 ? const Color(0xFFB91C1C) : Colors.grey),
            _StatTile('Accuracy / Rate', '${pr.percentage.toStringAsFixed(0)}%', Icons.insights_rounded,
                const Color(0xFF7C3AED)),
          ],
        ),
        const SizedBox(height: 16),

        // ── Progress bar ──
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Milestone Completion', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text('${pr.percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF4F46E5))),
              ]),
              const SizedBox(height: 12),
              ProgressLine(pr.percentage),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${pr.completed} tasks solved',
                      style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
                  Text('${pr.assigned - pr.completed} remaining',
                      style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// Clickable Platform Profile Tile
class _HandleButton extends StatelessWidget {
  const _HandleButton({
    required this.title,
    required this.url,
    required this.icon,
    required this.brandColor,
    this.onTap,
  });

  final String title;
  final String? url;
  final IconData icon;
  final Color brandColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isLinked = url != null && url!.trim().isNotEmpty;
    return InkWell(
      onTap: isLinked ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isLinked ? brandColor.withOpacity(0.08) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLinked ? brandColor.withOpacity(0.3) : Colors.grey.shade300,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: isLinked ? brandColor : Colors.grey),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isLinked ? brandColor : Colors.grey,
              ),
            ),
            Text(
              isLinked ? 'Open ↗' : 'Not linked',
              style: TextStyle(
                fontSize: 10,
                color: isLinked ? Colors.black54 : Colors.grey,
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// Circular avatar with progress ring
class _AvatarRing extends StatelessWidget {
  const _AvatarRing({required this.name, required this.percentage});
  final String name;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 90,
      child: CustomPaint(
        painter: _RingPainter(percentage / 100),
        child: Center(
          child: CircleAvatar(
            radius: 35,
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  _RingPainter(this.fraction);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    final fg = Paint()
      ..color = const Color(0xFF4F46E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromLTWH(2.5, 2.5, size.width - 5, size.height - 5);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, bg);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(children: [
        Icon(icon, size: 15, color: Colors.black45),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}

class _PerformanceBadge extends StatelessWidget {
  const _PerformanceBadge(this.pr);
  final Progress pr;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    final IconData icon;
    if (pr.percentage >= 80) {
      label = 'Top Performer ★';
      color = const Color(0xFF15803D);
      icon = Icons.star_rounded;
    } else if (pr.percentage >= 50) {
      label = 'Consistent 🎯';
      color = const Color(0xFF1D4ED8);
      icon = Icons.thumb_up_rounded;
    } else if (pr.overdue > 0) {
      label = 'Needs Attention ⚠️';
      color = const Color(0xFFB91C1C);
      icon = Icons.warning_amber_rounded;
    } else {
      label = 'In Progress ⏳';
      color = const Color(0xFFB45309);
      icon = Icons.hourglass_bottom;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value, this.icon, this.color);
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(.12),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: color)),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────────── Tasks Tab ────────────────────────────────────

class _TasksTab extends ConsumerStatefulWidget {
  const _TasksTab({required this.student});
  final StudentProfile student;

  @override
  ConsumerState<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends ConsumerState<_TasksTab> {
  String _filter = 'ALL';
  String _searchQuery = '';

  static const _filterOptions = [
    {'key': 'ALL', 'label': 'All Tasks'},
    {'key': 'DONE', 'label': 'Done (Completed)'},
    {'key': 'PENDING', 'label': 'Pending / In Progress'},
    {'key': 'AWAITING_REVIEW', 'label': 'Awaiting Review'},
    {'key': 'OVERDUE', 'label': 'Overdue'},
  ];

  @override
  Widget build(BuildContext context) {
    final assignments = ref.watch(studentAssignmentsProvider(widget.student.uid));
    return assignments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(studentAssignmentsProvider(widget.student.uid))),
      data: (list) {
        final filtered = list.where((a) {
          // Status filter
          if (_filter == 'DONE' && a.status != 'COMPLETED') return false;
          if (_filter == 'PENDING' && (a.status == 'COMPLETED' || a.status == 'OVERDUE')) return false;
          if (_filter == 'AWAITING_REVIEW' && a.status != 'SUBMITTED') return false;
          if (_filter == 'OVERDUE' && a.status != 'OVERDUE') return false;

          // Search query
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            return a.taskTitle.toLowerCase().contains(q) ||
                a.topic.toLowerCase().contains(q) ||
                a.platform.toLowerCase().contains(q);
          }
          return true;
        }).toList();

        final doneCount = list.where((a) => a.status == 'COMPLETED').length;
        final pendingCount = list.where((a) => a.status != 'COMPLETED' && a.status != 'OVERDUE').length;

        return Column(children: [
          // Filter Bar & Search
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(children: [
              // Search input
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search tasks by title, topic, platform...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 10),
              // Segment Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filterOptions.map((opt) {
                    final key = opt['key']!;
                    final label = opt['label']!;
                    final selected = _filter == key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (_) => setState(() => _filter = key),
                        selectedColor: const Color(0xFF4F46E5).withOpacity(.15),
                        checkmarkColor: const Color(0xFF4F46E5),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ]),
          ),
          const Divider(height: 1),

          // Count Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${filtered.length} of ${list.length} tasks',
                  style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
                ),
                Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Color(0xFF15803D), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text('$doneCount Done', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15803D))),
                  const SizedBox(width: 12),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Color(0xFF1D4ED8), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text('$pendingCount Pending', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8))),
                ]),
              ],
            ),
          ),

          Expanded(
            child: filtered.isEmpty
                ? const Center(child: EmptyState(title: 'No tasks found', message: 'No tasks match the filter.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _AssignmentCard(assignment: filtered[i]),
                  ),
          ),
        ]);
      },
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.assignment});
  final Assignment assignment;

  static Color _statusColor(String s) => switch (s) {
        'COMPLETED' => const Color(0xFF15803D),
        'SUBMITTED' => const Color(0xFF1D4ED8),
        'IN_PROGRESS' => const Color(0xFF4F46E5),
        'OVERDUE' => const Color(0xFFB91C1C),
        _ => const Color(0xFFB45309),
      };

  static Color _diffColor(String d) => switch (d) {
        'EASY' => const Color(0xFF15803D),
        'MEDIUM' => const Color(0xFFB45309),
        _ => const Color(0xFFB91C1C),
      };

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final dc = _diffColor(a.difficulty);
    final isDone = a.status == 'COMPLETED';
    final isOverdue = a.deadline.isBefore(DateTime.now()) && !isDone;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDone
              ? const Color(0xFF15803D).withOpacity(0.3)
              : (isOverdue ? const Color(0xFFB91C1C).withOpacity(.3) : Colors.grey.shade200),
          width: isDone || isOverdue ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDone
                    ? const Color(0xFF15803D).withOpacity(0.1)
                    : (isOverdue ? const Color(0xFFB91C1C).withOpacity(0.1) : const Color(0xFF4F46E5).withOpacity(0.1)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDone ? Icons.check_circle : (isOverdue ? Icons.error_outline : Icons.pending_actions),
                size: 16,
                color: isDone ? const Color(0xFF15803D) : (isOverdue ? const Color(0xFFB91C1C) : const Color(0xFF4F46E5)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(a.taskTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            StatusChip(a.status),
          ]),
          const SizedBox(height: 8),
          if (a.taskDescription != null && a.taskDescription!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                a.taskDescription!,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _MiniChip(a.platform, Icons.computer_outlined, const Color(0xFF4F46E5)),
            _MiniChip(a.topic, Icons.label_outline, const Color(0xFF0891B2)),
            _MiniChip(a.difficulty, Icons.speed, dc),
            _MiniChip(
              'Due ${_fmt(a.deadline)}',
              isOverdue ? Icons.warning_amber_rounded : Icons.calendar_today_outlined,
              isOverdue ? const Color(0xFFB91C1C) : Colors.black54,
            ),
          ]),
          if (a.problemUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => launchUrl(Uri.parse(a.problemUrl), mode: LaunchMode.externalApplication),
              child: const Row(children: [
                Icon(Icons.open_in_new, size: 14, color: Color(0xFF4F46E5)),
                SizedBox(width: 4),
                Text('Open Problem Statement',
                    style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  static String _fmt(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ───────────────────────────── Submissions Tab ──────────────────────────────

class _SubmissionsTab extends ConsumerWidget {
  const _SubmissionsTab({required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subs = ref.watch(studentSubmissionsForMentorProvider(studentId));
    return subs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(studentSubmissionsForMentorProvider(studentId))),
      data: (list) => list.isEmpty
          ? const Center(
              child: EmptyState(
                title: 'No submissions yet',
                message: 'This student hasn\'t submitted any solutions yet.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _SubmissionCard(sub: list[i]),
            ),
    );
  }
}

class _SubmissionCard extends ConsumerWidget {
  const _SubmissionCard({required this.sub});
  final Submission sub;

  static Color _reviewColor(String s) => switch (s) {
        'APPROVED' => const Color(0xFF15803D),
        'NEEDS_REVISION' => const Color(0xFFB91C1C),
        _ => const Color(0xFFB45309),
      };

  void _showReviewDialog(BuildContext context, WidgetRef ref) {
    final feedbackCtrl = TextEditingController(text: sub.mentorFeedback ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Review: ${sub.taskTitle}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: feedbackCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Feedback for Student',
              hintText: 'e.g. Great approach! Optimize space complexity next time.',
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(apiProvider).reviewSubmission(
                submissionId: sub.id,
                decision: 'NEEDS_REVISION',
                feedback: feedbackCtrl.text.trim(),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Requested revision with feedback!'), backgroundColor: Colors.orange),
              );
            },
            child: const Text('Needs Revision'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(apiProvider).reviewSubmission(
                submissionId: sub.id,
                decision: 'APPROVED',
                feedback: feedbackCtrl.text.trim(),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Submission Approved!'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = this.sub;
    final rc = _reviewColor(sub.reviewStatus);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(sub.taskTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: rc.withOpacity(.1), borderRadius: BorderRadius.circular(20)),
              child: Text(sub.reviewStatus, style: TextStyle(color: rc, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Submitted: ${_fmt(sub.submittedAt)}  •  Revision #${sub.revision}',
            style: const TextStyle(color: Colors.black45, fontSize: 12),
          ),
          const Divider(height: 20),

          // Approach & complexity
          _DetailRow('Approach', sub.approach),
          _DetailRow('Understanding', sub.understanding),
          _DetailRow('Time Complexity', sub.timeComplexity),
          _DetailRow('Space Complexity', sub.spaceComplexity),

          // Code preview if present
          if (sub.code != null && sub.code!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Submitted Code', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: sub.code!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied to clipboard!')),
                        );
                      },
                      child: const Icon(Icons.copy, size: 14, color: Colors.white70),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    sub.code!,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],

          if (sub.mentorFeedback != null && sub.mentorFeedback!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF4F46E5).withOpacity(.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.rate_review_outlined, size: 15, color: Color(0xFF4F46E5)),
                  SizedBox(width: 6),
                  Text('Mentor Feedback',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF4F46E5))),
                ]),
                const SizedBox(height: 6),
                Text(sub.mentorFeedback!, style: const TextStyle(fontSize: 13, color: Colors.black87)),
              ]),
            ),
          ],

          const SizedBox(height: 12),
          Row(children: [
            if (sub.solutionUrl != null && sub.solutionUrl!.isNotEmpty)
              OutlinedButton.icon(
                icon: const Icon(Icons.code, size: 14),
                label: const Text('External Solution', style: TextStyle(fontSize: 12)),
                onPressed: () => launchUrl(Uri.parse(sub.solutionUrl!), mode: LaunchMode.externalApplication),
              ),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.rate_review, size: 14),
              label: Text(sub.reviewStatus == 'PENDING' ? 'Review Now' : 'Edit Review', style: const TextStyle(fontSize: 12)),
              onPressed: () => _showReviewDialog(context, ref),
            ),
          ]),
        ]),
      ),
    );
  }

  static String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 130,
          child: Text('$label:', style: const TextStyle(color: Colors.black45, fontSize: 13)),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

// ───────────────────────────── Live Verification Tab ──────────────────────────

class _LiveVerificationTab extends ConsumerStatefulWidget {
  const _LiveVerificationTab({required this.student});
  final StudentProfile student;

  @override
  ConsumerState<_LiveVerificationTab> createState() => _LiveVerificationTabState();
}

class _LiveVerificationTabState extends ConsumerState<_LiveVerificationTab> {
  String _selectedWeekId = 'W1';
  final _verifiedCountCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  String _status = 'VERIFIED'; // VERIFIED, DOUBTFUL, NOT_CHECKED
  String _seriousness = 'HIGH'; // HIGH, MEDIUM, LOW
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _verifiedCountCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _syncForm(WeeklySubmission? sub) {
    if (sub != null) {
      _verifiedCountCtrl.text = sub.verifiedCount != null
          ? '${sub.verifiedCount}'
          : (sub.claimedCount > 0 ? '${sub.claimedCount}' : '');
      _remarksCtrl.text = sub.remarks ?? '';
      _status = sub.verificationStatus ?? 'VERIFIED';
      _seriousness = sub.seriousness ?? 'HIGH';
    } else {
      _verifiedCountCtrl.clear();
      _remarksCtrl.clear();
      _status = 'VERIFIED';
      _seriousness = 'HIGH';
    }
  }

  Future<void> _saveVerification(String batchId, WeekConfig week) async {
    final count = int.tryParse(_verifiedCountCtrl.text.trim());
    if (count == null || count < 0) {
      setState(() => _error = 'Please enter a valid verified count (>= 0).');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final seniorUser = ref.read(currentUserProvider).valueOrNull;
    final submissionId = '${batchId}_${week.weekId}_${widget.student.uid}';

    final payload = {
      'submissionId': submissionId,
      'batchId': batchId,
      'weekId': week.weekId,
      'juniorUid': widget.student.uid,
      'verifiedCount': count,
      'verificationStatus': _status,
      'seriousness': _seriousness,
      'remarks': _remarksCtrl.text.trim(),
    };

    try {
      try {
        await ref.read(apiProvider).verifyWeeklyProgress(payload);
      } catch (_) {
        // Direct Firestore fallback
        final subRef = ref.read(firestoreProvider).collection('submissions').doc(submissionId);
        final verRef = ref.read(firestoreProvider).collection('verifications').doc(submissionId);

        final updateData = {
          'verifiedCount': count,
          'verificationStatus': _status,
          'seriousness': _seriousness,
          'remarks': _remarksCtrl.text.trim(),
          'checkedAt': DateTime.now(),
          'checkedByUid': seniorUser?.uid,
          'reviewedBy': seniorUser?.uid,
          'reviewedAt': DateTime.now(),
          'status': _status == 'VERIFIED' ? 'VERIFIED' : (_status == 'DOUBTFUL' ? 'DOUBTFUL' : 'AWAITING_REVIEW'),
          'updatedAt': DateTime.now(),
        };

        await subRef.set(updateData, SetOptions(merge: true));
        await verRef.set({
          'submissionId': submissionId,
          'batchId': batchId,
          'weekId': week.weekId,
          'juniorUid': widget.student.uid,
          'verifiedCount': count,
          'verificationStatus': _status,
          'seriousness': _seriousness,
          'remarks': _remarksCtrl.text.trim(),
          'checkedAt': DateTime.now(),
          'checkedByUid': seniorUser?.uid,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification saved for ${widget.student.name} (${week.label})!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Failed to save verification: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final batchId = s.batchId.isNotEmpty ? s.batchId : 'default';

    final weeksAsync = ref.watch(csspWeeksProvider(batchId));
    final submissionsAsync = ref.watch(csspStudentSubmissionsProvider(s.uid));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: weeksAsync.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
        error: (e, _) => ErrorView(e),
        data: (weeks) {
          final activeWeek = weeks.firstWhere((w) => w.weekId == _selectedWeekId, orElse: () => weeks.first);

          return submissionsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
            error: (e, _) => ErrorView(e),
            data: (submissions) {
              final sub = submissions.where((sub) => sub.weekId == _selectedWeekId).firstOrNull;

              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Week selector pills ──
                const Text('Select Week to Review:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: weeks.map((w) {
                      final selected = w.weekId == _selectedWeekId;
                      final weekSub = submissions.where((s) => s.weekId == w.weekId).firstOrNull;
                      final st = weekSub?.verificationStatus ?? (weekSub != null ? 'PENDING' : 'NONE');

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(w.label),
                            const SizedBox(width: 4),
                            if (st == 'VERIFIED')
                              const Icon(Icons.check_circle, size: 13, color: Colors.green)
                            else if (st == 'DOUBTFUL')
                              const Icon(Icons.error_outline, size: 13, color: Colors.red)
                            else if (st == 'PENDING')
                              const Icon(Icons.hourglass_top, size: 13, color: Colors.orange),
                          ]),
                          selected: selected,
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedWeekId = w.weekId;
                                _error = null;
                              });
                              final nextSub = submissions.where((s) => s.weekId == w.weekId).firstOrNull;
                              _syncForm(nextSub);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Junior's Claim Summary ──
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('${activeWeek.label} Student Submission', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: sub == null
                              ? Colors.grey.shade100
                              : (sub.status == 'VERIFIED' ? Colors.green.shade50 : Colors.orange.shade50),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          sub == null ? 'Not Submitted' : sub.status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: sub == null ? Colors.grey : (sub.status == 'VERIFIED' ? Colors.green : Colors.orange.shade800),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _DetailBox(
                          label: 'Mentoring Week',
                          value: activeWeek.label,
                          color: const Color(0xFF1B365D),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DetailBox(
                          label: 'Claimed Solved',
                          value: sub != null ? '${sub.claimedCount} problems' : 'No claim',
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ]),
                    if (sub?.problemName != null && sub!.problemName!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Explainable Problem: ${sub.problemName}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      if (sub.problemUrl != null && sub.problemUrl!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final uri = Uri.tryParse(sub.problemUrl!);
                            if (uri != null && await canLaunchUrl(uri)) launchUrl(uri);
                          },
                          child: Text(
                            sub.problemUrl!,
                            style: const TextStyle(color: Colors.blue, fontSize: 12, decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ],
                    if (sub?.approach != null && sub!.approach!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                        child: Text('Approach: ${sub.approach}', style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 18),

                // ── Senior Live Review Form ──
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Live Verification Recording', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text(
                      'Verify profile total and live problem explanation. Record verified count, seriousness, and dated remark.',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
                      ),
                    TextField(
                      controller: _verifiedCountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Verified Count *',
                        helperText: 'Record verified count for ${activeWeek.label}',
                        prefixIcon: const Icon(Icons.check_circle_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _status,
                          decoration: InputDecoration(
                            labelText: 'Verification Status',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'VERIFIED', child: Text('Verified')),
                            DropdownMenuItem(value: 'DOUBTFUL', child: Text('Doubtful')),
                            DropdownMenuItem(value: 'NOT_CHECKED', child: Text('Not Checked')),
                          ],
                          onChanged: (v) => setState(() => _status = v ?? 'VERIFIED'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _seriousness,
                          decoration: InputDecoration(
                            labelText: 'Seriousness Rating',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'HIGH', child: Text('High')),
                            DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                            DropdownMenuItem(value: 'LOW', child: Text('Low')),
                          ],
                          onChanged: (v) => setState(() => _seriousness = v ?? 'HIGH'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _remarksCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Dated Remark / Live Review Feedback',
                        hintText: 'e.g. Explaining two-pointer approach well; LeetCode profile verified live.',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : () => _saveVerification(batchId, activeWeek),
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.verified),
                        label: Text(_saving ? 'Saving...' : 'Save Verification to Firestore'),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── 12-Week Progression History ──
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('12-Week Progress & Verification Overview',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap any week to review or edit remarks and verification status.',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 16,
                        headingRowHeight: 38,
                        dataRowMinHeight: 44,
                        dataRowMaxHeight: 52,
                        columns: const [
                          DataColumn(label: Text('Week', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Claimed', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Verified', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: weeks.map((w) {
                          final weekSub = submissions.where((s) => s.weekId == w.weekId).firstOrNull;
                          final isCurrent = w.weekId == _selectedWeekId;
                          final st = weekSub?.verificationStatus ?? (weekSub != null ? 'AWAITING' : 'NOT SUBMITTED');

                          return DataRow(
                            selected: isCurrent,
                            onSelectChanged: (_) {
                              setState(() {
                                _selectedWeekId = w.weekId;
                                _error = null;
                              });
                              _syncForm(weekSub);
                            },
                            cells: [
                              DataCell(Text(w.label, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(weekSub != null ? '${weekSub.claimedCount}' : '—')),
                              DataCell(Text(weekSub?.verifiedCount != null ? '${weekSub!.verifiedCount}' : '—')),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: st == 'VERIFIED'
                                      ? Colors.green.shade50
                                      : (st == 'DOUBTFUL' ? Colors.red.shade50 : Colors.orange.shade50),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  st,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: st == 'VERIFIED'
                                        ? Colors.green.shade700
                                        : (st == 'DOUBTFUL' ? Colors.red.shade700 : Colors.orange.shade700),
                                  ),
                                ),
                              )),
                              DataCell(SizedBox(
                                width: 180,
                                child: Text(
                                  weekSub?.remarks ?? '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ]),
                ),
              ]);
            },
          );
        },
      ),
    );
  }
}

// ───────────────────────────── Mock Interview Tab ─────────────────────────────

class _MockInterviewTab extends ConsumerStatefulWidget {
  const _MockInterviewTab({required this.student});
  final StudentProfile student;

  @override
  ConsumerState<_MockInterviewTab> createState() => _MockInterviewTabState();
}

class _MockInterviewTabState extends ConsumerState<_MockInterviewTab> {
  String _selectedWeekId = 'W1';
  final _score10Ctrl = TextEditingController();
  final _technical5Ctrl = TextEditingController();
  final _communication5Ctrl = TextEditingController();
  final _problemSolving5Ctrl = TextEditingController();
  final _recommendationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _status = 'COMPLETED'; // NOT_PLANNED, SCHEDULED, COMPLETED, MISSED
  DateTime? _scheduledAt;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _score10Ctrl.dispose();
    _technical5Ctrl.dispose();
    _communication5Ctrl.dispose();
    _problemSolving5Ctrl.dispose();
    _recommendationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _syncMock(MockInterview? mock) {
    if (mock != null) {
      _score10Ctrl.text = mock.score10 != null ? '${mock.score10}' : '';
      _technical5Ctrl.text = mock.technical5 != null ? '${mock.technical5}' : '';
      _communication5Ctrl.text = mock.communication5 != null ? '${mock.communication5}' : '';
      _problemSolving5Ctrl.text = mock.problemSolving5 != null ? '${mock.problemSolving5}' : '';
      _recommendationCtrl.text = mock.recommendation ?? '';
      _notesCtrl.text = mock.notes ?? '';
      _status = mock.status;
      _scheduledAt = mock.scheduledAt;
    } else {
      _score10Ctrl.clear();
      _technical5Ctrl.clear();
      _communication5Ctrl.clear();
      _problemSolving5Ctrl.clear();
      _recommendationCtrl.clear();
      _notesCtrl.clear();
      _status = 'NOT_PLANNED';
      _scheduledAt = null;
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _scheduledAt != null ? TimeOfDay.fromDateTime(_scheduledAt!) : const TimeOfDay(hour: 16, minute: 0),
      );
      if (pickedTime != null) {
        setState(() {
          _scheduledAt = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (_status == 'NOT_PLANNED') _status = 'SCHEDULED';
        });
      }
    }
  }

  Future<void> _saveMock(String batchId, WeekConfig week) async {
    // Validate score ranges according to specification
    final score10 = double.tryParse(_score10Ctrl.text.trim()) ?? 0;
    final technical5 = double.tryParse(_technical5Ctrl.text.trim()) ?? 0;
    final communication5 = double.tryParse(_communication5Ctrl.text.trim()) ?? 0;
    final problemSolving5 = double.tryParse(_problemSolving5Ctrl.text.trim()) ?? 0;

    if (_status == 'COMPLETED') {
      if (score10 < 0 || score10 > 10) {
        setState(() => _error = 'Overall score must be between 0 and 10.');
        return;
      }
      if (technical5 < 0 || technical5 > 5) {
        setState(() => _error = 'Technical score must be between 0 and 5.');
        return;
      }
      if (communication5 < 0 || communication5 > 5) {
        setState(() => _error = 'Communication score must be between 0 and 5.');
        return;
      }
      if (problemSolving5 < 0 || problemSolving5 > 5) {
        setState(() => _error = 'Problem solving score must be between 0 and 5.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final seniorUser = ref.read(currentUserProvider).valueOrNull;
    final docId = '${batchId}_${week.weekId}_${widget.student.uid}';

    final payload = {
      'batchId': batchId,
      'weekId': week.weekId,
      'juniorUid': widget.student.uid,
      'score10': score10,
      'technical5': technical5,
      'communication5': communication5,
      'problemSolving5': problemSolving5,
      'recommendation': _recommendationCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
      'status': _status,
      'scheduledAt': _scheduledAt?.toIso8601String(),
    };

    try {
      try {
        await ref.read(apiProvider).evaluateMock(payload);
      } catch (_) {
        // Direct Firestore fallback
        final refDoc = ref.read(firestoreProvider).collection('mocks').doc(docId);
        await refDoc.set({
          'batchId': batchId,
          'weekId': week.weekId,
          'juniorUid': widget.student.uid,
          'seniorUid': seniorUser?.uid,
          'evaluatorUid': seniorUser?.uid,
          'status': _status,
          'score10': score10,
          'technical5': technical5,
          'communication5': communication5,
          'problemSolving5': problemSolving5,
          'recommendation': _recommendationCtrl.text.trim(),
          'notes': _notesCtrl.text.trim(),
          'scheduledAt': _scheduledAt,
          'updatedAt': DateTime.now(),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mock interview evaluation saved for ${widget.student.name} (${week.label})!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Failed to save mock: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final batchId = s.batchId.isNotEmpty ? s.batchId : 'default';

    final weeksAsync = ref.watch(csspWeeksProvider(batchId));
    final mocksAsync = ref.watch(csspStudentMocksProvider(s.uid));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: weeksAsync.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
        error: (e, _) => ErrorView(e),
        data: (weeks) {
          final activeWeek = weeks.firstWhere((w) => w.weekId == _selectedWeekId, orElse: () => weeks.first);

          return mocksAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
            error: (e, _) => ErrorView(e),
            data: (mocks) {
              final mock = mocks.where((m) => m.weekId == _selectedWeekId).firstOrNull;

              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Week selector pills ──
                const Text('Select Mock Week:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: weeks.map((w) {
                      final selected = w.weekId == _selectedWeekId;
                      final weekMock = mocks.where((m) => m.weekId == w.weekId).firstOrNull;
                      final st = weekMock?.status ?? 'NOT_PLANNED';

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(w.label),
                            const SizedBox(width: 4),
                            if (st == 'COMPLETED')
                              const Icon(Icons.check_circle, size: 13, color: Colors.green)
                            else if (st == 'SCHEDULED')
                              const Icon(Icons.alarm, size: 13, color: Colors.blue)
                            else if (st == 'MISSED')
                              const Icon(Icons.warning_amber, size: 13, color: Colors.red),
                          ]),
                          selected: selected,
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedWeekId = w.weekId;
                                _error = null;
                              });
                              final nextMock = mocks.where((m) => m.weekId == w.weekId).firstOrNull;
                              _syncMock(nextMock);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Evaluation Form ──
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Mock Evaluation & Scheduling (${activeWeek.label})',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text(
                      'Score Overall /10 and independent criteria /5. Do not sum automatically into /10.',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
                      ),

                    // Status and schedule picker
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _status,
                          decoration: InputDecoration(
                            labelText: 'Mock Status',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'NOT_PLANNED', child: Text('Not Planned')),
                            DropdownMenuItem(value: 'SCHEDULED', child: Text('Scheduled')),
                            DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                            DropdownMenuItem(value: 'MISSED', child: Text('Missed (Reschedule)')),
                          ],
                          onChanged: (v) => setState(() => _status = v ?? 'COMPLETED'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDateTime,
                          icon: const Icon(Icons.event, size: 18),
                          label: Text(
                            _scheduledAt != null ? Format.date(_scheduledAt!) : 'Pick Date/Time',
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Score Inputs
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _score10Ctrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Overall Score (/10)',
                            hintText: '0 - 10',
                            prefixIcon: const Icon(Icons.star_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _technical5Ctrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Technical (/5)',
                            hintText: '0 - 5',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _communication5Ctrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Communication (/5)',
                            hintText: '0 - 5',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _problemSolving5Ctrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Problem Solving (/5)',
                            hintText: '0 - 5',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _recommendationCtrl,
                      decoration: InputDecoration(
                        labelText: 'Recommendation',
                        hintText: 'e.g. Ready for placements / Practice recursion tree analysis',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Detailed Mentor Feedback & Notes',
                        hintText: 'Feedback on approach, edge cases handled, and communication style...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : () => _saveMock(batchId, activeWeek),
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Saving...' : 'Save Mock Evaluation'),
                      ),
                    ),
                  ]),
                ),
              ]);
            },
          );
        },
      ),
    );
  }
}

class _DetailBox extends StatelessWidget {
  const _DetailBox({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25), width: 1.2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
      ]),
    );
  }
}
