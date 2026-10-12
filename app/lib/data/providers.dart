import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../models/app_user.dart';
import '../models/cssp_models.dart';
import '../models/models.dart';
import 'api.dart';

final authProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final apiProvider = Provider<Api>((ref) => Api(FirebaseFunctions.instanceFor(region: kFunctionsRegion)));

/// Signed-in user + their users/{uid} document (null = signed out, deactivated or no profile).
/// Streams, so a forced-password-change flag or deactivation is reflected immediately.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(authProvider);
  final db = ref.watch(firestoreProvider);
  return auth.authStateChanges().asyncExpand((fbUser) {
    if (fbUser == null) return Stream.value(null);
    return db.doc('users/${fbUser.uid}').snapshots().map(AppUser.fromDoc);
  });
});

final uidProvider = Provider<String?>((ref) => ref.watch(currentUserProvider).valueOrNull?.uid);

// ── Role-scoped reads (the security rules guarantee users can only read their own scope) ──

final myStudentProfileProvider = StreamProvider.autoDispose<StudentProfile?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(firestoreProvider).doc('students/$uid').snapshots().map((d) => d.exists ? StudentProfile.fromDoc(d) : null);
});

final myAssignmentsProvider = StreamProvider.autoDispose<List<Assignment>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('assignments')
      .where('studentId', isEqualTo: uid)
      .snapshots()
      .map((s) {
        final list = s.docs.map(Assignment.fromDoc).toList();
        list.sort((a, b) => a.deadline.compareTo(b.deadline));
        return list;
      });
});

final mentorStudentsProvider = StreamProvider.autoDispose<List<StudentProfile>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('students')
      .where('mentorId', isEqualTo: uid)
      .snapshots()
      .map((s) {
        final list = s.docs.map(StudentProfile.fromDoc).toList();
        list.sort((a, b) => a.studentCode.compareTo(b.studentCode));
        return list;
      });
});

final adminCountsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final db = ref.watch(firestoreProvider);
  final results = await Future.wait([
    db.collection('mentors').count().get(),
    db.collection('students').count().get(),
    db.collection('tasks').count().get(),
    db.collection('assignments').where('status', isEqualTo: 'SUBMITTED').count().get(),
    db.collection('assignments').where('status', isEqualTo: 'OVERDUE').count().get(),
  ]);
  int n(int i) => results[i].count ?? 0;
  return {'mentors': n(0), 'students': n(1), 'tasks': n(2), 'pendingReviews': n(3), 'overdue': n(4)};
});

final mentorSubmissionsProvider = StreamProvider.autoDispose<List<Submission>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('submissions')
      .where('mentorId', isEqualTo: uid)
      .where('reviewStatus', isEqualTo: 'PENDING')
      .snapshots()
      .map((s) {
        final list = s.docs.map(Submission.fromDoc).toList();
        list.sort((a, b) => (a.submittedAt ?? DateTime(2000)).compareTo(b.submittedAt ?? DateTime(2000)));
        return list;
      });
});

final adminBatchesProvider = FutureProvider.autoDispose<List<Map<String, String>>>((ref) async {
  final db = ref.watch(firestoreProvider);
  final snap = await db.collection('batches').orderBy('name').get();
  return snap.docs.map((d) => {'id': d.id, 'name': d.data()['name'] as String}).toList();
});

// ── Admin streaming providers ──

final adminBatchesStreamProvider = StreamProvider.autoDispose<List<Batch>>((ref) {
  return ref.watch(firestoreProvider).collection('batches').orderBy('name').snapshots().map((s) => s.docs.map(Batch.fromDoc).toList());
});

final adminMentorsProvider = StreamProvider.autoDispose<List<MentorProfile>>((ref) {
  return ref.watch(firestoreProvider).collection('mentors').orderBy('mentorCode').snapshots().map((s) => s.docs.map(MentorProfile.fromDoc).toList());
});

final adminStudentsProvider = StreamProvider.autoDispose<List<StudentProfile>>((ref) {
  return ref.watch(firestoreProvider).collection('students').orderBy('studentCode').snapshots().map((s) => s.docs.map(StudentProfile.fromDoc).toList());
});

final adminSubmissionsProvider = StreamProvider.autoDispose<List<Submission>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('submissions')
      .orderBy('submittedAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(Submission.fromDoc).toList());
});

final adminAnnouncementsProvider = StreamProvider.autoDispose<List<Announcement>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('announcements')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(Announcement.fromDoc).toList());
});

// ── Mentor streaming providers ──

final mentorTasksProvider = StreamProvider.autoDispose<List<Task>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(firestoreProvider).doc('mentors/$uid').snapshots().asyncExpand((snap) {
    if (!snap.exists) return Stream.value(const <Task>[]);
    final batchId = (snap.data() as Map<String, dynamic>)['batchId'] as String?;
    if (batchId == null) return Stream.value(const <Task>[]);
    return ref
        .watch(firestoreProvider)
        .collection('tasks')
        .where('batchId', isEqualTo: batchId)
        .snapshots()
        .map((s) {
          final list = s.docs.map(Task.fromDoc).toList();
          list.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
          return list;
        });
  });
});

