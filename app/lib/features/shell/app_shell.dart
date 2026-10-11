import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/sru_branding.dart';
import '../../data/providers.dart';

class NavItem {
  const NavItem(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

/// Responsive scaffold with deep university-blue top navigation on desktop
/// and collapsible drawer on mobile/tablet.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.roleLabel,
    required this.items,
    required this.profilePath,
    required this.location,
    required this.child,
  });

  final String roleLabel;
  final List<NavItem> items;
  final String profilePath;
  final String location;
  final Widget child;

  int get _selected {
    final i = items.indexWhere((e) => location.startsWith(e.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 960;

    final bannerAndContent = Column(children: [
      if (user?.mustChangePassword == true)
        Container(
          width: double.infinity,
          color: const Color(0xFFFEF3C7),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'You are using a temporary password. Please update your password.',
                  style: TextStyle(color: Color(0xFF92400E), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => context.go(profilePath),
                child: const Text('Change Password', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      Expanded(child: child),
    ]);

    final roleBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            roleLabel.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
        ],
      ),
    );

    // ── Desktop Layout: Deep University-Blue Top Header ──
    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FC),
        body: Column(
          children: [
            // Deep University-Blue Top Navigation Bar (#274985)
            Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(
                color: SruColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Logo on left
                  const SruLogo(
                    isLight: true,
                    fontSize: 20,
                    subtitle: 'CSSP MENTOR TRACKER',
                  ),
                  const SizedBox(width: 24),

                  // Horizontal Navigation Items
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: items.asMap().entries.map((entry) {
                          final i = entry.key;
                          final item = entry.value;
                          final isSelected = _selected == i;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Material(
                              color: isSelected ? SruColors.primaryHover : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                onTap: () => context.go(item.path),
                                borderRadius: BorderRadius.circular(10),
                                hoverColor: SruColors.primaryHover.withOpacity(0.8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? Colors.white.withOpacity(0.3) : Colors.transparent,
                                      width: 1.0,
                                    ),
                                    boxShadow: isSelected
                                        ? const [
                                            BoxShadow(
                                              color: Color(0x20000000),
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        item.icon,
                                        size: 16,
                                        color: isSelected ? Colors.white : Colors.white70,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        item.label.toUpperCase(),
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.85),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Right Profile & Role Controls
                  roleBadge,
                  const SizedBox(width: 12),
                  if (user != null)
                    Text(
                      user.email,
                      style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Settings',
                    icon: const Icon(Icons.settings_outlined, size: 18, color: Colors.white70),
                    onPressed: () => context.go(profilePath),
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white70),
                    onPressed: () async {
                      await ref.read(authProvider).signOut();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ],
              ),
            ),

            // Main Page Content Area
            Expanded(child: bannerAndContent),
          ],
        ),
      );
    }

    // ── Mobile / Tablet Layout with Deep Blue App Bar & Drawer ──
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: SruColors.primary,
        foregroundColor: Colors.white,
        elevation: 1,
        title: const SruLogo(fontSize: 18, isLight: true, subtitle: 'SR UNIVERSITY'),
        actions: [
          roleBadge,
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
            onPressed: () => context.go(profilePath),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            onPressed: () async {
              await ref.read(authProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      drawer: NavigationDrawer(
        selectedIndex: _selected,
        onDestinationSelected: (i) {
          Navigator.of(context).pop();
          context.go(items[i].path);
        },
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [SruColors.primary, SruColors.primaryHover],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Text(
                    user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: SruColors.primary, fontSize: 18),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.name ?? 'User',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    roleLabel,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final i in items)
            NavigationDrawerDestination(
              icon: Icon(i.icon),
              label: Text(
                i.label.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
        ],
      ),
      body: bannerAndContent,
    );
  }
}
