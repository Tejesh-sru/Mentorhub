import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/providers.dart';
import '../../models/cssp_models.dart';

class StudentLinksPage extends ConsumerStatefulWidget {
  const StudentLinksPage({super.key});

  @override
  ConsumerState<StudentLinksPage> createState() => _StudentLinksPageState();
}

class _StudentLinksPageState extends ConsumerState<StudentLinksPage> {
  final _formKey = GlobalKey<FormState>();
  final _leetcode = TextEditingController();
  final _codeforces = TextEditingController();
  final _hackerrank = TextEditingController();
  final _linkedin = TextEditingController();
  final _github = TextEditingController();
  final _resume = TextEditingController();
  final _phone = TextEditingController();

  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _leetcode.dispose();
    _codeforces.dispose();
    _hackerrank.dispose();
    _linkedin.dispose();
    _github.dispose();
    _resume.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _loadFromProfile(dynamic p) {
    if (_loaded || p == null) return;
    _leetcode.text = p.leetcode ?? '';
    _codeforces.text = p.codeforce ?? '';
    _hackerrank.text = p.hackerrank ?? '';
    _linkedin.text = p.linkedin ?? '';
    _github.text = p.github ?? '';
    _resume.text = p.resume ?? '';
    _phone.text = p.phone ?? '';
    _loaded = true;
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open: $url')));
      }
    }
  }

  Future<void> _saveLinks() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    final payload = {
      'leetcodeUrl': _leetcode.text.trim().isEmpty ? null : _leetcode.text.trim(),
      'codeforcesUrl': _codeforces.text.trim().isEmpty ? null : _codeforces.text.trim(),
      'hackerRankUrl': _hackerrank.text.trim().isEmpty ? null : _hackerrank.text.trim(),
      'linkedInUrl': _linkedin.text.trim().isEmpty ? null : _linkedin.text.trim(),
      'gitHubUrl': _github.text.trim().isEmpty ? null : _github.text.trim(),
      'resumeUrl': _resume.text.trim().isEmpty ? null : _resume.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
    };

    try {
      try {
        await ref.read(apiProvider).updateProfileLinks(payload);
      } catch (_) {
        // Direct Firestore fallback
        final updateData = {
          'leetcode': payload['leetcodeUrl'],
          'codeforce': payload['codeforcesUrl'],
          'hackerrank': payload['hackerRankUrl'],
          'linkedin': payload['linkedInUrl'],
          'github': payload['gitHubUrl'],
          'resume': payload['resumeUrl'],
          'phone': payload['phone'],
          'updatedAt': DateTime.now(),
        };
        final db = ref.read(firestoreProvider);
        await db.collection('students').doc(user.uid).set(updateData, SetOptions(merge: true));
        await db.collection('profiles').doc(user.uid).set(updateData, SetOptions(merge: true));
      }

      ref.invalidate(myStudentProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Portfolio & profile links saved!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      setState(() => _error = 'Failed to save links: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateUrl(String? v, String name) {
    if (v == null || v.trim().isEmpty) return null; // optional
    if (!ProfileLinksHelper.isValidUrl(v)) {
      return '$name must be a valid URL starting with http:// or https://';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myStudentProfileProvider);

    return PageBody(
      title: 'Profile & Portfolio Links',
      subtitle: 'Provide your 6 validated portfolio links for mentor verification and placement records',
      child: profileAsync.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        error: (e, _) => ErrorView(e),
        data: (profile) {
          _loadFromProfile(profile);

          final validCount = ProfileLinksHelper.validCount(
            leetcode: _leetcode.text,
            codeforce: _codeforces.text,
            hackerrank: _hackerrank.text,
            linkedin: _linkedin.text,
            github: _github.text,
            resume: _resume.text,
          );

          final missing = ProfileLinksHelper.missingLinks(
            leetcode: _leetcode.text,
            codeforce: _codeforces.text,
            hackerrank: _hackerrank.text,
            linkedin: _linkedin.text,
            github: _github.text,
            resume: _resume.text,
          );

          return Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Summary Header ──
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: validCount == 6 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    child: Text('$validCount/6', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        validCount == 6 ? 'All 6 Links Complete 🎉' : '$validCount of 6 Links Provided',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        missing.isEmpty
                            ? 'All portfolio profiles and resume are validly configured.'
                            : 'Missing or unverified: ${missing.join(', ')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: missing.isEmpty ? Colors.green.shade800 : Colors.brown.shade800,
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 20),

              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                ),

              // ── 6 Links Input Fields ──
              _LinkInputField(
                controller: _leetcode,
                title: 'LeetCode Profile URL',
                hintText: 'https://leetcode.com/u/your_handle/',
                icon: Icons.code,
                brandColor: const Color(0xFFFFA116),
                validator: (v) => _validateUrl(v, 'LeetCode'),
                onOpen: () => _openLink(_leetcode.text),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              _LinkInputField(
                controller: _codeforces,
                title: 'Codeforces Profile URL',
                hintText: 'https://codeforces.com/profile/your_handle',
                icon: Icons.military_tech_outlined,
                brandColor: const Color(0xFF1877F2),
                validator: (v) => _validateUrl(v, 'Codeforces'),
                onOpen: () => _openLink(_codeforces.text),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              _LinkInputField(
                controller: _hackerrank,
                title: 'HackerRank Profile URL',
                hintText: 'https://www.hackerrank.com/profile/your_handle',
                icon: Icons.terminal_rounded,
                brandColor: const Color(0xFF2EC866),
                validator: (v) => _validateUrl(v, 'HackerRank'),
                onOpen: () => _openLink(_hackerrank.text),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              _LinkInputField(
                controller: _linkedin,
                title: 'LinkedIn Profile URL',
                hintText: 'https://www.linkedin.com/in/your_name/',
                icon: Icons.work_outline_rounded,
                brandColor: const Color(0xFF0A66C2),
                validator: (v) => _validateUrl(v, 'LinkedIn'),
                onOpen: () => _openLink(_linkedin.text),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              _LinkInputField(
                controller: _github,
                title: 'GitHub Profile URL',
                hintText: 'https://github.com/your_handle',
                icon: Icons.folder_shared_outlined,
                brandColor: const Color(0xFF24292E),
                validator: (v) => _validateUrl(v, 'GitHub'),
                onOpen: () => _openLink(_github.text),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              _LinkInputField(
                controller: _resume,
                title: 'Résumé URL (PDF Link)',
                hintText: 'https://sraap.in/resume/... or Drive PDF link',
                icon: Icons.description_outlined,
                brandColor: const Color(0xFFEA4335),
                validator: (v) => _validateUrl(v, 'Résumé'),
                onOpen: () => _openLink(_resume.text),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Contact Phone Number (Optional)',
                  hintText: 'e.g. +91 9876543210',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveLinks,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving...' : 'Save Profile Links'),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _LinkInputField extends StatelessWidget {
  const _LinkInputField({
    required this.controller,
    required this.title,
    required this.hintText,
    required this.icon,
    required this.brandColor,
    required this.validator,
    required this.onOpen,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String title, hintText;
  final IconData icon;
  final Color brandColor;
  final String? Function(String?) validator;
  final VoidCallback onOpen;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    final isValid = ProfileLinksHelper.isValidUrl(controller.text);

    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.url,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: title,
        hintText: hintText,
        prefixIcon: Icon(icon, color: brandColor),
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (hasText)
            IconButton(
              tooltip: 'Open Link',
              icon: const Icon(Icons.open_in_new, size: 18),
              onPressed: onOpen,
            ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Icon(
              isValid ? Icons.check_circle : (hasText ? Icons.error_outline : Icons.circle_outlined),
              size: 16,
              color: isValid ? Colors.green : (hasText ? Colors.red : Colors.grey),
            ),
          ),
        ]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
