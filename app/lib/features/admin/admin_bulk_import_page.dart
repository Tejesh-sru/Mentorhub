import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/providers.dart';
import '../../models/cssp_models.dart';
import '../../models/models.dart';

class AdminBulkImportPage extends ConsumerStatefulWidget {
  const AdminBulkImportPage({super.key});

  @override
  ConsumerState<AdminBulkImportPage> createState() => _AdminBulkImportPageState();
}

class _AdminBulkImportPageState extends ConsumerState<AdminBulkImportPage> {
  String? _selectedBatchId;
  final _csvTextCtrl = TextEditingController();

  List<Map<String, dynamic>> _parsedRows = [];
  List<Map<String, dynamic>> _validRows = [];
  List<Map<String, dynamic>> _errorRows = [];
  bool _previewReady = false;
  bool _importing = false;
  Map<String, dynamic>? _importResult;

  @override
  void dispose() {
    _csvTextCtrl.dispose();
    super.dispose();
  }

  void _parseAndValidate(List<Batch> batches) {
    final raw = _csvTextCtrl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please paste CSV data first.')));
      return;
    }

    try {
      final rows = const CsvToListConverter(shouldParseNumbers: false, eol: '\n').convert(raw.replaceAll('\r\n', '\n'));
      if (rows.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV must include header row and data rows.')));
        return;
      }

      final header = rows[0].map((e) => e.toString().trim().toLowerCase()).toList();

      // Find indices
      int idxOf(List<String> candidates) {
        for (final c in candidates) {
          final idx = header.indexOf(c.toLowerCase());
          if (idx != -1) return idx;
        }
        return -1;
      }

      final rollIdx = idxOf(['roll no', 'rollno', 'student code', 'roll']);
      final nameIdx = idxOf(['student name', 'name', 'studentname']);
      final branchIdx = idxOf(['branch', 'dept']);
      final batchIdx = idxOf(['batch', 'nbatch']);
      final mentorRollIdx = idxOf(['mentor roll no', 'mentorrollno', 'mentor roll', 'mentor code']);
      final mentorNameIdx = idxOf(['mentor name', 'mentorname']);
      final leetcodeIdx = idxOf(['leetcode', 'leetcode url']);
      final codeforceIdx = idxOf(['codeforce', 'codeforces']);
      final hackerrankIdx = idxOf(['hackerrank']);
      final linkedinIdx = idxOf(['linkedin']);
      final githubIdx = idxOf(['github']);
      final resumeIdx = idxOf(['resume', 'cv']);

      if (rollIdx == -1 || nameIdx == -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find required columns "Roll No" and "Student Name" in header.')),
        );
        return;
      }

      final parsed = <Map<String, dynamic>>[];
      final valid = <Map<String, dynamic>>[];
      final errors = <Map<String, dynamic>>[];
      final seenRolls = <String>{};

      for (int i = 1; i < rows.length; i++) {
        final r = rows[i];
        if (r.isEmpty || (r.length == 1 && r[0].toString().trim().isEmpty)) continue;

        String valAt(int idx) => idx != -1 && idx < r.length ? r[idx].toString().trim() : '';

        final rollNo = valAt(rollIdx);
        final name = valAt(nameIdx);
        final branch = valAt(branchIdx);
        final batch = valAt(batchIdx);
        final mentorRoll = valAt(mentorRollIdx);
        final mentorName = valAt(mentorNameIdx);
        final leetcode = valAt(leetcodeIdx);
        final codeforce = valAt(codeforceIdx);
        final hackerrank = valAt(hackerrankIdx);
        final linkedin = valAt(linkedinIdx);
        final github = valAt(githubIdx);
        final resume = valAt(resumeIdx);

        final item = {
          'rowNumber': i + 1,
          'rollNo': rollNo,
          'name': name,
          'branch': branch,
          'batch': batch,
          'mentorRoll': mentorRoll,
          'mentorName': mentorName,
          'leetcode': leetcode,
          'codeforce': codeforce,
          'hackerrank': hackerrank,
          'linkedin': linkedin,
          'github': github,
          'resume': resume,
        };
        parsed.add(item);

        if (rollNo.isEmpty) {
          errors.add({...item, 'error': 'Missing Roll Number'});
        } else if (name.isEmpty) {
          errors.add({...item, 'error': 'Missing Student Name'});
        } else if (seenRolls.contains(rollNo.toUpperCase())) {
          errors.add({...item, 'error': 'Duplicate Roll No in import data: $rollNo'});
        } else {
          seenRolls.add(rollNo.toUpperCase());
          valid.add(item);
        }
      }

