import '../enums/user_role.dart';

class UserModel {
  const UserModel({
    required this.name,
    required this.email,
    required this.studentId,
    required this.program,
    this.uid,
    this.role,
    this.isActive,
  });

  final String? uid;
  final String name;
  final String email;
  final String studentId;
  final String program;
  final UserRole? role;
  final bool? isActive;

  static const demo = UserModel(
    name: 'Nicolas Julian Kurnia P',
    email: 'nicolas.julian@student.pradita.ac.id',
    studentId: '2410101011',
    program: 'Informatika · Angkatan 2024',
    role: UserRole.student,
    isActive: true,
  );

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? studentId,
    String? program,
    UserRole? role,
    bool? isActive,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      studentId: studentId ?? this.studentId,
      program: program ?? this.program,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
    );
  }
}
