import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/providers.dart';
import 'features/admin/admin_analytics_page.dart';
import 'features/admin/admin_announcements_page.dart';
import 'features/admin/admin_batches_page.dart';
import 'features/admin/admin_bulk_import_page.dart';
import 'features/admin/admin_mentors_page.dart';
import 'features/admin/admin_mock_planner_page.dart';
import 'features/admin/admin_reports_page.dart';
import 'features/admin/admin_students_page.dart';
import 'features/admin/admin_user_allocation_page.dart';
import 'features/admin/admin_weekly_schedule_page.dart';
import 'features/auth/login_page.dart';
import 'features/auth/profile_page.dart';
import 'features/home/admin_home.dart';
import 'features/home/admin_tasks_page.dart';
import 'features/home/mentor_home.dart';
import 'features/home/student_home.dart';
import 'features/mentor/mentor_announcements_page.dart';
import 'features/mentor/mentor_mock_planner_page.dart';
import 'features/mentor/mentor_notifications_page.dart';
import 'features/mentor/mentor_students_page.dart';
import 'features/mentor/mentor_submissions_page.dart';
import 'features/mentor/mentor_tasks_page.dart';
import 'features/shared/chat_page.dart';
import 'features/shared/complaints_page.dart';
import 'features/shared/potd_page.dart';
import 'features/shell/app_shell.dart';
import 'features/student/student_help_page.dart';
import 'features/student/student_links_page.dart';
import 'features/student/student_mocks_page.dart';
import 'features/student/student_notifications_page.dart';
import 'features/student/student_progress_page.dart';
import 'features/student/student_submissions_page.dart';
import 'features/student/student_weekly_history_page.dart';
import 'features/student/student_weekly_progress_page.dart';
import 'features/super_admin/super_admin_admins_page.dart';
import 'features/super_admin/super_admin_audit_page.dart';
import 'features/super_admin/super_admin_overview_page.dart';
import 'models/app_user.dart';

const _superAdminNav = [
  NavItem('/superadmin/dashboard', 'Overview', Icons.account_balance_rounded),
  NavItem('/superadmin/admins', 'Admins & Batches', Icons.shield_outlined),
  NavItem('/superadmin/mentors', 'Senior Mentors', Icons.engineering_outlined),
  NavItem('/superadmin/students', 'Junior Mentees', Icons.groups_outlined),
  NavItem('/superadmin/potd', 'Daily POTD', Icons.local_fire_department_rounded),
  NavItem('/superadmin/complaints', 'Complaints', Icons.security_rounded),
  NavItem('/superadmin/mocks', 'Mock Planner', Icons.event_available_rounded),
  NavItem('/superadmin/reports', 'Reports & Export', Icons.assessment_outlined),
  NavItem('/superadmin/audit', 'Audit Trail', Icons.history_edu_rounded),
  NavItem('/superadmin/settings', 'Settings', Icons.settings_outlined),
];

const _adminNav = [
  NavItem('/admin/dashboard', 'Batch Overview', Icons.speed),
  NavItem('/admin/batches', 'Batches (4)', Icons.collections_bookmark_outlined),
  NavItem('/admin/mentors', 'Mentors', Icons.engineering_outlined),
  NavItem('/admin/students', 'Students', Icons.groups_outlined),
  NavItem('/admin/tasks', 'Bulk Tasks', Icons.playlist_add_check_rounded),
  NavItem('/admin/potd', 'Daily POTD', Icons.local_fire_department_rounded),
  NavItem('/admin/complaints', 'Complaints', Icons.security_rounded),
  NavItem('/admin/user-allocation', 'User Allocation', Icons.people_outline_rounded),
  NavItem('/admin/mocks', 'Mock Planner', Icons.event_available_rounded),
  NavItem('/admin/weekly-schedule', 'Academic Calendar', Icons.calendar_today_outlined),
  NavItem('/admin/import', 'Bulk Import', Icons.file_upload_outlined),
  NavItem('/admin/reports', 'Reports & Export', Icons.assessment_outlined),
  NavItem('/admin/announcements', 'Announcements', Icons.campaign_outlined),
  NavItem('/admin/analytics', 'Analytics', Icons.insights_outlined),
  NavItem('/admin/settings', 'Settings', Icons.settings_outlined),
];

