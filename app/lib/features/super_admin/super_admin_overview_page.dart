import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../../data/providers.dart';

class SuperAdminOverviewPage extends ConsumerWidget {
  const SuperAdminOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(adminBatchesStreamProvider);
    final mentorsAsync = ref.watch(adminMentorsProvider);
    final studentsAsync = ref.watch(adminStudentsProvider);
    final countsAsync = ref.watch(adminCountsProvider);

    return PageBody(
      title: 'Institution Overview (Super Admin)',
      subtitle: 'Cross-batch and cross-admin institution analytics, compliance, and oversight',
      actions: [
        IconButton(
          tooltip: 'Refresh Analytics',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () {
            ref.invalidate(adminCountsProvider);
            ref.invalidate(adminBatchesStreamProvider);
            ref.invalidate(adminMentorsProvider);
            ref.invalidate(adminStudentsProvider);
          },
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Institution Banner ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF312E81), Color(0xFF4338CA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text(
                  'Institution Oversight & Administration',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Super Admin has institution-wide privileges across all batches, student cohorts, mentors, and administrators.',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                ),
              ]),
            ),
            const SizedBox(width: 16),
            const CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white24,
              child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 30),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // ── High-Level Institution Stats ──
        countsAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
          error: (e, _) => ErrorView(e),
          data: (counts) {
            return batchesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (batches) {
                return mentorsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (mentors) {
                    return studentsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => const SizedBox.shrink(),
                      data: (students) {
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          StatGrid(children: [
                            StatCard(icon: Icons.domain_rounded, label: 'Active Batches', value: '${batches.length}', color: const Color(0xFF4F46E5)),
                            StatCard(icon: Icons.engineering_outlined, label: 'Total Mentors', value: '${mentors.length}', color: const Color(0xFF0284C7)),
                            StatCard(icon: Icons.groups_rounded, label: 'Enrolled Juniors', value: '${students.length}', color: const Color(0xFF10B981)),
                            StatCard(icon: Icons.pending_actions_rounded, label: 'Awaiting Reviews', value: '${counts["pendingReviews"] ?? 0}', color: const Color(0xFFF59E0B)),
                          ]),
                          const SizedBox(height: 24),

                          // ── Cross-Batch Breakdown ──
                          const Text('Cross-Batch Distribution & Performance',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                          const SizedBox(height: 12),

                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: batches.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final b = batches[i];
                                final bStudents = students.where((s) => s.batchId == b.id).toList();
                                final bMentors = mentors.where((m) => m.batchId == b.id).toList();

                                return ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFEEF2FF),
                                    child: Icon(Icons.school, color: Color(0xFF4F46E5), size: 18),
                                  ),
                                  title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Academic Year: ${b.academicYear} • Status: ${b.isActive ? "Active" : "Archived"}'),
                                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                                      child: Text('${bMentors.length} Mentors', style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                                      child: Text('${bStudents.length} Students', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                                    ),
                                  ]),
                                );
                              },
                            ),
                          ),
                        ]);
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ]),
    );
  }
}
