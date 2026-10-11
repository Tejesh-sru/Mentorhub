import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : (v is String ? DateTime.tryParse(v) : null);

/// Represents a configured mentoring week (W1-W12) with start date and cumulative LeetCode target.
class WeekConfig {
  const WeekConfig({
    required this.id,
    required this.batchId,
    required this.weekId,
    required this.label,
    required this.startsAt,
    required this.targetCumulative,
    required this.order,
  });

  final String id;
  final String batchId;
  final String weekId;
  final String label;
  final DateTime startsAt;
  final int targetCumulative;
  final int order;

  static const List<int> defaultCumulativeTargets = [
    98, 111, 141, 156, 170, 184, 207, 207, 207, 207, 207, 207
  ];

  static List<WeekConfig> defaultWeeks(String batchId) {
    // Initial prototype defines W1–W12 beginning 05 Oct 2026
    final baseDate = DateTime(2026, 10, 5);
    return List.generate(12, (index) {
      final weekNum = index + 1;
      final weekId = 'W$weekNum';
      return WeekConfig(
        id: '${batchId}_$weekId',
        batchId: batchId,
        weekId: weekId,
        label: 'Week $weekNum',
        startsAt: baseDate.add(Duration(days: index * 7)),
        targetCumulative: defaultCumulativeTargets[index],
        order: weekNum,
      );
    });
  }

  factory WeekConfig.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    final order = (m['order'] as num?)?.toInt() ?? 1;
    final weekId = (m['weekId'] as String?) ?? 'W$order';
    return WeekConfig(
      id: doc.id,
      batchId: (m['batchId'] ?? '') as String,
      weekId: weekId,
      label: (m['label'] ?? 'Week $order') as String,
      startsAt: _ts(m['startsAt']) ?? DateTime(2026, 10, 5),
      targetCumulative: (m['targetCumulative'] as num?)?.toInt() ?? (order <= 12 ? defaultCumulativeTargets[order - 1] : 207),
      order: order,
    );
  }

  Map<String, dynamic> toMap() => {
        'batchId': batchId,
        'weekId': weekId,
        'label': label,
        'startsAt': Timestamp.fromDate(startsAt),
        'targetCumulative': targetCumulative,
        'order': order,
      };
}

/// submissions/{batchId_weekId_juniorUid}
/// Represents weekly student submission and live senior mentor verification.
class WeeklySubmission {
  const WeeklySubmission({
    required this.id,
    required this.batchId,
    required this.weekId,
    required this.juniorUid,
    this.seniorUid,
    required this.claimedCount,
    this.problemName,
    this.problemUrl,
    this.approach,
    required this.status,
    this.verifiedCount,
    this.verificationStatus,
    this.seriousness,
    this.remarks,
    required this.submittedAt,
    this.checkedAt,
    this.checkedByUid,
  });

  final String id;
  final String batchId;
  final String weekId;
  final String juniorUid;
  final String? seniorUid;
  final int claimedCount;
  final String? problemName;
  final String? problemUrl;
  final String? approach;
  final String status; // 'AWAITING_REVIEW', 'VERIFIED', 'DOUBTFUL', 'NOT_SUBMITTED'
  final int? verifiedCount;
  final String? verificationStatus; // 'VERIFIED', 'DOUBTFUL', 'NOT_CHECKED'
  final String? seriousness; // 'HIGH', 'MEDIUM', 'LOW'
  final String? remarks;
  final DateTime submittedAt;
  final DateTime? checkedAt;
  final String? checkedByUid;

  /// Business Rule (Spec 4):
  /// Target met iff verified count >= that week's cumulative target; pending/awaiting review must not count as verified.
  bool isTargetMet(dynamic target) {
    if (verificationStatus != 'VERIFIED') return false;
    final int weekTarget = target is WeekConfig ? target.targetCumulative : (target as int? ?? 0);
    return (verifiedCount ?? 0) >= weekTarget;
  }

  factory WeeklySubmission.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return WeeklySubmission(
      id: doc.id,
      batchId: (m['batchId'] ?? '') as String,
      weekId: (m['weekId'] ?? '') as String,
      juniorUid: (m['juniorUid'] ?? m['studentId'] ?? '') as String,
      seniorUid: m['seniorUid'] ?? m['mentorId'] as String?,
      claimedCount: (m['claimedCount'] as num?)?.toInt() ?? 0,
      problemName: m['problemName'] as String?,
      problemUrl: m['problemUrl'] as String?,
      approach: m['approach'] as String?,
      status: (m['status'] ?? 'AWAITING_REVIEW') as String,
      verifiedCount: (m['verifiedCount'] as num?)?.toInt(),
      verificationStatus: m['verificationStatus'] as String?,
      seriousness: m['seriousness'] as String?,
      remarks: m['remarks'] as String?,
      submittedAt: _ts(m['submittedAt']) ?? DateTime.now(),
      checkedAt: _ts(m['checkedAt']),
      checkedByUid: m['checkedByUid'] as String?,
    );
  }
}

