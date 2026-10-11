import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  superAdmin,
  admin,
  mentor,
  student;

  static UserRole? parse(String? v) {
    if (v == null) return null;
    switch (v.toUpperCase()) {
      case 'SUPER_ADMIN':
      case 'SUPERADMIN':
        return UserRole.superAdmin;
      case 'ADMIN':
        return UserRole.admin;
      case 'MENTOR':
      case 'SENIOR':
        return UserRole.mentor;
      case 'STUDENT':
      case 'JUNIOR':
        return UserRole.student;
    }
    return null;
  }

  String get label => switch (this) {
        UserRole.superAdmin => 'Super Admin',
        UserRole.admin => 'Admin',
        UserRole.mentor => 'Senior Mentor',
        UserRole.student => 'Junior Mentor',
      };

  String get basePath => switch (this) {
        UserRole.superAdmin => '/superadmin',
        UserRole.admin => '/admin',
        UserRole.mentor => '/mentor',
        UserRole.student => '/student',
      };
}

/// users/{uid}: login identity written by Cloud Functions.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.mustChangePassword,
    this.batchId,
    this.batchIds = const [],
    this.rollNo,
    this.seniorUid,
    this.active = true,
  });

  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final bool mustChangePassword;
  final String? batchId;
  final List<String> batchIds;
  final String? rollNo;
  final String? seniorUid;
  final bool active;

  static AppUser? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    if (m == null) return null;
    final role = UserRole.parse(m['role'] as String?);
    if (role == null || m['isActive'] == false || m['active'] == false) return null;

    final rawBatchIds = m['batchIds'];
    final List<String> batchIds = [];
    if (rawBatchIds is List) {
      batchIds.addAll(rawBatchIds.map((e) => e.toString()));
    } else if (m['batchId'] is String) {
      batchIds.add(m['batchId'] as String);
    }

    return AppUser(
      uid: doc.id,
      email: (m['email'] ?? '') as String,
      name: (m['name'] ?? m['displayName'] ?? '') as String,
      role: role,
      mustChangePassword: m['mustChangePassword'] == true,
      batchId: m['batchId'] as String?,
      batchIds: batchIds,
      rollNo: (m['rollNo'] ?? m['studentCode'] ?? m['mentorCode']) as String?,
      seniorUid: (m['seniorUid'] ?? m['mentorId']) as String?,
      active: m['isActive'] != false && m['active'] != false,
    );
  }
}
