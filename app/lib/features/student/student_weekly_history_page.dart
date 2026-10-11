import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sru_branding.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/cssp_models.dart';

class StudentWeeklyHistoryPage extends ConsumerWidget {
  const StudentWeeklyHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final batchId = user?.batchId ?? 'default';

    final weeksAsync = ref.watch(csspWeeksProvider(batchId));
    final submissionsAsync = ref.watch(csspStudentSubmissionsProvider(user?.uid ?? ''));

    return PageBody(
      title: '12-Week Milestone History',
      subtitle: 'Complete 12-week breakdown of your submitted counts and verified mentor results',
      child: weeksAsync.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        error: (e, _) => ErrorView(e),
        data: (weeks) {
          return submissionsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ErrorView(e),
            data: (submissions) {
              final subMap = {for (var s in submissions) s.weekId: s};

              int verifiedCount = submissions.where((s) => s.verificationStatus == 'VERIFIED').length;

              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Performance Summary Card ──
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: SruColors.navy,
                      child: Text('$verifiedCount/12',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Weekly Submission & Verification History',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        SizedBox(height: 4),
                        Text(
                          'Track your problem-solving submissions, mentor reviews, and seriousness ratings week by week.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── 12-Week Grid / Cards ──
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: weeks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final week = weeks[index];
                    final sub = subMap[week.weekId];

                    final isVerified = sub?.verificationStatus == 'VERIFIED';
                    final isDoubtful = sub?.verificationStatus == 'DOUBTFUL';
                    final isPending = sub != null && sub.status == 'AWAITING_REVIEW';
                    final hasSubmitted = sub != null;

                    final badgeColor = isVerified
                        ? const Color(0xFF10B981)
                        : (isDoubtful ? const Color(0xFFEF4444) : (isPending ? const Color(0xFFF59E0B) : Colors.grey));

                    final badgeText = isVerified
                        ? 'Verified'
                        : (isDoubtful
                            ? 'Doubtful'
                            : (isPending ? 'Awaiting Review' : 'Not Submitted'));

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isVerified ? Colors.green.shade200 : Colors.grey.shade200,
                          width: isVerified ? 1.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: SruColors.navy.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                week.label,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: SruColors.navy, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Starts: ${Format.date(week.startsAt)}',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 14),

                          // Claimed vs Verified
                          Row(children: [
                            Expanded(
                              child: _CountBox(
                                label: 'Your Submitted Claim',
                                value: hasSubmitted ? '${sub.claimedCount} problems' : '—',
                                color: SruColors.cyan,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _CountBox(
                                label: 'Verified Result',
                                value: isVerified || isDoubtful ? '${sub?.verifiedCount ?? 0} problems' : 'Pending',
                                color: isVerified ? Colors.green : Colors.grey,
                              ),
                            ),
                          ]),

                          if (sub?.problemName != null && sub!.problemName!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Explainable Problem: ${sub.problemName}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                            ),
                          ],

                          if (sub?.remarks != null && sub!.remarks!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                'Senior Remark: "${sub.remarks}" • Seriousness: ${sub.seriousness ?? 'N/A'}',
                                style: TextStyle(fontSize: 12, color: Colors.brown.shade900),
                              ),
                            ),
                          ],
                        ]),
                      ),
                    );
                  },
                ),
              ]);
            },
          );
        },
      ),
    );
  }
}

class _CountBox extends StatelessWidget {
  const _CountBox({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SruColors.blueBorder, width: 1.2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
      ]),
    );
  }
}
