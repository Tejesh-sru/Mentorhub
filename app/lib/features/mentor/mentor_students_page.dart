import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sru_branding.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/cssp_models.dart';
import '../../models/models.dart';
import '../shared/bulk_assign_dialog.dart';
import '../shared/mentee_profile_dialog.dart';
import 'student_detail_page.dart';

class MentorStudentsPage extends ConsumerStatefulWidget {
  const MentorStudentsPage({super.key});

  @override
  ConsumerState<MentorStudentsPage> createState() => _MentorStudentsPageState();
}

class _MentorStudentsPageState extends ConsumerState<MentorStudentsPage> {
  String _search = '';
  String _filter = 'ALL'; // ALL, AWAITING_REVIEW, VERIFIED, DOUBTFUL, BELOW_TARGET, MISSING_LINKS

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final mentorProfile = ref.watch(myMentorProfileProvider).valueOrNull;
    final students = ref.watch(mentorStudentsProvider);
    final batchSubmissions = ref.watch(csspBatchSubmissionsProvider(user?.batchId ?? '')).valueOrNull ?? [];

    return PageBody(
      title: 'My Juniors (${mentorProfile?.batchName ?? "Batch"})',
      subtitle: 'Manage, search, bulk-assign problems, and inspect your assigned mentees',
      actions: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: SruColors.primary),
          onPressed: () {
            showBulkProblemAssignDialog(
              context,
              isAdmin: false,
              mentorUid: user?.uid,
              mentorBatchId: mentorProfile?.batchId ?? user?.batchId ?? 'g6_b1',
            );
          },
          icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
          label: const Text('Bulk Assign Problems'),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(mentorStudentsProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: students.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(mentorStudentsProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const AppCard(
              child: EmptyState(
                title: 'No students assigned yet',
                message: 'Your students will appear here once assigned by the administrator.',
              ),
            );
          }

          final filtered = list.where((s) {
            // Search filter
            if (_search.isNotEmpty) {
              final q = _search.toLowerCase();
              final matchesSearch = s.name.toLowerCase().contains(q) || s.studentCode.toLowerCase().contains(q);
              if (!matchesSearch) return false;
            }

            // Category filter
            if (_filter == 'MISSING_LINKS') {
              return !ProfileLinksHelper.isValidUrl(s.leetcode) ||
                  !ProfileLinksHelper.isValidUrl(s.github) ||
                  !ProfileLinksHelper.isValidUrl(s.linkedin) ||
                  !ProfileLinksHelper.isValidUrl(s.resume);
            }

            final studentSubs = batchSubmissions.where((sub) => sub.juniorUid == s.uid);
            if (_filter == 'AWAITING_REVIEW') {
              return s.progress.awaitingReview > 0 || studentSubs.any((sub) => sub.status == 'AWAITING_REVIEW');
            }
            if (_filter == 'VERIFIED') {
              return studentSubs.any((sub) => sub.verificationStatus == 'VERIFIED');
            }
            if (_filter == 'DOUBTFUL') {
              return studentSubs.any((sub) => sub.verificationStatus == 'DOUBTFUL');
            }
            if (_filter == 'NEEDS_ATTENTION') {
              return s.progress.overdue > 0 || s.progress.pending > 0;
            }

            return true;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search & Filter header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SruColors.blueBorder, width: 1.4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search by student name or roll number (e.g. 2403A51015)...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    if (_search.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () => setState(() => _search = ''),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${filtered.length} Students',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _filter == 'ALL',
                    onSelected: (_) => setState(() => _filter = 'ALL'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Awaiting Review'),
                    selected: _filter == 'AWAITING_REVIEW',
                    selectedColor: Colors.orange.shade100,
                    onSelected: (_) => setState(() => _filter = 'AWAITING_REVIEW'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Verified'),
                    selected: _filter == 'VERIFIED',
                    selectedColor: Colors.green.shade100,
                    onSelected: (_) => setState(() => _filter = 'VERIFIED'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Doubtful'),
                    selected: _filter == 'DOUBTFUL',
                    selectedColor: Colors.red.shade100,
                    onSelected: (_) => setState(() => _filter = 'DOUBTFUL'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Needs Attention'),
                    selected: _filter == 'NEEDS_ATTENTION',
                    selectedColor: Colors.amber.shade100,
                    onSelected: (_) => setState(() => _filter = 'NEEDS_ATTENTION'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Missing Links'),
                    selected: _filter == 'MISSING_LINKS',
                    selectedColor: Colors.deepOrange.shade100,
                    onSelected: (_) => setState(() => _filter = 'MISSING_LINKS'),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // Responsive Student Cards Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1000;
                  if (isWide) {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 220,
                      ),
                      itemBuilder: (context, i) => _StudentCard(student: filtered[i]),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) => _StudentCard(student: filtered[i]),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final StudentProfile student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final s = student;
    final pr = s.progress;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => StudentDetailPage(student: s)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SruColors.blueBorder, width: 1.4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C1E40AF),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Avatar, Name, Roll No, Completion count
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF1B365D),
                  foregroundColor: Colors.white,
                  child: Text(
                    s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              s.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B365D).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.studentCode,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B365D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(s.email, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${pr.completed}/${pr.assigned}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: Color(0xFF0F172A)),
                    ),
                    const Text('solved', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  ],
                ),
              ],
            ),

            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ProgressLine(pr.percentage),
            ),

            // Badges row
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoBadge(Icons.check_circle_outline, 'Completed', '${pr.completed}', const Color(0xFF10B981)),
                _InfoBadge(Icons.hourglass_bottom_rounded, 'Pending', '${pr.pending}', const Color(0xFF3B82F6)),
                _InfoBadge(Icons.rate_review_outlined, 'Review', '${pr.awaitingReview}', const Color(0xFFF59E0B)),
                _InfoBadge(Icons.local_fire_department_rounded, 'POTD (${s.milestone})', '${s.potdCount}', const Color(0xFFEA580C)),
                if (pr.overdue > 0)
                  _InfoBadge(Icons.warning_amber_rounded, 'Overdue', '${pr.overdue}', const Color(0xFFEF4444)),
              ],
            ),

            const Divider(height: 14, color: Color(0xFFF1F5F9)),

            // Footer: Handles icons + Action link
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (s.leetcode?.isNotEmpty ?? false)
                      _handleIconBtn(context, 'LeetCode', s.leetcode!, Icons.code, const Color(0xFFFFA116)),
                    if (s.codeforce?.isNotEmpty ?? false)
                      _handleIconBtn(context, 'Codeforces', s.codeforce!, Icons.military_tech_outlined, const Color(0xFF1877F2)),
                    if (s.hackerrank?.isNotEmpty ?? false)
                      _handleIconBtn(context, 'HackerRank', s.hackerrank!, Icons.terminal, const Color(0xFF2EC866)),
                    if (s.github?.isNotEmpty ?? false)
                      _handleIconBtn(context, 'GitHub', s.github!, Icons.folder_shared_outlined, const Color(0xFF24292E)),
                    if (s.linkedin?.isNotEmpty ?? false)
                      _handleIconBtn(context, 'LinkedIn', s.linkedin!, Icons.work_outline, const Color(0xFF0A66C2)),
                    if (s.resume?.isNotEmpty ?? false)
                      _handleIconBtn(context, 'Resume CV', s.resume!, Icons.description_outlined, const Color(0xFFEA4335)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => showMenteeProfileDialog(context, student: s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: SruColors.surfaceBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.analytics_outlined, size: 14, color: SruColors.primary),
                            SizedBox(width: 4),
                            Text(
                              'Profile & Analysis',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: SruColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF4F46E5)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _handleIconBtn(BuildContext context, String label, String url, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: 'Open $label ($url)',
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => openExternalUrl(context, url, label: label),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoBadge(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            '$value $label',
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
