import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../models/cssp_models.dart';

class SuperAdminAuditPage extends ConsumerStatefulWidget {
  const SuperAdminAuditPage({super.key});

  @override
  ConsumerState<SuperAdminAuditPage> createState() => _SuperAdminAuditPageState();
}

class _SuperAdminAuditPageState extends ConsumerState<SuperAdminAuditPage> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auditLogsAsync = ref.watch(csspAuditLogsProvider);
    final importsAsync = ref.watch(csspImportsProvider);

    return PageBody(
      title: 'Audit Trail & Bulk Import Logs',
      subtitle: 'Immutable system audit entries for score updates, role changes, bulk imports, and assignment reallocations',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF4F46E5),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFF4F46E5),
          tabs: const [
            Tab(icon: Icon(Icons.history_rounded, size: 20), text: 'Security Audit Logs'),
            Tab(icon: Icon(Icons.file_download_done_rounded, size: 20), text: 'Bulk Import History'),
          ],
        ),
        const SizedBox(height: 16),

        SizedBox(
          height: 600,
          child: TabBarView(
            controller: _tabs,
            children: [
              // ── Tab 1: Audit Logs ──
              auditLogsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorView(e),
                data: (logs) {
                  if (logs.isEmpty) {
                    return const AppCard(child: EmptyState(title: 'No audit log entries recorded yet'));
                  }

                  return ListView.separated(
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final l = logs[i];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  l.action,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4F46E5)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'By: ${l.actorRole ?? "User"} (${l.actorUid})',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                              const Spacer(),
                              Text(Format.date(l.timestamp), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ]),
                            const SizedBox(height: 8),
                            Text('Target: ${l.targetPath}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            if (l.changedFields.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  'Payload: ${l.changedFields}',
                                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black87),
                                ),
                              ),
                            ],
                          ]),
                        ),
                      );
                    },
                  );
                },
              ),

              // ── Tab 2: Imports History ──
              importsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorView(e),
                data: (imports) {
                  if (imports.isEmpty) {
                    return const AppCard(child: EmptyState(title: 'No bulk import sessions recorded yet'));
                  }

                  return ListView.separated(
                    itemCount: imports.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final imp = imports[i];
                      final status = (imp['status'] ?? 'COMPLETED') as String;
                      final totals = imp['totals'] ?? 0;
                      final imported = imp['imported'] ?? 0;
                      final updated = imp['updated'] ?? 0;
                      final fileName = (imp['fileName'] ?? 'import.csv') as String;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade50,
                            child: const Icon(Icons.table_chart_outlined, color: Colors.blue),
                          ),
                          title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Processed: $totals rows • Added: $imported, Updated: $updated'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'COMPLETED' ? Colors.green.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: status == 'COMPLETED' ? Colors.green : Colors.orange,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