const _mentorNav = [
  NavItem('/mentor/dashboard', 'Dashboard', Icons.speed),
  NavItem('/mentor/students', 'My Juniors', Icons.groups_outlined),
  NavItem('/mentor/chat', 'Group Chat', Icons.forum_outlined),
  NavItem('/mentor/tasks', 'Tasks & Bulk', Icons.playlist_add_check_rounded),
  NavItem('/mentor/potd', 'Daily POTD', Icons.local_fire_department_rounded),
  NavItem('/mentor/submissions', 'Submissions', Icons.inbox_outlined),
  NavItem('/mentor/notifications', 'Notifications', Icons.notifications_active_outlined),
  NavItem('/mentor/complaints', 'Complaint Box', Icons.report_problem_outlined),
  NavItem('/mentor/mocks', 'Mock Planner', Icons.event_available_rounded),
  NavItem('/mentor/announcements', 'Announcements', Icons.campaign_outlined),
  NavItem('/mentor/profile', 'Profile', Icons.account_circle_outlined),
];

const _studentNav = [
  NavItem('/student/dashboard', 'Home', Icons.speed),
  NavItem('/student/chat', 'Group Chat', Icons.forum_outlined),
  NavItem('/student/potd', 'POTD & Milestones', Icons.local_fire_department_rounded),
  NavItem('/student/tasks', 'My Tasks', Icons.code),
  NavItem('/student/submissions', 'Submissions', Icons.inbox_outlined),
  NavItem('/student/complaints', 'Complaint Box', Icons.lock_person_outlined),
  NavItem('/student/links', 'Portfolio Links', Icons.link_rounded),
  NavItem('/student/mocks', 'Mock Details', Icons.rate_review_outlined),
  NavItem('/student/progress', 'Progress Analysis', Icons.emoji_events_outlined),
  NavItem('/student/notifications', 'Notifications', Icons.notifications_outlined),
  NavItem('/student/submit-progress', 'Submit Progress', Icons.trending_up_rounded),
  NavItem('/student/history', '12-Week History', Icons.calendar_month_outlined),
  NavItem('/student/help', 'Guidelines & Help', Icons.help_outline_rounded),
  NavItem('/student/profile', 'Profile', Icons.account_circle_outlined),
];

String homeFor(UserRole role) => '${role.basePath}/dashboard';

/// Builds a GoRoute per nav item.
List<RouteBase> _routes(List<NavItem> nav, Map<String, Widget> screens) => [
      for (final n in nav)
        GoRoute(
          path: n.path,
          pageBuilder: (context, state) => NoTransitionPage(child: screens[n.path]!),
        ),
    ];

