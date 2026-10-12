import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/progress.dart';

DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;

Map<String, int> _stats(dynamic raw) {
  final out = <String, int>{};
  if (raw is Map) {
    raw.forEach((k, v) => out[k as String] = (v as num).toInt());
  }
  return out;
}

String computeMilestone(int potdCount, int approvedTasks) {
  final total = potdCount + approvedTasks;
  if (total >= 50 || potdCount >= 30) return 'Diamond Champion';
  if (total >= 25 || potdCount >= 15) return 'Gold Solver';
  if (total >= 10 || potdCount >= 7) return 'Silver Solver';
  if (total >= 3 || potdCount >= 3) return 'Bronze Solver';
  if (total >= 1 || potdCount >= 1) return 'Rising Coder';
  return 'Starter';
}

/// students/{uid}
class StudentProfile {
  StudentProfile({
    required this.uid,
    required this.studentCode,
    required this.name,
    required this.email,
    required this.batchId,
    required this.mentorId,
    required this.stats,
    this.branch,
    this.batchName,
    this.mentorCode,
    this.mentorName,
    this.potdCount = 0,
    this.potdStreak = 0,
    this.phone,
    this.leetcode,
    this.codeforce,
    this.hackerrank,
    this.linkedin,
    this.github,
    this.resume,
  }) : progress = Progress.fromStats(stats);

  final String uid;
  final String studentCode;
  final String name;
  final String email;
  final String batchId;
  final String? mentorId;
  final String? branch;
  final String? batchName;
  final String? mentorCode;
  final String? mentorName;
  final int potdCount;
  final int potdStreak;
  final Map<String, int> stats;
  final Progress progress;
  final String? phone;
  final String? leetcode;
  final String? codeforce;
  final String? hackerrank;
  final String? linkedin;
  final String? github;
  final String? resume;

  String get milestone => computeMilestone(potdCount, progress.completed);

  factory StudentProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return StudentProfile(
      uid: d.id,
      studentCode: (m['studentCode'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      email: (m['email'] ?? '') as String,
      batchId: (m['batchId'] ?? '') as String,
      mentorId: m['mentorId'] as String?,
      branch: m['branch'] as String?,
      batchName: m['batchName'] as String?,
      mentorCode: m['mentorCode'] as String?,
      mentorName: m['mentorName'] as String?,
      potdCount: ((m['potdCount'] ?? 0) as num).toInt(),
      potdStreak: ((m['potdStreak'] ?? 0) as num).toInt(),
      stats: _stats(m['stats']),
      phone: m['phone'] as String?,
      leetcode: m['leetcode'] as String?,
      codeforce: m['codeforce'] as String?,
      hackerrank: m['hackerrank'] as String?,
      linkedin: m['linkedin'] as String?,
      github: m['github'] as String?,
      resume: m['resume'] as String?,
    );
  }
}

/// mentors/{uid}
class MentorProfile {
  const MentorProfile({
    required this.uid,
    required this.mentorCode,
    required this.name,
    required this.email,
    required this.batchId,
    this.batchName,
    this.studentCount = 0,
  });

  final String uid;
  final String mentorCode;
  final String name;
  final String email;
  final String batchId;
  final String? batchName;
  final int studentCount;

  factory MentorProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return MentorProfile(
      uid: d.id,
      mentorCode: (m['mentorCode'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      email: (m['email'] ?? '') as String,
      batchId: (m['batchId'] ?? '') as String,
      batchName: m['batchName'] as String?,
      studentCount: ((m['studentCount'] ?? 0) as num).toInt(),
    );
  }
}

/// assignments/{taskId_studentUid}: one task for one student (task fields are denormalised).
class Assignment {
  const Assignment({
    required this.id,
    required this.taskId,
    required this.studentId,
    required this.mentorId,
    required this.status,
    required this.deadline,
    required this.taskTitle,
    required this.taskDescription,
    required this.platform,
    required this.problemUrl,
    required this.difficulty,
    required this.topic,
    required this.studentName,
    required this.studentCode,
    this.assignedAt,
    this.startedAt,
    this.submittedAt,
    this.reviewedAt,
  });

