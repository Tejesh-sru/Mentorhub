import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/providers.dart';
import '../../models/cssp_models.dart';
import '../../models/models.dart';

class AdminWeeklySchedulePage extends ConsumerStatefulWidget {
  const AdminWeeklySchedulePage({super.key});

  @override
  ConsumerState<AdminWeeklySchedulePage> createState() => _AdminWeeklySchedulePageState();
}

class _AdminWeeklySchedulePageState extends ConsumerState<AdminWeeklySchedulePage> {
  String? _selectedBatchId;
  final Map<String, TextEditingController> _targetControllers = {};
  final Map<String, DateTime> _weekStartDates = {};
  bool _saving = false;
  String? _message;

  @override
  void dispose() {
    for (final c in _targetControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initControllers(List<WeekConfig> weeks) {
    for (final w in weeks) {
      if (!_targetControllers.containsKey(w.weekId)) {
        _targetControllers[w.weekId] = TextEditingController(text: '${w.targetCumulative}');
        _weekStartDates[w.weekId] = w.startsAt;
      }
    }
  }

  Future<void> _pickDate(String weekId) async {
    final current = _weekStartDates[weekId] ?? DateTime(2026, 10, 5);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() => _weekStartDates[weekId] = picked);
    }
  }

  Future<void> _saveSchedule(String batchId, List<WeekConfig> weeks) async {
    setState(() {
      _saving = true;
      _message = null;
    });

    final updatedWeeks = weeks.map((w) {
      final target = int.tryParse(_targetControllers[w.weekId]?.text.trim() ?? '') ?? w.targetCumulative;
      final startDate = _weekStartDates[w.weekId] ?? w.startsAt;
      return {
        'weekId': w.weekId,
        'label': w.label,
        'order': w.order,
        'targetCumulative': target,
        'startsAt': startDate.toIso8601String(),
      };
    }).toList();

    try {
      try {
        await ref.read(apiProvider).updateWeeklyConfig({
          'batchId': batchId,
          'weeks': updatedWeeks,
        });
      } catch (_) {
        // Direct Firestore fallback
        final db = ref.read(firestoreProvider);
        final batch = db.batch();
        for (final w in updatedWeeks) {
          final refDoc = db.collection('weeks').doc('${batchId}_${w['weekId']}');
          batch.set(refDoc, {
            'batchId': batchId,
            'weekId': w['weekId'],
            'label': w['label'],
            'order': w['order'],
            'targetCumulative': w['targetCumulative'],
            'startsAt': DateTime.parse(w['startsAt'] as String),
            'updatedAt': DateTime.now(),
          }, SetOptions(merge: true));
        }
        await batch.commit();
      }

      if (mounted) {
        setState(() => _message = 'Successfully updated 12-week schedule and targets for batch!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weekly schedule & targets saved!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      setState(() => _message = 'Error saving schedule: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(adminBatchesStreamProvider);

    return PageBody(
      title: 'Weekly Schedule & Targets',
      subtitle: 'Configure 12-week schedule dates and cumulative LeetCode targets for assigned batches',
      child: batchesAsync.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        error: (e, _) => ErrorView(e),
        data: (batches) {
          if (batches.isEmpty) return const AppCard(child: EmptyState(title: 'No batches found'));

          _selectedBatchId ??= batches.first.id;
          final currentBatchId = _selectedBatchId!;

          final weeksAsync = ref.watch(csspWeeksProvider(currentBatchId));

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Batch Selector & Info ──
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                const Icon(Icons.school_outlined, color: Color(0xFF4F46E5), size: 24),
                const SizedBox(width: 14),
                const Text('Select Batch:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 14),
                DropdownButton<String>(
                  value: currentBatchId,
                  items: batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedBatchId = val;
                        _targetControllers.clear();
                        _weekStartDates.clear();
                        _message = null;
                      });
                    }
                  },
                ),
              ]),
            ),
            const SizedBox(height: 18),

            if (_message != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _message!.contains('Error') ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _message!,
                  style: TextStyle(color: _message!.contains('Error') ? Colors.red.shade800 : Colors.green.shade800),
                ),
              ),

            weeksAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
              error: (e, _) => ErrorView(e),
              data: (weeks) {
                _initControllers(weeks);

                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('12-Week Targets & Schedule Matrix',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _saveSchedule(currentBatchId, weeks),
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(_saving ? 'Saving...' : 'Save All Changes'),
                    ),
                  ]),
                  const SizedBox(height: 14),

                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.2),
                          1: FlexColumnWidth(2.0),
                          2: FlexColumnWidth(2.2),
                          3: FlexColumnWidth(1.4),
                        },
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          const TableRow(
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
                            children: [
                              Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Week', style: TextStyle(fontWeight: FontWeight.bold))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Cumulative Target', style: TextStyle(fontWeight: FontWeight.bold))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                          ),
                          ...weeks.map((w) {
                            final ctrl = _targetControllers[w.weekId];
                            final startDate = _weekStartDates[w.weekId] ?? w.startsAt;

                            return TableRow(
                              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Text(w.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Text(Format.date(startDate)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                  child: SizedBox(
                                    height: 40,
                                    child: TextField(
                                      controller: ctrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        suffixText: 'problems',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: TextButton.icon(
                                    icon: const Icon(Icons.edit_calendar, size: 16),
                                    label: const Text('Date', style: TextStyle(fontSize: 12)),
                                    onPressed: () => _pickDate(w.weekId),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ]);
              },
            ),
          ]);
        },
      ),
    );
  }
}