final routerProvider = Provider<GoRouter>((ref) {
  // Bridges Riverpod -> GoRouter so redirects re-run when the auth state changes.
  final auth = ValueNotifier<AsyncValue<AppUser?>>(const AsyncLoading());
  ref.listen<AsyncValue<AppUser?>>(currentUserProvider, (_, next) => auth.value = next, fireImmediately: true);
  ref.onDispose(auth.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) {
      final a = auth.value;
      final loc = state.matchedLocation;
      if (a.isLoading) return loc == '/splash' ? null : '/splash';
      final user = a.valueOrNull;
      if (user == null) return loc == '/login' ? null : '/login';
      if (loc == '/login' || loc == '/splash' || loc == '/') return homeFor(user.role);
      // Role guard (UX only: Firestore rules + Cloud Functions enforce actual security)
      if (!loc.startsWith(user.role.basePath)) return homeFor(user.role);
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/splash'),
      GoRoute(path: '/splash', builder: (_, __) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          roleLabel: 'Super Admin',
          items: _superAdminNav,
          profilePath: '/superadmin/settings',
          location: state.matchedLocation,
          child: child,
        ),
        routes: _routes(_superAdminNav, {
          '/superadmin/dashboard': const SuperAdminOverviewPage(),
          '/superadmin/admins': const SuperAdminAdminsPage(),
          '/superadmin/mentors': const AdminMentorsPage(),
          '/superadmin/students': const AdminStudentsPage(),
          '/superadmin/potd': const PotdPage(),
          '/superadmin/complaints': const ComplaintsPage(),
          '/superadmin/mocks': const AdminMockPlannerPage(),
          '/superadmin/reports': const AdminReportsPage(),
          '/superadmin/audit': const SuperAdminAuditPage(),
          '/superadmin/settings': const ProfilePage(),
        }),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          roleLabel: 'Admin',
          items: _adminNav,
          profilePath: '/admin/settings',
          location: state.matchedLocation,
          child: child,
        ),
        routes: _routes(_adminNav, {
          '/admin/dashboard': const AdminHome(),
          '/admin/batches': const AdminBatchesPage(),
          '/admin/mentors': const AdminMentorsPage(),
          '/admin/students': const AdminStudentsPage(),
          '/admin/tasks': const AdminTasksPage(),
          '/admin/potd': const PotdPage(),
          '/admin/complaints': const ComplaintsPage(),
          '/admin/user-allocation': const AdminUserAllocationPage(),
          '/admin/mocks': const AdminMockPlannerPage(),
          '/admin/weekly-schedule': const AdminWeeklySchedulePage(),
          '/admin/import': const AdminBulkImportPage(),
          '/admin/reports': const AdminReportsPage(),
          '/admin/announcements': const AdminAnnouncementsPage(),
          '/admin/analytics': const AdminAnalyticsPage(),
          '/admin/settings': const ProfilePage(),
        }),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          roleLabel: 'Senior Mentor',
          items: _mentorNav,
          profilePath: '/mentor/profile',
          location: state.matchedLocation,
          child: child,
        ),
        routes: _routes(_mentorNav, {
          '/mentor/dashboard': const MentorHome(),
          '/mentor/students': const MentorStudentsPage(),
          '/mentor/chat': const ChatPage(),
          '/mentor/tasks': const MentorTasksPage(),
          '/mentor/potd': const PotdPage(),
          '/mentor/submissions': const MentorSubmissionsPage(),
          '/mentor/notifications': const MentorNotificationsPage(),
          '/mentor/complaints': const ComplaintsPage(),
          '/mentor/mocks': const MentorMockPlannerPage(),
          '/mentor/announcements': const MentorAnnouncementsPage(),
          '/mentor/profile': const ProfilePage(),
        }),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          roleLabel: 'Junior Mentee',
          items: _studentNav,
          profilePath: '/student/profile',
          location: state.matchedLocation,
          child: child,
        ),
        routes: _routes(_studentNav, {
          '/student/dashboard': const StudentHome(),
          '/student/chat': const ChatPage(),
          '/student/potd': const PotdPage(),
          '/student/tasks': const StudentTasksPage(),
          '/student/submissions': const StudentSubmissionsPage(),
          '/student/complaints': const ComplaintsPage(),
          '/student/links': const StudentLinksPage(),
          '/student/mocks': const StudentMocksPage(),
          '/student/progress': const StudentProgressPage(),
          '/student/notifications': const StudentNotificationsPage(),
          '/student/submit-progress': const StudentWeeklyProgressPage(),
          '/student/history': const StudentWeeklyHistoryPage(),
          '/student/help': const StudentHelpPage(),
          '/student/profile': const ProfilePage(),
        }),
      ),
    ],
  );
});