  final String id;
  final String taskId;
  final String studentId;
  final String? mentorId;
  final String status;
  final DateTime deadline;
  final String taskTitle;
  final String? taskDescription;
  final String platform;
  final String problemUrl;
  final String difficulty;
  final String topic;
  final String studentName;
  final String studentCode;
  final DateTime? assignedAt;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  factory Assignment.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Assignment(
      id: d.id,
      taskId: (m['taskId'] ?? '') as String,
      studentId: (m['studentId'] ?? '') as String,
      mentorId: m['mentorId'] as String?,
      status: (m['status'] ?? 'ASSIGNED') as String,
      deadline: _ts(m['deadline']) ?? DateTime.now(),
      taskTitle: (m['taskTitle'] ?? '') as String,
      taskDescription: m['taskDescription'] as String?,
      platform: (m['platform'] ?? 'OTHER') as String,
      problemUrl: (m['problemUrl'] ?? '') as String,
      difficulty: (m['difficulty'] ?? 'EASY') as String,
      topic: (m['topic'] ?? '') as String,
      studentName: (m['studentName'] ?? '') as String,
      studentCode: (m['studentCode'] ?? '') as String,
      assignedAt: _ts(m['assignedAt']),
      startedAt: _ts(m['startedAt']),
      submittedAt: _ts(m['submittedAt']),
      reviewedAt: _ts(m['reviewedAt']),
    );
  }
}

/// batches/{batchId}
class Batch {
  const Batch({required this.id, required this.name, required this.academicYear, required this.startDate, required this.endDate, required this.isActive});
  final String id;
  final String name;
  final String academicYear;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  factory Batch.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Batch(
      id: d.id,
      name: (m['name'] ?? '') as String,
      academicYear: (m['academicYear'] ?? '') as String,
      startDate: _ts(m['startDate']) ?? DateTime.now(),
      endDate: _ts(m['endDate']) ?? DateTime.now(),
      isActive: m['isActive'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'academicYear': academicYear,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'isActive': isActive,
      };
}

/// tasks/{taskId}
class Task {
  const Task({required this.id, required this.title, required this.description, required this.platform, required this.problemUrl, required this.difficulty, required this.topic, required this.batchId, required this.deadline, required this.createdAt});
  final String id;
  final String title;
  final String? description;
  final String platform;
  final String problemUrl;
  final String difficulty;
  final String topic;
  final String batchId;
  final DateTime deadline;
  final DateTime? createdAt;

  factory Task.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Task(
      id: d.id,
      title: (m['title'] ?? '') as String,
      description: m['description'] as String?,
      platform: (m['platform'] ?? 'OTHER') as String,
      problemUrl: (m['problemUrl'] ?? '') as String,
      difficulty: (m['difficulty'] ?? 'EASY') as String,
      topic: (m['topic'] ?? '') as String,
      batchId: (m['batchId'] ?? '') as String,
      deadline: _ts(m['deadline']) ?? DateTime.now(),
      createdAt: _ts(m['createdAt']),
    );
  }
}

/// potd/{dateKey} — Problem of the Day
class ProblemOfTheDay {
  const ProblemOfTheDay({
    required this.id,
    required this.dateKey,
    required this.title,
    required this.platform,
    required this.problemUrl,
    required this.difficulty,
    required this.topic,
    this.description,
    required this.mentorId,
    required this.mentorName,
    required this.mentorCode,
    required this.solvedCount,
    this.createdAt,
  });

  final String id;
  final String dateKey;
  final String title;
  final String platform;
  final String problemUrl;
  final String difficulty;
  final String topic;
  final String? description;
  final String mentorId;
  final String mentorName;
  final String mentorCode;
  final int solvedCount;
  final DateTime? createdAt;

  factory ProblemOfTheDay.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return ProblemOfTheDay(
      id: d.id,
      dateKey: (m['dateKey'] ?? d.id) as String,
      title: (m['title'] ?? '') as String,
      platform: (m['platform'] ?? 'LEETCODE') as String,
      problemUrl: (m['problemUrl'] ?? '') as String,
      difficulty: (m['difficulty'] ?? 'MEDIUM') as String,
      topic: (m['topic'] ?? 'Algorithms') as String,
      description: m['description'] as String?,
      mentorId: (m['mentorId'] ?? '') as String,
      mentorName: (m['mentorName'] ?? 'Senior Mentor') as String,
      mentorCode: (m['mentorCode'] ?? '') as String,
      solvedCount: ((m['solvedCount'] ?? 0) as num).toInt(),
      createdAt: _ts(m['createdAt']),
    );
  }
}

/// potd_submissions/{dateKey_studentUid}
class PotdSubmission {
  const PotdSubmission({
    required this.id,
    required this.potdId,
    required this.dateKey,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.potdTitle,
    required this.solutionUrl,
    this.approach,
    this.completedAt,
  });

