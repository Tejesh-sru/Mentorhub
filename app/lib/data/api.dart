import 'package:cloud_functions/cloud_functions.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.code]);
  final String message;
  final String? code;
  @override
  String toString() => message;
}

/// Thin wrapper over the Cloud Functions callables (see functions/index.js for the full list).
class Api {
  Api(this._functions);
  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> call(String name, [Map<String, dynamic>? data]) async {
    try {
      final callable = _functions.httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
      );
      final res = await callable.call<dynamic>(data);
      final d = res.data;
      return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      throw ApiException(e.message ?? 'Request failed', e.code);
    }
  }

  // ── Student workflow ──
  Future<void> createTask(Map<String, dynamic> payload) => call('createTask', payload);
  Future<void> assignTask(String taskId, Map<String, dynamic> assignTo) => call('assignTask', {'taskId': taskId, 'assignTo': assignTo});

  Future<void> startAssignment(String assignmentId) => call('startAssignment', {'assignmentId': assignmentId});
  Future<void> submitAssignment(Map<String, dynamic> payload) => call('submitAssignment', payload);

  // ── Mentor workflow ──
  Future<void> reviewSubmission({required String submissionId, required String decision, String? feedback}) =>
      call('reviewSubmission', {'submissionId': submissionId, 'decision': decision, 'feedback': feedback});

  // ── Admin: People ──
  Future<Map<String, dynamic>> createMentor(Map<String, dynamic> input) => call('createMentor', input);
  Future<Map<String, dynamic>> createStudent(Map<String, dynamic> input) => call('createStudent', input);
  Future<void> setUserActive(String uid, bool isActive) => call('setUserActive', {'uid': uid, 'isActive': isActive});
  Future<void> resetUserPassword(String uid) => call('resetUserPassword', {'uid': uid});
  Future<void> updateStudentMentor(String studentId, String? mentorId) =>
      call('updateStudentMentor', {'studentId': studentId, 'mentorId': mentorId});

  // ── Admin: Announcements ──
  Future<Map<String, dynamic>> createAnnouncement(Map<String, dynamic> input) => call('createAnnouncement', input);

  // ── Admin: Maintenance ──
  Future<void> recomputeStats() => call('recomputeStats');
  Future<void> runJobs() => call('runJobs');

  // ── Account ──
  Future<void> markPasswordChanged() => call('markPasswordChanged');

  // ── CSSP: Weekly Progress & Live Verification ──
  Future<Map<String, dynamic>> submitWeeklyProgress(Map<String, dynamic> payload) =>
      call('submitWeeklyProgress', payload);

  Future<Map<String, dynamic>> verifyWeeklyProgress(Map<String, dynamic> payload) =>
      call('verifyWeeklyProgress', payload);

  // ── CSSP: Mock Interviews ──
  Future<Map<String, dynamic>> scheduleMock(Map<String, dynamic> payload) =>
      call('scheduleMock', payload);

  Future<Map<String, dynamic>> evaluateMock(Map<String, dynamic> payload) =>
      call('evaluateMock', payload);

  // ── CSSP: Schedules, Profile Links, Import & Admin ──
  Future<Map<String, dynamic>> updateWeeklyConfig(Map<String, dynamic> payload) =>
      call('updateWeeklyConfig', payload);

  Future<Map<String, dynamic>> updateProfileLinks(Map<String, dynamic> payload) =>
      call('updateProfileLinks', payload);

  Future<Map<String, dynamic>> bulkImportStudentsCssp(Map<String, dynamic> payload) =>
      call('bulkImportStudentsCssp', payload);

  Future<Map<String, dynamic>> createAdminAccount(Map<String, dynamic> payload) =>
      call('createAdminAccount', payload);
}
