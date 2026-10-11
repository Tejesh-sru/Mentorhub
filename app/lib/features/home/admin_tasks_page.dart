import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/sru_branding.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../shared/bulk_assign_dialog.dart';

class AdminTasksPage extends ConsumerStatefulWidget {
  const AdminTasksPage({super.key});

  @override
  ConsumerState<AdminTasksPage> createState() => _AdminTasksPageState();
}

class _AdminTasksPageState extends ConsumerState<AdminTasksPage> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _url = TextEditingController();
  final _topic = TextEditingController();
  String _platform = 'LEETCODE';
  String _difficulty = 'EASY';
  int _days = 3;
  bool _loading = false;

  String? _batchId;

  Future<void> _createTask() async {
    if (_batchId == null) {
      showSnack(context, 'Please select a batch first', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final deadlineStr = DateTime.now().add(Duration(days: _days)).toUtc().toIso8601String();
      await ref.read(apiProvider).createTask({
        'title': _title.text,
        'description': _desc.text,
        'platform': _platform,
        'problemUrl': _url.text,
        'difficulty': _difficulty,
        'topic': _topic.text,
        'batchId': _batchId,
        'deadline': deadlineStr,
        'assignTo': {'type': 'BATCH'},
      });
      if (mounted) {
        showSnack(context, 'Successfully created and assigned task!');
        _title.clear();
        _desc.clear();
        _url.clear();
        _topic.clear();
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(adminBatchesProvider);
    final studentsAsync = ref.watch(adminStudentsProvider);
    final tasksAsync = ref.watch(adminTasksProvider);

    return PageBody(
      title: 'Assign Tasks & Bulk Problem Assignment',
      subtitle: 'Assign multiple coding problems at once (Bulk Assign) or create a single task for a batch',
      actions: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: SruColors.primary),
          onPressed: () {
            showBulkProblemAssignDialog(
              context,
              isAdmin: true,
            );
          },
          icon: const Icon(Icons.playlist_add_check_rounded),
          label: const Text('Bulk Assign Problems'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fast Bulk Problem Assignment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                          SizedBox(height: 4),
                          Text(
                            'Instead of assigning one by one, use Bulk Assign to push 5+ LeetCode/HackerRank problems at once to all 4 batches, a single batch, or a specific mentor group.',
                            style: TextStyle(color: SruColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
                      onPressed: () {
                        showBulkProblemAssignDialog(
                          context,
                          isAdmin: true,
                        );
                      },
                      icon: const Icon(Icons.bolt_rounded),
                      label: const Text('Open Bulk Problem Assigner'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Single Task Assignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                TextField(controller: _title, decoration: const InputDecoration(labelText: 'Task Title')),
                const SizedBox(height: 16),
                TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description (optional)'), maxLines: 2),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: TextField(controller: _topic, decoration: const InputDecoration(labelText: 'Topic (e.g. Arrays)'))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: batchesAsync.when(
                      loading: () => const CircularProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                      data: (batches) {
                        if (_batchId == null && batches.isNotEmpty) {
                          _batchId = batches.first['id'];
                        }
                        return DropdownButtonFormField<String>(
                          value: _batchId,
                          decoration: const InputDecoration(labelText: 'Batch'),
                          items: batches.map((b) => DropdownMenuItem(value: b['id'], child: Text(b['name']!))).toList(),
                          onChanged: (v) => setState(() => _batchId = v),
                        );
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _platform,
                      decoration: const InputDecoration(labelText: 'Platform'),
                      items: const [
                        DropdownMenuItem(value: 'LEETCODE', child: Text('LeetCode')),
                        DropdownMenuItem(value: 'HACKERRANK', child: Text('HackerRank')),
                        DropdownMenuItem(value: 'CODEFORCES', child: Text('CodeForces')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _platform = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: TextField(controller: _url, decoration: const InputDecoration(labelText: 'Problem URL'))),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _difficulty,
                      decoration: const InputDecoration(labelText: 'Difficulty'),
                      items: const [
                        DropdownMenuItem(value: 'EASY', child: Text('Easy')),
                        DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                        DropdownMenuItem(value: 'HARD', child: Text('Hard')),
                      ],
                      onChanged: (v) => setState(() => _difficulty = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: '3',
                      decoration: const InputDecoration(labelText: 'Deadline (Days from now)'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _days = int.tryParse(v) ?? 3,
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _createTask,
                    icon: _loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                    label: const Text('Create & Assign to Selected Batch'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Assigned Tasks Overview', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 12),
          tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(e),
            data: (list) => list.isEmpty
                ? const AppCard(
                    child: EmptyState(
                      title: '0 tasks currently assigned',
                      message: 'All previous tasks were cleared. Use Bulk Assign Problems above to assign coding problems.',
                    ),
                  )
                : AppCard(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final t = list[i];
                        return ListTile(
                          title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${t.platform} • ${t.topic} • Due ${fmtDate(t.deadline)}'),
                          trailing: StatusChip(t.difficulty),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