  final String id;
  final String potdId;
  final String dateKey;
  final String studentId;
  final String studentName;
  final String studentCode;
  final String potdTitle;
  final String solutionUrl;
  final String? approach;
  final DateTime? completedAt;

  factory PotdSubmission.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return PotdSubmission(
      id: d.id,
      potdId: (m['potdId'] ?? '') as String,
      dateKey: (m['dateKey'] ?? '') as String,
      studentId: (m['studentId'] ?? '') as String,
      studentName: (m['studentName'] ?? '') as String,
      studentCode: (m['studentCode'] ?? '') as String,
      potdTitle: (m['potdTitle'] ?? '') as String,
      solutionUrl: (m['solutionUrl'] ?? '') as String,
      approach: m['approach'] as String?,
      completedAt: _ts(m['completedAt']),
    );
  }
}

/// complaints/{id} — Confidential Complaint Box (Student -> Admin, Mentor -> Admin)
class Complaint {
  const Complaint({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.authorCode,
    required this.authorRole,
    this.batchId,
    required this.targetType,
    required this.targetName,
    required this.subject,
    required this.description,
    required this.isConfidential,
    required this.status,
    this.adminReply,
    this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String authorCode;
  final String authorRole; // 'STUDENT' or 'MENTOR'
  final String? batchId;
  final String targetType; // 'TRAINER', 'MENTOR', 'PROGRAMME', 'STUDENT', 'OTHER'
  final String targetName;
  final String subject;
  final String description;
  final bool isConfidential;
  final String status; // 'OPEN', 'IN_REVIEW', 'RESOLVED'
  final String? adminReply;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  factory Complaint.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Complaint(
      id: d.id,
      authorUid: (m['authorUid'] ?? '') as String,
      authorName: (m['authorName'] ?? '') as String,
      authorCode: (m['authorCode'] ?? '') as String,
      authorRole: (m['authorRole'] ?? 'STUDENT') as String,
      batchId: m['batchId'] as String?,
      targetType: (m['targetType'] ?? 'TRAINER') as String,
      targetName: (m['targetName'] ?? '') as String,
      subject: (m['subject'] ?? '') as String,
      description: (m['description'] ?? '') as String,
      isConfidential: m['isConfidential'] != false,
      status: (m['status'] ?? 'OPEN') as String,
      adminReply: m['adminReply'] as String?,
      createdAt: _ts(m['createdAt']),
      resolvedAt: _ts(m['resolvedAt']),
    );
  }
}

/// announcements/{id}
class Announcement {
  const Announcement({required this.id, required this.title, required this.message, required this.targetType, required this.createdByName, required this.createdByRole, required this.createdAt, this.batchId});
  final String id;
  final String title;
  final String message;
  final String targetType;
  final String createdByName;
  final String createdByRole;
  final DateTime? createdAt;
  final String? batchId;

  factory Announcement.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Announcement(
      id: d.id,
      title: (m['title'] ?? '') as String,
      message: (m['message'] ?? '') as String,
      targetType: (m['targetType'] ?? 'ALL') as String,
      createdByName: (m['createdByName'] ?? '') as String,
      createdByRole: (m['createdByRole'] ?? '') as String,
      createdAt: _ts(m['createdAt']),
      batchId: m['batchId'] as String?,
    );
  }
}

/// notifications/{id}
class AppNotification {
  const AppNotification({required this.id, required this.userId, required this.title, required this.message, required this.type, required this.isRead, required this.createdAt});
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime? createdAt;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return AppNotification(
      id: d.id,
      userId: (m['userId'] ?? '') as String,
      title: (m['title'] ?? '') as String,
      message: (m['message'] ?? '') as String,
      type: (m['type'] ?? 'SYSTEM') as String,
      isRead: m['isRead'] == true,
      createdAt: _ts(m['createdAt']),
    );
  }
}

/// submissions/{assignmentId}
class Submission {
  const Submission({
    required this.id, required this.assignmentId, required this.taskId, required this.studentId, required this.mentorId,
    required this.studentName, required this.studentCode, required this.taskTitle, required this.understanding, required this.approach,
    required this.timeComplexity, required this.spaceComplexity, required this.solutionUrl, required this.code, required this.mentorFeedback,
    required this.reviewStatus, required this.submittedAt, required this.revision,
  });