/// mocks/{batchId_weekId_juniorUid}
/// Represents a weekly mock interview schedule, evaluation, and feedback.
class MockInterview {
  const MockInterview({
    required this.id,
    required this.batchId,
    required this.weekId,
    required this.juniorUid,
    this.seniorUid,
    this.scheduledAt,
    required this.status,
    this.topic,
    this.meetingLink,
    this.durationMinutes,
    this.score10,
    this.technical5,
    this.communication5,
    this.problemSolving5,
    this.recommendation,
    this.notes,
    this.evaluatorUid,
    this.updatedAt,
  });

  final String id;
  final String batchId;
  final String weekId;
  final String juniorUid;
  final String? seniorUid;
  final DateTime? scheduledAt;
  final String status; // 'NOT_PLANNED', 'SCHEDULED', 'COMPLETED', 'MISSED', 'CANCELLED'
  final String? topic;
  final String? meetingLink;
  final int? durationMinutes;
  final double? score10; // 0..10
  final double? technical5; // 0..5
  final double? communication5; // 0..5
  final double? problemSolving5; // 0..5
  final String? recommendation;
  final String? notes;
  final String? evaluatorUid;
  final DateTime? updatedAt;

  factory MockInterview.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return MockInterview(
      id: doc.id,
      batchId: (m['batchId'] ?? '') as String,
      weekId: (m['weekId'] ?? '') as String,
      juniorUid: (m['juniorUid'] ?? '') as String,
      seniorUid: m['seniorUid'] as String?,
      scheduledAt: _ts(m['scheduledAt']),
      status: (m['status'] ?? 'NOT_PLANNED') as String,
      topic: m['topic'] as String?,
      meetingLink: m['meetingLink'] as String?,
      durationMinutes: (m['durationMinutes'] as num?)?.toInt(),
      score10: (m['score10'] as num?)?.toDouble(),
      technical5: (m['technical5'] as num?)?.toDouble(),
      communication5: (m['communication5'] as num?)?.toDouble(),
      problemSolving5: (m['problemSolving5'] as num?)?.toDouble(),
      recommendation: m['recommendation'] as String?,
      notes: m['notes'] as String?,
      evaluatorUid: m['evaluatorUid'] as String?,
      updatedAt: _ts(m['updatedAt']),
    );
  }
}

/// auditLogs/{eventId}
/// Immutable audit log entry for changes to scores, roles, imports, and assignments.
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.actorUid,
    this.actorRole,
    required this.action,
    required this.targetPath,
    required this.timestamp,
    required this.changedFields,
  });

  final String id;
  final String actorUid;
  final String? actorRole;
  final String action;
  final String targetPath;
  final DateTime timestamp;
  final Map<String, dynamic> changedFields;

  factory AuditLogEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return AuditLogEntry(
      id: doc.id,
      actorUid: (m['actorUid'] ?? 'system') as String,
      actorRole: m['actorRole'] as String?,
      action: (m['action'] ?? '') as String,
      targetPath: (m['targetPath'] ?? '') as String,
      timestamp: _ts(m['timestamp']) ?? DateTime.now(),
      changedFields: (m['changedFields'] as Map<String, dynamic>?) ?? {},
    );
  }
}

/// Profile links helper & validator for the 6 requested links
class ProfileLinksHelper {
  static final RegExp urlRegExp = RegExp(
    r'^https?:\/\/[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}(\/.*)?$',
    caseSensitive: false,
  );

  static bool isValidUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    return urlRegExp.hasMatch(url.trim());
  }

  static int validCount({
    String? leetcode,
    String? codeforce,
    String? hackerrank,
    String? linkedin,
    String? github,
    String? resume,
  }) {
    int c = 0;
    if (isValidUrl(leetcode)) c++;
    if (isValidUrl(codeforce)) c++;
    if (isValidUrl(hackerrank)) c++;
    if (isValidUrl(linkedin)) c++;
    if (isValidUrl(github)) c++;
    if (isValidUrl(resume)) c++;
    return c;
  }

  static List<String> missingLinks({
    String? leetcode,
    String? codeforce,
    String? hackerrank,
    String? linkedin,
    String? github,
    String? resume,
  }) {
    final missing = <String>[];
    if (!isValidUrl(leetcode)) missing.add('LeetCode');
    if (!isValidUrl(codeforce)) missing.add('Codeforces');
    if (!isValidUrl(hackerrank)) missing.add('HackerRank');
    if (!isValidUrl(linkedin)) missing.add('LinkedIn');
    if (!isValidUrl(github)) missing.add('GitHub');
    if (!isValidUrl(resume)) missing.add('Resume');
    return missing;
  }
}