final mentorSubmissionsAllProvider = StreamProvider.autoDispose<List<Submission>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('submissions')
      .where('mentorId', isEqualTo: uid)
      .snapshots()
      .map((s) {
        final list = s.docs.map(Submission.fromDoc).toList();
        list.sort((a, b) => (b.submittedAt ?? DateTime(2000)).compareTo(a.submittedAt ?? DateTime(2000)));
        return list;
      });
});

final mentorAnnouncementsProvider = StreamProvider.autoDispose<List<Announcement>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('announcements')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(Announcement.fromDoc).toList());
});

// ── Student streaming providers ──

final studentSubmissionsProvider = StreamProvider.autoDispose<List<Submission>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('submissions')
      .where('studentId', isEqualTo: uid)
      .snapshots()
      .map((s) {
        final list = s.docs.map(Submission.fromDoc).toList();
        list.sort((a, b) => (b.submittedAt ?? DateTime(2000)).compareTo(a.submittedAt ?? DateTime(2000)));
        return list;
      });
});

final studentNotificationsProvider = StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('notifications')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((s) {
        final list = s.docs.map(AppNotification.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        return list;
      });
});

final studentAnnouncementsProvider = StreamProvider.autoDispose<List<Announcement>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('announcements')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(Announcement.fromDoc).toList());
});

// ── Per-student providers (used by Student Detail page) ──

/// Assignments for a specific student (by uid). Usable by mentor/admin.
final studentAssignmentsProvider =
    StreamProvider.autoDispose.family<List<Assignment>, String>((ref, studentId) {
  return ref
      .watch(firestoreProvider)
      .collection('assignments')
      .where('studentId', isEqualTo: studentId)
      .snapshots()
      .map((s) {
        final list = s.docs.map(Assignment.fromDoc).toList();
        list.sort((a, b) => a.deadline.compareTo(b.deadline));
        return list;
      });
});

/// Submissions for a specific student (by uid). Usable by mentor/admin.
final studentSubmissionsForMentorProvider =
    StreamProvider.autoDispose.family<List<Submission>, String>((ref, studentId) {
  return ref
      .watch(firestoreProvider)
      .collection('submissions')
      .where('studentId', isEqualTo: studentId)
      .snapshots()
      .map((s) {
        final list = s.docs.map(Submission.fromDoc).toList();
        list.sort((a, b) => (b.submittedAt ?? DateTime(2000)).compareTo(a.submittedAt ?? DateTime(2000)));
        return list;
      });
});

// ── CSSP Mentor Tracker Providers ──

/// Configured 12 weeks for a batch. If not configured in Firestore, defaults to standard W1-W12 schedule.
final csspWeeksProvider = StreamProvider.autoDispose.family<List<WeekConfig>, String>((ref, batchId) {
  if (batchId.isEmpty) return Stream.value(WeekConfig.defaultWeeks('default'));
  return ref
      .watch(firestoreProvider)
      .collection('weeks')
      .where('batchId', isEqualTo: batchId)
      .snapshots()
      .map((s) {
        if (s.docs.isEmpty) {
          return WeekConfig.defaultWeeks(batchId);
        }
        final list = s.docs.map(WeekConfig.fromDoc).toList();
        list.sort((a, b) => a.order.compareTo(b.order));
        return list;
      });
});

/// Weekly progress submissions for a junior/student
final csspStudentSubmissionsProvider =
    StreamProvider.autoDispose.family<List<WeeklySubmission>, String>((ref, juniorUid) {
  if (juniorUid.isEmpty) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('submissions')
      .where('juniorUid', isEqualTo: juniorUid)
      .snapshots()
      .map((s) => s.docs.map(WeeklySubmission.fromDoc).toList());
});

/// Mock interview evaluations for a junior/student
final csspStudentMocksProvider =
    StreamProvider.autoDispose.family<List<MockInterview>, String>((ref, juniorUid) {
  if (juniorUid.isEmpty) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('mocks')
      .where('juniorUid', isEqualTo: juniorUid)
      .snapshots()
      .map((s) => s.docs.map(MockInterview.fromDoc).toList());
});

/// All weekly submissions for a batch (used by Admin and Senior dashboards)
final csspBatchSubmissionsProvider =
    StreamProvider.autoDispose.family<List<WeeklySubmission>, String>((ref, batchId) {
  if (batchId.isEmpty) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('submissions')
      .where('batchId', isEqualTo: batchId)
      .snapshots()
      .map((s) => s.docs.map(WeeklySubmission.fromDoc).toList());
});

/// All mock interviews for a batch
final csspBatchMocksProvider =
    StreamProvider.autoDispose.family<List<MockInterview>, String>((ref, batchId) {
  if (batchId.isEmpty) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('mocks')
      .where('batchId', isEqualTo: batchId)
      .snapshots()
      .map((s) => s.docs.map(MockInterview.fromDoc).toList());
});

/// Immutable Audit logs stream for Super Admin / Admin
final csspAuditLogsProvider = StreamProvider.autoDispose<List<AuditLogEntry>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('auditLogs')
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(AuditLogEntry.fromDoc).toList());
});