  final String id; final String assignmentId; final String taskId; final String studentId; final String? mentorId;
  final String studentName; final String studentCode; final String taskTitle; final String understanding; final String approach;
  final String timeComplexity; final String spaceComplexity; final String? solutionUrl; final String? code; final String? mentorFeedback;
  final String reviewStatus; final DateTime submittedAt; final int revision;

  factory Submission.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Submission(
      id: d.id, assignmentId: (m['assignmentId'] ?? '') as String, taskId: (m['taskId'] ?? '') as String, studentId: (m['studentId'] ?? '') as String, mentorId: m['mentorId'] as String?,
      studentName: (m['studentName'] ?? '') as String, studentCode: (m['studentCode'] ?? '') as String, taskTitle: (m['taskTitle'] ?? '') as String,
      understanding: (m['understanding'] ?? '') as String, approach: (m['approach'] ?? '') as String, timeComplexity: (m['timeComplexity'] ?? '') as String, spaceComplexity: (m['spaceComplexity'] ?? '') as String,
      solutionUrl: m['solutionUrl'] as String?, code: m['code'] as String?, mentorFeedback: m['mentorFeedback'] as String?,
      reviewStatus: (m['reviewStatus'] ?? 'PENDING') as String, submittedAt: _ts(m['submittedAt']) ?? DateTime.now(), revision: (m['revision'] ?? 1) as int,
    );
  }
}

/// chats/{mentorUid_studentUid} — Private Mentor–Mentee Conversation
class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.mentorId,
    required this.mentorName,
    required this.mentorCode,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    this.batchId,
    this.batchName,
    this.lastMessage,
    this.lastSenderId,
    this.lastSenderRole,
    this.lastMessageAt,
    this.unreadForMentor = 0,
    this.unreadForStudent = 0,
    this.updatedAt,
  });

  final String id;
  final String mentorId;
  final String mentorName;
  final String mentorCode;
  final String studentId;
  final String studentName;
  final String studentCode;
  final String? batchId;
  final String? batchName;
  final String? lastMessage;
  final String? lastSenderId;
  final String? lastSenderRole;
  final DateTime? lastMessageAt;
  final int unreadForMentor;
  final int unreadForStudent;
  final DateTime? updatedAt;

  static String chatIdFor(String mentorId, String studentId) => '${mentorId}_$studentId';

  factory ChatConversation.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return ChatConversation(
      id: d.id,
      mentorId: (m['mentorId'] ?? '') as String,
      mentorName: (m['mentorName'] ?? '') as String,
      mentorCode: (m['mentorCode'] ?? '') as String,
      studentId: (m['studentId'] ?? '') as String,
      studentName: (m['studentName'] ?? '') as String,
      studentCode: (m['studentCode'] ?? '') as String,
      batchId: m['batchId'] as String?,
      batchName: m['batchName'] as String?,
      lastMessage: m['lastMessage'] as String?,
      lastSenderId: m['lastSenderId'] as String?,
      lastSenderRole: m['lastSenderRole'] as String?,
      lastMessageAt: _ts(m['lastMessageAt']),
      unreadForMentor: ((m['unreadForMentor'] ?? 0) as num).toInt(),
      unreadForStudent: ((m['unreadForStudent'] ?? 0) as num).toInt(),
      updatedAt: _ts(m['updatedAt']),
    );
  }
}

/// chats/{mentorId}/messages/{messageId}
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.mentorId,
    required this.studentId,
    required this.senderId,
    required this.senderName,
    required this.senderCode,
    required this.senderRole,
    required this.text,
    required this.isRead,
    this.createdAt,
  });

  final String id;
  final String chatId;
  final String mentorId;
  final String studentId;
  final String senderId;
  final String senderName;
  final String senderCode;
  final String senderRole;
  final String text;
  final bool isRead;
  final DateTime? createdAt;

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return ChatMessage(
      id: d.id,
      chatId: (m['chatId'] ?? '') as String,
      mentorId: (m['mentorId'] ?? '') as String,
      studentId: (m['studentId'] ?? '') as String,
      senderId: (m['senderId'] ?? '') as String,
      senderName: (m['senderName'] ?? '') as String,
      senderCode: (m['senderCode'] ?? '') as String,
      senderRole: (m['senderRole'] ?? '') as String,
      text: (m['text'] ?? '') as String,
      isRead: m['isRead'] == true,
      createdAt: _ts(m['createdAt']),
    );
  }
}

