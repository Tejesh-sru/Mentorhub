import 'package:flutter/material.dart';

/// Official SR University Design System Tokens
class SruColors {
  // ── Core Design Tokens from Specification ──
  static const Color primary = Color(0xFF274985); // Primary university blue
  static const Color primaryHover = Color(0xFF1E3A70); // Hover blue
  static const Color surfaceBlue = Color(0xFFDCE7F7); // Light blue surfaces / inputs
  static const Color link = Color(0xFF1469F5); // Bright blue links and interactive accents
  static const Color surface = Color(0xFFFFFFFF); // White card backgrounds
  static const Color textPrimary = Color(0xFF111827); // Primary text
  static const Color textSecondary = Color(0xFF374151); // Secondary text
  static const Color border = Color(0xFFE5E7EB); // Borders and dividers
  static const Color hoverBlue = Color(0xFF1E3A70); // Hover blue

  // ── Aliases & Accents ──
  static const Color navy = Color(0xFF274985); // Primary university blue
  static const Color navyDark = Color(0xFF1E3A70); // Hover / Darker blue
  static const Color royal = Color(0xFF1469F5); // Interactive accent
  static const Color lightBlue = Color(0xFF274985);
  static const Color bluePrimary = Color(0xFF274985);
  static const Color blueAccent = Color(0xFF1469F5);
  static const Color blueBorder = Color(0xFFDCE7F7); // Light blue surface border
  static const Color blueBorderLight = Color(0xFFE5E7EB); // Subtle border
  static const Color blueBorderFocused = Color(0xFF1469F5);
  static const Color red = Color(0xFFE11D48); // Notice accent
  static const Color redDark = Color(0xFFBE123C);
  static const Color coral = Color(0xFFEF4444);
  static const Color cyan = Color(0xFF0284C7);
  static const Color bg = Color(0xFFF8FAFC);
}

/// Official SRU Logo Widget matching the university's bold lowercase brandmark
class SruLogo extends StatelessWidget {
  const SruLogo({
    super.key,
    this.isLight = false,
    this.fontSize = 28,
    this.showUniversityName = true,
    this.subtitle,
  });

  final bool isLight;
  final double fontSize;
  final bool showUniversityName;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textColor = isLight ? Colors.white : SruColors.navy;
    final subColor = isLight ? Colors.white.withOpacity(0.85) : const Color(0xFF475569);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Signature bold lowercase "sru" brand mark
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: isLight ? Colors.white.withOpacity(0.12) : SruColors.navy.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isLight ? Colors.white.withOpacity(0.3) : SruColors.navy.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Text(
            'sru',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              color: textColor,
              height: 1.0,
            ),
          ),
        ),
        if (showUniversityName) ...[
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SR UNIVERSITY',
                style: TextStyle(
                  fontSize: fontSize * 0.48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: textColor,
                  height: 1.1,
                ),
              ),
              Text(
                subtitle ?? 'CSSP MENTOR TRACKER',
                style: TextStyle(
                  fontSize: fontSize * 0.32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: subColor,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Top contact & university portal strip matching Image 1
class SruTopContactStrip extends StatelessWidget {
  const SruTopContactStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Container(
      width: double.infinity,
      color: SruColors.navyDark,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_in_talk, size: 13, color: Colors.white70),
              const SizedBox(width: 6),
              const Text(
                '(870) 281-8333/8311',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.email_outlined, size: 13, color: Colors.white70),
              const SizedBox(width: 6),
              const Text(
                'info@sru.edu.in',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Spacer(),
          if (isDesktop) ...[
            _topLink('Minors & Honours'),
            _topLink('Careers'),
            _topLink('SRiX'),
            _topLink('Visit Us'),
            _topLink('Alumni'),
            _topLink('IQAC'),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: SruColors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'CSSP Portal',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _topLink(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Circular notice marquee strip matching Image 2
class SruNoticeTicker extends StatelessWidget {
  const SruNoticeTicker({super.key, this.notice});
  final String? notice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: SruColors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'SRU NOTICE',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              notice ?? 'All students and mentors are requested to submit and review weekly coding progress on schedule.',
              style: const TextStyle(color: SruColors.redDark, fontSize: 12, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
