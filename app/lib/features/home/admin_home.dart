import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/sru_branding.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';

class AdminHome extends ConsumerWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(adminCountsProvider);
    return PageBody(
      title: 'SRU Administration Dashboard',
      subtitle: 'SR University CSSP Portal • Coordinate mentors, mentees, mock evaluations, and batch compliance',
      actions: [IconButton(tooltip: 'Refresh', onPressed: () => ref.invalidate(adminCountsProvider), icon: const Icon(Icons.refresh))],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── CSSP Quick Actions Grid ──
        Row(children: [
          Expanded(
            child: _AdminActionTile(
              title: 'Mock Planner',
              subtitle: 'Custom & Batch Slots',
              icon: Icons.event_available_rounded,
              color: SruColors.navy,
              onTap: () => context.go('/admin/mocks'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AdminActionTile(
              title: 'User Allocation',
              subtitle: 'Assign Senior Mentors',
              icon: Icons.people_outline_rounded,
              color: SruColors.royal,
              onTap: () => context.go('/admin/user-allocation'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AdminActionTile(
              title: 'Bulk Import',
              subtitle: 'CSV Preview & Upsert',
              icon: Icons.file_upload_outlined,
              color: const Color(0xFF10B981),
              onTap: () => context.go('/admin/import'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AdminActionTile(
              title: 'Batches',
              subtitle: 'Academic Batches',
              icon: Icons.collections_bookmark_outlined,
              color: SruColors.cyan,
              onTap: () => context.go('/admin/batches'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AdminActionTile(
              title: 'Batch Reports',
              subtitle: 'Export CSV & Stats',
              icon: Icons.assessment_outlined,
              color: SruColors.red,
              onTap: () => context.go('/admin/reports'),
            ),
          ),
        ]),
        const SizedBox(height: 24),

        const Text('Batch Statistics & Health', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A))),
        const SizedBox(height: 12),
        counts.when(
          loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(adminCountsProvider)),
          data: (c) => StatGrid(children: [
            StatCard(icon: Icons.engineering_outlined, label: 'Total Mentors', value: '${c['mentors']}'),
            StatCard(icon: Icons.groups_outlined, label: 'Total Students', value: '${c['students']}', color: const Color(0xFF0369A1)),
            StatCard(icon: Icons.code, label: 'Tasks', value: '${c['tasks']}', color: const Color(0xFF7E22CE)),
            StatCard(icon: Icons.inbox_outlined, label: 'Pending Reviews', value: '${c['pendingReviews']}', color: const Color(0xFFB45309)),
            StatCard(icon: Icons.warning_amber_rounded, label: 'Overdue Tasks', value: '${c['overdue']}', color: const Color(0xFFB91C1C)),
          ]),
        ),
      ]),
    );
  }
}

class _AdminActionTile extends StatelessWidget {
  const _AdminActionTile({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: SruColors.blueBorder, width: 1.4),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}
