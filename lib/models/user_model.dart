class UserModel {
  const UserModel({
    required this.name,
    required this.email,
    required this.studentId,
    required this.program,
  });

  final String name;
  final String email;
  final String studentId;
  final String program;

  static const demo = UserModel(
    name: 'Nicolas Julian Kurnia P',
    email: 'nicolas.julian@student.pradita.ac.id',
    studentId: '2410101011',
    program: 'Informatika · Angkatan 2024',
  );
}
