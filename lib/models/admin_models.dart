import 'package:cloud_firestore/cloud_firestore.dart';

import '../enums/user_role.dart';

/// Ringkasan akun pengguna kampus untuk panel Administrator.
class CampusUserSummary {
  const CampusUserSummary({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
    this.studentId,
    this.program,
    this.createdAt,
    this.lastLoginAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final bool isActive;
  final String? studentId;
  final String? program;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  factory CampusUserSummary.fromMap(Map<String, dynamic> data, {String? id}) {
    final roleRaw = (data['role'] as String?) ?? 'student';
    UserRole parsedRole;
    try {
      parsedRole = UserRole.fromString(roleRaw);
    } catch (_) {
      parsedRole = UserRole.student;
    }

    return CampusUserSummary(
      uid: (data['uid'] as String?) ?? id ?? '',
      email: (data['email'] as String?) ?? '',
      displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? (data['displayName'] as String).trim()
          : ((data['email'] as String?)?.split('@').first ?? 'Pengguna'),
      role: parsedRole,
      isActive: data['isActive'] is bool ? data['isActive'] as bool : true,
      studentId: data['studentId'] as String?,
      program: data['program'] as String?,
      createdAt: _parseDate(data['createdAt']),
      lastLoginAt: _parseDate(data['lastLoginAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'role': role.toClaimValue(),
        'isActive': isActive,
        if (studentId != null) 'studentId': studentId,
        if (program != null) 'program': program,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (lastLoginAt != null) 'lastLoginAt': lastLoginAt!.toIso8601String(),
      };

  CampusUserSummary copyWith({
    String? displayName,
    UserRole? role,
    bool? isActive,
    DateTime? lastLoginAt,
  }) =>
      CampusUserSummary(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        isActive: isActive ?? this.isActive,
        studentId: studentId,
        program: program,
        createdAt: createdAt,
        lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      );
}

/// Catatan audit operasi administratif dan alur kerja tiket.
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.performedBy,
    required this.summary,
    this.targetUser,
    this.timestamp,
  });

  final String id;
  final String action;
  final String performedBy;
  final String summary;
  final String? targetUser;
  final DateTime? timestamp;

  factory AuditLogEntry.fromMap(Map<String, dynamic> data, {String? id}) {
    final action = (data['action'] as String?) ?? 'unknown';
    final performedBy = (data['performedBy'] as String?) ?? 'system';
    final target = (data['targetUser'] as String?) ?? '';

    String summary = (data['summary'] as String?) ?? '';
    if (summary.isEmpty) {
      summary = switch (action) {
        'create_technician' =>
          'Membuat akun teknisi baru (${data['details']?['email'] ?? target})',
        'update_role' =>
          'Mengubah peran $target: ${data['oldRole'] ?? '-'} → ${data['newRole'] ?? '-'}',
        'deactivate_user' =>
          'Menonaktifkan akun $target${data['reason'] != null ? ' (${data['reason']})' : ''}',
        'reactivate_user' =>
          'Mengaktifkan kembali akun $target (${data['restoredRole'] ?? 'student'})',
        'assign_ticket' =>
          'Menugaskan tiket kepada ${data['assignedTo'] ?? '-'}',
        'delete_report' => 'Menghapus laporan ${data['reportId'] ?? ''}',
        _ => 'Aksi sistem: $action',
      };
    }

    return AuditLogEntry(
      id: id ?? (data['id'] as String?) ?? '',
      action: action,
      performedBy: performedBy,
      summary: summary,
      targetUser: target.isEmpty ? null : target,
      timestamp: _parseDate(data['timestamp']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'action': action,
        'performedBy': performedBy,
        'summary': summary,
        if (targetUser != null) 'targetUser': targetUser,
        if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
      };
}

DateTime? _parseDate(Object? raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}