/// Import history records
final csspImportsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('imports')
      .orderBy('startedAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

// ── New Feature Providers: POTD, Milestones, Confidential Complaints, Mentor Notifications, Bulk Tasks ──

final myMentorProfileProvider = StreamProvider.autoDispose<MentorProfile?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .doc('mentors/$uid')
      .snapshots()
      .map((d) => d.exists ? MentorProfile.fromDoc(d) : null);
});

final mentorNotificationsProvider = StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('notifications')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((s) {
        final list = s.docs.map(AppNotification.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        return list;
      });
});

final potdListProvider = StreamProvider.autoDispose<List<ProblemOfTheDay>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('potd')
      .snapshots()
      .map((s) {
        final list = s.docs.map(ProblemOfTheDay.fromDoc).toList();
        list.sort((a, b) => b.dateKey.compareTo(a.dateKey));
        return list;
      });
});

final myPotdSubmissionsProvider = StreamProvider.autoDispose<List<PotdSubmission>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('potd_submissions')
      .where('studentId', isEqualTo: uid)
      .snapshots()
      .map((s) {
        final list = s.docs.map(PotdSubmission.fromDoc).toList();
        list.sort((a, b) => b.dateKey.compareTo(a.dateKey));
        return list;
      });
});

final studentPotdSubmissionsProvider =
    StreamProvider.autoDispose.family<List<PotdSubmission>, String>((ref, studentId) {
  if (studentId.isEmpty) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('potd_submissions')
      .where('studentId', isEqualTo: studentId)
      .snapshots()
      .map((s) {
        final list = s.docs.map(PotdSubmission.fromDoc).toList();
        list.sort((a, b) => b.dateKey.compareTo(a.dateKey));
        return list;
      });
});

final myComplaintsProvider = StreamProvider.autoDispose<List<Complaint>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('complaints')
      .where('authorUid', isEqualTo: uid)
      .snapshots()
      .map((s) {
        final list = s.docs.map(Complaint.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        return list;
      });
});

final adminComplaintsProvider = StreamProvider.autoDispose<List<Complaint>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('complaints')
      .snapshots()
      .map((s) {
        final list = s.docs.map(Complaint.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        return list;
      });
});

final adminTasksProvider = StreamProvider.autoDispose<List<Task>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('tasks')
      .snapshots()
      .map((s) {
        final list = s.docs.map(Task.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        return list;
      });
});

// ── Real-Time Mentor–Mentee Chat Providers ──

/// Streams the assigned MentorProfile for the signed-in student.
final studentAssignedMentorProvider = StreamProvider.autoDispose<MentorProfile?>((ref) {
  final studentProfile = ref.watch(myStudentProfileProvider).valueOrNull;
  final mentorId = studentProfile?.mentorId;
  if (mentorId == null || mentorId.isEmpty) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .doc('mentors/$mentorId')
      .snapshots()
      .map((d) => d.exists ? MentorProfile.fromDoc(d) : null);
});

/// Streams all active chat conversations for the signed-in mentor.
final mentorChatConversationsProvider = StreamProvider.autoDispose<Map<String, ChatConversation>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const {});
  return ref
      .watch(firestoreProvider)
      .collection('chats')
      .where('mentorId', isEqualTo: uid)
      .snapshots()
      .map((s) {
        final map = <String, ChatConversation>{};
        for (final doc in s.docs) {
          final conv = ChatConversation.fromDoc(doc);
          map[conv.studentId] = conv;
        }
        return map;
      });
});

/// Streams the chat conversation between the signed-in student and their assigned mentor.
final studentChatConversationProvider = StreamProvider.autoDispose<ChatConversation?>((ref) {
  final studentProfile = ref.watch(myStudentProfileProvider).valueOrNull;
  if (studentProfile == null || studentProfile.mentorId == null || studentProfile.mentorId!.isEmpty) {
    return Stream.value(null);
  }
  final chatId = ChatConversation.chatIdFor(studentProfile.mentorId!, studentProfile.uid);
  return ref
      .watch(firestoreProvider)
      .doc('chats/$chatId')
      .snapshots()
      .map((d) => d.exists ? ChatConversation.fromDoc(d) : null);
});

/// Streams all students belonging to a specific Mentor's mentorship group.
final groupStudentsProvider = StreamProvider.autoDispose.family<List<StudentProfile>, String>((ref, mentorId) {
  if (mentorId.isEmpty) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('students')
      .where('mentorId', isEqualTo: mentorId)
      .snapshots()
      .map((s) {
        final list = s.docs.map(StudentProfile.fromDoc).toList();
        list.sort((a, b) => a.studentCode.compareTo(b.studentCode));
        return list;
      });
});

/// Streams messages in real time for a given mentor group chat ("{mentorUid}").
final chatMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, chatId) {
  if (chatId.isEmpty) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('chats/$chatId/messages')
      .snapshots()
      .map((s) {
        final list = s.docs.map(ChatMessage.fromDoc).toList();
        list.sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));
        return list;
      });
});


