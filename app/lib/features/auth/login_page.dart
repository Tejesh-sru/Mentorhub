import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sru_branding.dart';
import '../../data/providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String _selectedRole = 'admin';

  @override
  void initState() {
    super.initState();
    final port = Uri.base.port;
    if (port == 50002) {
      _selectRole('mentor', '2303a51408@mentorhub.dev', 'Mentor@12345');
    } else if (port == 50003) {
      _selectRole('student', '2403a51282@mentorhub.dev', 'Student@12345');
    } else {
      _selectRole('admin', 'admin@mentorhub.dev', 'Admin@12345');
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return 'Invalid enrolment number or password';
      case 'user-disabled':
        return 'This university account has been deactivated';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Cannot reach SRU server. Check your connection.';
      default:
        return e.message ?? 'Login failed';
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider).signInWithEmailAndPassword(
            email: _email.text.trim(),
            password: _password.text,
          );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectRole(String role, String email, String pwd) {
    setState(() {
      _selectedRole = role;
      _email.text = email;
      _password.text = pwd;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 920;

    if (isDesktop) {
      // ── Desktop 50/50 Split Layout Matching Screenshot ──
      return Scaffold(
        body: Row(
          children: [
            // Left Half: Primary University Blue Panel (#274985)
            Expanded(
              flex: 1,
              child: Container(
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [SruColors.primary, SruColors.primaryHover],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Logo
                    const SruLogo(
                      isLight: true,
                      fontSize: 28,
                      subtitle: 'CAMPUS CONNECT • CSSP PORTAL',
                    ),
                    const SizedBox(height: 52),

                    // Hero Headline matching reference
                    const Text(
                      'Your campus community,\nall in one place.',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.25,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Subtitle
                    Text(
                      'Chat with mentors, stay updated on announcements, and collaborate — all within your program portal.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.85),
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Outlined Checkpoint Bullets
                    _buildBulletItem(Icons.chat_bubble_outline_rounded, 'Real-time peer & mentor interaction'),
                    const SizedBox(height: 16),
                    _buildBulletItem(Icons.campaign_outlined, 'Program announcements & coding milestones'),
                    const SizedBox(height: 16),
                    _buildBulletItem(Icons.verified_user_outlined, 'Secure student-only verified reviews'),
                  ],
                ),
              ),
            ),

            // Right Half: Crisp White Form Panel
            Expanded(
              flex: 1,
              child: Container(
                height: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _buildFormContent(),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Mobile / Tablet Responsive Stacked Layout ──
    return Scaffold(
      backgroundColor: SruColors.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Top Banner
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SruLogo(
                      isLight: true,
                      fontSize: 24,
                      subtitle: 'CAMPUS CONNECT • CSSP PORTAL',
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Your campus community,\nall in one place.',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.25,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connect with mentors, track LeetCode milestones, and prepare for interviews.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              // White Content Card with 28px border radius
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _buildFormContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulletItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: Colors.white.withOpacity(0.9)),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section Heading matching screenshot
          const Text(
            'Welcome back',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: SruColors.textPrimary,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sign in to your student portal',
            style: TextStyle(
              fontSize: 14,
              color: SruColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // Role Switcher Pills (connected to full live database)
          Row(
            children: [
              Expanded(
                child: _buildRoleSelector(
                  id: 'admin',
                  label: 'Admin',
                  icon: Icons.shield_outlined,
                  email: 'admin@mentorhub.dev',
                  pwd: 'Admin@12345',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRoleSelector(
                  id: 'mentor',
                  label: 'Mentor',
                  icon: Icons.engineering_outlined,
                  email: '2303a51408@mentorhub.dev',
                  pwd: 'Mentor@12345',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRoleSelector(
                  id: 'student',
                  label: 'Mentee',
                  icon: Icons.school_outlined,
                  email: '2403a51282@mentorhub.dev',
                  pwd: 'Student@12345',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dataset Status Information Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: SruColors.surfaceBlue.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SruColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.dataset_outlined, size: 15, color: SruColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedRole == 'admin'
                        ? 'Super Admin • Full access to 496 students, 42 mentors & 4 batches'
                        : _selectedRole == 'mentor'
                            ? 'Senior Mentor (Charanvitha • G6-B1) • 12 active mentees assigned'
                            : 'Junior Mentee (Siri Chandana • G6-B1) • POTD, Tasks & Milestones',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: SruColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Error alert
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Email Field Label
          const Text(
            'Email',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: SruColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'student@university.edu',
              fillColor: SruColors.surfaceBlue, // Pale-blue input background (#DCE7F7)
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: SruColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: SruColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: SruColors.primary, width: 2),
              ),
            ),
            validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid university email' : null,
          ),
          const SizedBox(height: 20),

          // Password Field Label
          const Text(
            'Password',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: SruColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              hintText: '••••••••',
              fillColor: SruColors.surfaceBlue, // Pale-blue input background (#DCE7F7)
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: SruColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: SruColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: SruColors.primary, width: 2),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                  color: const Color(0xFF6B7280),
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
          ),
          const SizedBox(height: 26),

          // Full-width Primary Blue Button matching reference (#274985)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SruColors.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0x30274985),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Sign in',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Footer Link matching reference
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Don't have an account? ",
                  style: TextStyle(fontSize: 13, color: SruColors.textSecondary),
                ),
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Student accounts are provisioned by university CSE administration.'),
                      ),
                    );
                  },
                  child: const Text(
                    'Sign up',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SruColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector({
    required String id,
    required String label,
    required IconData icon,
    required String email,
    required String pwd,
  }) {
    final isSelected = _selectedRole == id;
    return InkWell(
      onTap: () => _selectRole(id, email, pwd),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? SruColors.surfaceBlue : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? SruColors.primary : SruColors.border,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? SruColors.primary : SruColors.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? SruColors.primary : SruColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
