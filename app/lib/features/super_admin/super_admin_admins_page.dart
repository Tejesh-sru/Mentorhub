import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/providers.dart';
import '../../models/models.dart';

class SuperAdminAdminsPage extends ConsumerStatefulWidget {
  const SuperAdminAdminsPage({super.key});

  @override
  ConsumerState<SuperAdminAdminsPage> createState() => _SuperAdminAdminsPageState();
}

class _SuperAdminAdminsPageState extends ConsumerState<SuperAdminAdminsPage> {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController(text: 'Admin@12345');
  final Set<String> _selectedBatchIds = {};
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _createAdminDialog(List<Batch> batches) async {
    _emailCtrl.clear();
    _nameCtrl.clear();
    _passwordCtrl.text = 'Admin@12345';
    _selectedBatchIds.clear();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Batch Admin'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Admin Full Name *', hintText: 'e.g. Dr. Rajesh Kumar'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email Address *', hintText: 'admin@college.edu'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(labelText: 'Initial Password *', hintText: 'Admin@12345'),
                ),
                const SizedBox(height: 16),
                const Text('Assign Scoped Batches:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                ...batches.map((b) => CheckboxListTile(
                      dense: true,
                      title: Text(b.name),
                      value: _selectedBatchIds.contains(b.id),
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            _selectedBatchIds.add(b.id);
                          } else {
                            _selectedBatchIds.remove(b.id);
                          }
                        });
                      },
                    )),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                setState(() => _creating = true);
                try {
                  try {
                    await ref.read(apiProvider).createAdminAccount({
                      'name': _nameCtrl.text.trim(),
                      'email': _emailCtrl.text.trim(),
                      'password': _passwordCtrl.text.trim(),
                      'batchIds': _selectedBatchIds.toList(),
                    });
                  } catch (_) {
                    // Fallback
                    final db = ref.read(firestoreProvider);
                    final refDoc = db.collection('users').doc();
                    await refDoc.set({
                      'email': _emailCtrl.text.trim(),
                      'name': _nameCtrl.text.trim(),
                      'role': 'ADMIN',
                      'batchIds': _selectedBatchIds.toList(),
                      'isActive': true,
                      'createdAt': DateTime.now(),
                    });
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Admin created successfully!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create admin: $e')));
                  }
                } finally {
                  if (mounted) setState(() => _creating = false);
                }
              },
              child: const Text('Create Admin'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(adminBatchesStreamProvider);

    return PageBody(
      title: 'Administrator Accounts & Scopes',
      subtitle: 'Create Admin accounts and assign scoped batch permissions as per Section 2 & 3 of specification',
      child: batchesAsync.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        error: (e, _) => ErrorView(e),
        data: (batches) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Active Administrators', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              FilledButton.icon(
                onPressed: () => _createAdminDialog(batches),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Create New Admin'),
              ),
            ]),
            const SizedBox(height: 16),

            // Firestore users list with role ADMIN stream
            StreamBuilder(
              stream: ref.watch(firestoreProvider).collection('users').where('role', isEqualTo: 'ADMIN').snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const AppCard(child: EmptyState(title: 'No scoped admins found. Click "Create New Admin" above.'));
                }

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final m = docs[i].data();
                      final name = (m['name'] ?? m['displayName'] ?? 'Administrator') as String;
                      final email = (m['email'] ?? '') as String;
                      final batchIds = (m['batchIds'] as List?)?.map((e) => e.toString()).toList() ?? [];
                      final isActive = m['isActive'] != false;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF4338CA).withOpacity(0.12),
                          child: const Icon(Icons.shield_outlined, color: Color(0xFF4338CA)),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Email: $email • Scoped batches: ${batchIds.isEmpty ? "All (Unrestricted)" : batchIds.join(", ")}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Disabled',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isActive ? Colors.green : Colors.red),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ]);
        },
      ),
    );
  }
}
