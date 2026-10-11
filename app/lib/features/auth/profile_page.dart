import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/providers.dart';

final _strong = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,72}$');

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final student = ref.watch(myStudentProfileProvider).valueOrNull;
    final mentor = ref.watch(myMentorProfileProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(k, style: const TextStyle(color: Colors.black54)),
            Flexible(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700), textAlign: TextAlign.end)),
          ]),
        );
    return PageBody(
      title: 'My Profile',
      subtitle: 'Your university account details, POTD milestones, and security settings',
      child: LayoutBuilder(builder: (context, c) {
        final details = AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            row('Name', user.name),
            const Divider(),
            row('Email', user.email),
            const Divider(),
            row('Role', user.role.label),
            if (student != null) ...[
              const Divider(),
              row('Roll Number', student.studentCode),
              const Divider(),
              row('Batch & Branch', '${(student.batchName?.isNotEmpty ?? false) ? student.batchName! : student.batchId} • ${student.branch ?? "CSE"}'),
              const Divider(),
              row('Assigned Mentor', '${student.mentorName ?? "Assigned"} (${student.mentorCode ?? ""})'),
              const Divider(),
              row('Problem of the Day (POTD) Count', '${student.potdCount} Solved 🔥'),
              const Divider(),
              row('Current Milestone Rank', '🏆 ${student.milestone}'),
            ],
            if (mentor != null) ...[
              const Divider(),
              row('Mentor Roll Number', mentor.mentorCode),
              const Divider(),
              row('Batch', (mentor.batchName?.isNotEmpty ?? false) ? mentor.batchName! : (mentor.batchId ?? "")),
              const Divider(),
              row('Assigned Mentees', '${mentor.studentCount} Juniors'),
            ],
          ]),
        );
        const change = ChangePasswordCard();
        return c.maxWidth > 800
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: details), const SizedBox(width: 20), const Expanded(child: change)])
            : Column(children: [details, const SizedBox(height: 20), change]);
      }),
    );
  }
}

class ChangePasswordCard extends ConsumerStatefulWidget {
  const ChangePasswordCard({super.key});

  @override
  ConsumerState<ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends ConsumerState<ChangePasswordCard> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final user = ref.read(authProvider).currentUser!;
      // Re-authenticate with the current password, then update it with the Firebase Auth SDK.
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: _current.text));
      await user.updatePassword(_next.text);
      await ref.read(apiProvider).markPasswordChanged(); // clears the "temporary password" flag
      if (!mounted) return;
      showSnack(context, 'Password changed successfully');
      _form.currentState!.reset();
      _current.clear();
      _next.clear();
      _confirm.clear();
    } on FirebaseAuthException catch (e) {
      final msg = (e.code == 'wrong-password' || e.code == 'invalid-credential') ? 'Current password is incorrect' : (e.message ?? 'Could not change password');
      if (mounted) showSnack(context, msg, error: true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Change password', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextFormField(controller: _current, obscureText: true, decoration: const InputDecoration(labelText: 'Current password'), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(
            controller: _next,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password', helperText: 'At least 8 characters with upper-case, lower-case and a number'),
            validator: (v) => (v == null || !_strong.hasMatch(v)) ? 'Password is too weak' : (v == _current.text ? 'Must differ from current password' : null),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password'), validator: (v) => v != _next.text ? 'Passwords do not match' : null),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Update password')),
        ]),
      ),
    );
  }
}
