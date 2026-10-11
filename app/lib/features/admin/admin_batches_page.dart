import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';

class AdminBatchesPage extends ConsumerWidget {
  const AdminBatchesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(adminBatchesStreamProvider);
    return PageBody(
      title: 'Batches',
      subtitle: 'Manage programme batches',
      actions: [
        FilledButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New Batch'),
          onPressed: () => showDialog(context: context, builder: (_) => const _BatchDialog()),
        ),
        const SizedBox(width: 8),
        IconButton(tooltip: 'Refresh', onPressed: () => ref.invalidate(adminBatchesStreamProvider), icon: const Icon(Icons.refresh)),
      ],
      child: batches.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(adminBatchesStreamProvider)),
        data: (list) => list.isEmpty
            ? const AppCard(child: EmptyState(title: 'No batches yet', message: 'Create the first batch to get started.'))
            : AppCard(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final b = list[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      leading: CircleAvatar(
                        backgroundColor: b.isActive ? const Color(0xFF4F46E5) : Colors.grey.shade300,
                        foregroundColor: Colors.white,
                        child: Text(b.name.isEmpty ? '?' : b.name[0].toUpperCase()),
                      ),
                      title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      subtitle: Text('${b.academicYear} • ${fmtDate(b.startDate)} – ${fmtDate(b.endDate)}'),
                      trailing: Chip(
                        label: Text(b.isActive ? 'Active' : 'Inactive'),
                        backgroundColor: b.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                        labelStyle: TextStyle(color: b.isActive ? const Color(0xFF15803D) : Colors.black54, fontWeight: FontWeight.w600),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _BatchDialog extends ConsumerStatefulWidget {
  const _BatchDialog();

  @override
  ConsumerState<_BatchDialog> createState() => _BatchDialogState();
}

class _BatchDialogState extends ConsumerState<_BatchDialog> {
  final _name = TextEditingController();
  final _year = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 180));
  bool _loading = false;
  String? _error;

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => isStart ? _startDate = picked : _endDate = picked);
  }

  Future<void> _submit() async {
    if (_name.text.trim().length < 3) {
      setState(() => _error = 'Batch name must be at least 3 characters');
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      setState(() => _error = 'End date must be after start date');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(firestoreProvider).collection('batches').add({
        'name': _name.text.trim(),
        'academicYear': _year.text.trim(),
        'startDate': Timestamp.fromDate(_startDate),
        'endDate': Timestamp.fromDate(_endDate),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'Batch created!');
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Batch'),
      content: SizedBox(
        width: 480,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Batch Name')),
          const SizedBox(height: 12),
          TextField(controller: _year, decoration: const InputDecoration(labelText: 'Academic Year (e.g. 2024-25)')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text('Start: ${fmtDate(_startDate)}'),
                onPressed: () => _pickDate(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text('End: ${fmtDate(_endDate)}'),
                onPressed: () => _pickDate(false),
              ),
            ),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create')),
      ],
    );
  }
}
