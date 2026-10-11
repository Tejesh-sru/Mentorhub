import 'package:flutter/material.dart';

import 'sru_branding.dart';

const Color kPrimary = SruColors.primary; // 0xFF274985
const Color kPrimaryDark = SruColors.primaryHover; // 0xFF1E3A70
const Color kSecondary = SruColors.link; // 0xFF1469F5
const Color kAccent = SruColors.link; // 0xFF1469F5
const Color kSurface = SruColors.surface; // 0xFFFFFFFF
const Color kSurfaceBlue = SruColors.surfaceBlue; // 0xFFDCE7F7
const Color kBackground = SruColors.primary; // Primary university blue background (0xFF274985)
const Color kBorder = SruColors.border; // 0xFFE5E7EB
const Color kBorderActive = SruColors.link; // 0xFF1469F5
const Color kTextPrimary = SruColors.textPrimary; // 0xFF111827
const Color kTextSecondary = SruColors.textSecondary; // 0xFF374151

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kPrimary,
    primary: kPrimary,
    secondary: kSecondary,
    surface: kSurface,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF4F7FC),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: kPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: kBorder, width: 1.0),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurfaceBlue, // Pale blue input backgrounds (#DCE7F7)
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorder, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorder, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorderActive, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      labelStyle: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700, fontSize: 13),
      hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 2,
        shadowColor: const Color(0x30274985),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: kPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: kBorder, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      side: BorderSide.none,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
    dividerTheme: const DividerThemeData(
      color: kBorder,
      thickness: 1,
      space: 1,
    ),
  );
}

/// Colours for assignment / review / difficulty chips.
Color statusColor(String status) {
  switch (status) {
    case 'APPROVED':
    case 'EASY':
    case 'COMPLETED':
    case 'VERIFIED':
      return const Color(0xFF10B981); // Emerald
    case 'SUBMITTED':
    case 'AWAITING_REVIEW':
      return const Color(0xFFF59E0B); // Amber
    case 'IN_PROGRESS':
    case 'SCHEDULED':
      return SruColors.cyan; // Cyan / Blue
    case 'NEEDS_CHANGES':
    case 'NEEDS_REVISION':
    case 'MEDIUM':
      return const Color(0xFFF97316); // Orange
    case 'OVERDUE':
    case 'HARD':
    case 'MISSED':
    case 'DOUBTFUL':
      return SruColors.red; // SRU Red
    default:
      return const Color(0xFF64748B); // Slate
  }
}