      setState(() {
        _parsedRows = parsed;
        _validRows = valid;
        _errorRows = errors;
        _previewReady = true;
        _importResult = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV Parsing failed: $e')));
    }
  }

  Future<void> _commitImport(String batchId) async {
    if (_validRows.isEmpty) return;

    setState(() {
      _importing = true;
      _importResult = null;
    });

    try {
      final payload = {
        'batchId': batchId,
        'records': _validRows,
        'fileName': 'bulk_import_${DateTime.now().millisecondsSinceEpoch}.csv',
      };

      Map<String, dynamic> res;
      try {
        res = await ref.read(apiProvider).bulkImportStudentsCssp(payload);
      } catch (_) {
        // Fallback non-destructive client import
        final db = ref.read(firestoreProvider);
        int updated = 0;
        int imported = 0;
        for (final row in _validRows) {
          final rollNo = row['rollNo'] as String;
          final existingSnap = await db.collection('students').where('studentCode', isEqualTo: rollNo).limit(1).get();
          if (existingSnap.docs.isNotEmpty) {
            await existingSnap.docs.first.reference.set({
              'name': row['name'],
              'branch': row['branch'],
              'leetcode': row['leetcode'].isNotEmpty ? row['leetcode'] : null,
              'codeforce': row['codeforce'].isNotEmpty ? row['codeforce'] : null,
              'hackerrank': row['hackerrank'].isNotEmpty ? row['hackerrank'] : null,
              'linkedin': row['linkedin'].isNotEmpty ? row['linkedin'] : null,
              'github': row['github'].isNotEmpty ? row['github'] : null,
              'resume': row['resume'].isNotEmpty ? row['resume'] : null,
              'updatedAt': DateTime.now(),
            }, SetOptions(merge: true));
            updated++;
          } else {
            final docRef = db.collection('students').doc();
            await docRef.set({
              'studentCode': rollNo,
              'name': row['name'],
              'email': '${rollNo.toLowerCase()}@mentorhub.dev',
              'batchId': batchId,
              'mentorId': null,
              'branch': row['branch'],
              'leetcode': row['leetcode'].isNotEmpty ? row['leetcode'] : null,
              'codeforce': row['codeforce'].isNotEmpty ? row['codeforce'] : null,
              'hackerrank': row['hackerrank'].isNotEmpty ? row['hackerrank'] : null,
              'linkedin': row['linkedin'].isNotEmpty ? row['linkedin'] : null,
              'github': row['github'].isNotEmpty ? row['github'] : null,
              'resume': row['resume'].isNotEmpty ? row['resume'] : null,
              'stats': {'ASSIGNED': 0, 'IN_PROGRESS': 0, 'SUBMITTED': 0, 'APPROVED': 0, 'NEEDS_CHANGES': 0, 'OVERDUE': 0},
              'createdAt': DateTime.now(),
            });
            imported++;
          }
        }
        res = {'imported': imported, 'updated': updated, 'errors': []};
      }

      ref.invalidate(adminStudentsProvider);

      setState(() {
        _importResult = res;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import complete! Added ${res["imported"] ?? 0}, Updated ${res["updated"] ?? 0} records.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _loadSampleTemplate() {
    _csvTextCtrl.text = '''Sl No,Roll No,Student Name,Branch,Nbatch,Mentor Roll No,Mentor Name,LeetCode,Codeforce,Hackerrank,Linkedin,Github,Resume
1,2403A51015,POODARI SRINATH,CSE,G6-B1,2303A51812,JAKKULA TEJESH,https://leetcode.com/u/3N2yGGVIjw/,https://codeforces.com/profile/Srinath08,https://www.hackerrank.com/profile/poodarisrinath08,https://www.linkedin.com/in/srinath-poodari-453455339/,https://github.com/SrinathPoodari08,https://sraap.in/resume/2403A51015_R.pdf
2,2403A51021,BOLLAM RAKESH,CSE,G6-B1,2303A51812,JAKKULA TEJESH,https://leetcode.com/BollamRakesh/,https://codeforces.com/profile/bollamrakesh27,https://www.hackerrank.com/bollamrakesh0,https://www.linkedin.com/in/bollam-rakesh-7b60a8325/,https://github.com/bollamrakesh0,https://sraap.in/resume/2403A51021_R.pdf
3,2403A51027,PUNNA SHIVA KARTHIKEYA,CSE,G6-B1,2303A51812,JAKKULA TEJESH,https://leetcode.com/u/xzTGChbJcr/,https://codeforces.com/profile/shivakarthikeyapunna,https://www.hackerrank.com/profile/shivakarthikeya6,https://www.linkedin.com/in/shiva-karthikeya-punna-720925379/,https://github.com/karthikeya12151,https://sraap.in/resume/2403A51027_R.pdf''';
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sample CSV template loaded! Click "Preview & Validate".')));
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(adminBatchesStreamProvider);

    return PageBody(
      title: 'Bulk Import (Template & Non-Destructive Upsert)',
      subtitle: 'Preview, validate, deduplicate, and import junior profiles without erasing past progress or remarks',
      child: batchesAsync.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        error: (e, _) => ErrorView(e),
        data: (batches) {
          if (batches.isEmpty) return const AppCard(child: EmptyState(title: 'No batches found'));

          _selectedBatchId ??= batches.first.id;
          final batchId = _selectedBatchId!;

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Batch selector & template actions ──
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                const Icon(Icons.file_upload_outlined, color: Color(0xFF4F46E5), size: 24),
                const SizedBox(width: 14),
                const Text('Target Batch:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 14),
                DropdownButton<String>(
                  value: batchId,
                  items: batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (v) => setState(() => _selectedBatchId = v),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _loadSampleTemplate,
                  icon: const Icon(Icons.code_rounded, size: 16),
                  label: const Text('Load Sample Template'),
                ),
              ]),
            ),
            const SizedBox(height: 18),

            // ── Paste CSV input ──
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Paste CSV / Excel Data (with Headers)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                const Text(
                  'Expected columns: Roll No, Student Name, Branch, Batch, Mentor Roll No, Mentor Name, LeetCode, Codeforce, Hackerrank, Linkedin, Github, Resume',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _csvTextCtrl,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: 'Paste CSV text here...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  FilledButton.icon(
                    onPressed: () => _parseAndValidate(batches),
                    icon: const Icon(Icons.remove_red_eye_outlined),
                    label: const Text('Preview & Validate Records'),
                  ),
                  const SizedBox(width: 12),
                  if (_previewReady)
                    FilledButton.tonalIcon(
                      onPressed: _importing || _validRows.isEmpty ? null : () => _commitImport(batchId),
                      icon: _importing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.cloud_upload_outlined),
                      label: Text(_importing ? 'Importing...' : 'Confirm & Commit ${_validRows.length} Rows'),
                    ),
                ]),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Import Result Banner ──
            if (_importResult != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Import Completed Successfully!\nAdded: ${_importResult!["imported"] ?? 0} new records • Updated: ${_importResult!["updated"] ?? 0} existing records (historic progress preserved).',
                      style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
            ],

            // ── Validation Preview Table ──
            if (_previewReady) ...[
              Row(children: [
                Text('Validation Summary: ${_validRows.length} Valid Rows, ${_errorRows.length} Errors',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
              const SizedBox(height: 12),

              if (_errorRows.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Validation Errors Found (${_errorRows.length})',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    ..._errorRows.take(5).map((e) => Text(
                          '• Row ${e["rowNumber"]}: ${e["error"]}',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                        )),
                    if (_errorRows.length > 5)
                      Text('...and ${_errorRows.length - 5} more errors.',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade900, fontStyle: FontStyle.italic)),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // Preview Table
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _validRows.take(15).length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final row = _validRows[idx];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.green.shade100,
                          child: const Icon(Icons.check, size: 14, color: Colors.green),
                        ),
                        title: Text('${row["name"]} (${row["rollNo"]})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Mentor: ${row["mentorName"].isNotEmpty ? row["mentorName"] : "None"} • Branch: ${row["branch"]}'),
                        trailing: Text(
                          row["leetcode"].isNotEmpty ? 'LeetCode ✓' : 'No LeetCode',
                          style: TextStyle(fontSize: 11, color: row["leetcode"].isNotEmpty ? Colors.green : Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ]);
        },
      ),
    );
  }
}
