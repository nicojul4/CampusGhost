enum UserRole {
  student('Mahasiswa / Dosen', 'Pelapor Kendala Kampus'),
  technician('Teknisi GA & Satpam', 'Petugas Penanganan Tiket'),
  admin('Administrator', 'Pengelola Sistem & Penugasan');

  const UserRole(this.label, this.subtitle);
  final String label;
  final String subtitle;

  bool get isTechnician => this == UserRole.technician;
  bool get isStudent => this == UserRole.student;
  bool get isAdmin => this == UserRole.admin;

  /// Parse role from string (from Custom Claims)
  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return UserRole.student;
      case 'technician':
        return UserRole.technician;
      case 'admin':
        return UserRole.admin;
      default:
        throw ArgumentError('Invalid role: $role');
    }
  }

  /// Convert role to string (for Custom Claims)
  String toClaimValue() {
    switch (this) {
      case UserRole.student:
        return 'student';
      case UserRole.technician:
        return 'technician';
      case UserRole.admin:
        return 'admin';
    }
  }
}
