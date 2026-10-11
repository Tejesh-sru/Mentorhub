import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/models.dart';

class StudentNotificationsPage extends ConsumerWidget {
  const StudentNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(studentNotificationsProvider);
    return PageBody(
      title: 'Notifications',
      subtitle: 'Updates from your mentor and the platform',
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('Mark all read'),
          onPressed: () async {
            final notifs = ref.read(studentNotificationsProvider).valueOrNull ?? [];
            final db = ref.read(firestoreProvider);
            final batch = db.batch();
            for (final n in notifs.where((n) => !n.isRead)) {
              batch.update(db.collection('notifications').doc(n.id), {'isRead': true});
            }
            try { await batch.commit(); } catch (_) {}
          },
        ),
        const SizedBox(width: 4),
        IconButton(tooltip: 'Refresh', onPressed: () => ref.invalidate(studentNotificationsProvider), icon: const Icon(Icons.refresh)),
      ],
      child: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(studentNotificationsProvider)),
        data: (list) => list.isEmpty
            ? const AppCard(child: EmptyState(title: 'No notifications yet', icon: Icons.notifications_outlined))
            : AppCard(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => _NotificationTile(notification: list[i]),
                ),
              ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;
  const _NotificationTile({required this.notification});

  IconData _icon(String type) {
    switch (type) {
      case 'TASK_ASSIGNED': return Icons.assignment_outlined;
      case 'SUBMISSION':
      case 'SUBMISSION_RECEIVED': return Icons.upload_outlined;
      case 'VERIFICATION':
      case 'TASK_APPROVED': return Icons.check_circle_outline;
      case 'CHANGES_REQUESTED': return Icons.rate_review_outlined;
      case 'MOCK': return Icons.video_chat_outlined;
      case 'ANNOUNCEMENT': return Icons.campaign_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'VERIFICATION':
      case 'TASK_APPROVED': return const Color(0xFF15803D);
      case 'CHANGES_REQUESTED': return const Color(0xFFC2410C);
      case 'TASK_ASSIGNED': return const Color(0xFF4F46E5);
      case 'MOCK': return const Color(0xFF2563EB);
      case 'SUBMISSION':
      case 'SUBMISSION_RECEIVED': return const Color(0xFF0284C7);
      case 'ANNOUNCEMENT': return const Color(0xFF7C3AED);
      default: return Colors.grey;
    }
  }

  Future<void> _markRead(WidgetRef ref, AppNotification n) async {
    if (n.isRead) return;
    try {
      await ref.read(firestoreProvider).collection('notifications').doc(n.id).update({'isRead': true});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = notification;
    final c = _color(n.type);
    return InkWell(
      onTap: () => _markRead(ref, n),
      child: Container(
        color: n.isRead ? Colors.transparent : c.withOpacity(.04),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: Stack(
            children: [
              CircleAvatar(backgroundColor: c.withOpacity(.12), child: Icon(_icon(n.type), color: c, size: 20)),
              if (!n.isRead)
                Positioned(right: 0, top: 0, child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle))),
            ],
          ),
          title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.w700, fontSize: 16)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Text(n.message, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 4),
            Text(n.createdAt != null ? fmtDateTime(n.createdAt!) : '—', style: const TextStyle(fontSize: 12, color: Colors.black38)),
          ]),
          isThreeLine: true,
          trailing: n.isRead ? null : const Icon(Icons.circle, size: 10, color: Color(0xFF4F46E5)),
        ),
      ),
    );
  }
}
