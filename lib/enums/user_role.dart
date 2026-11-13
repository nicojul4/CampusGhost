enum UserRole {
  student('Mahasiswa / Dosen', 'Pelapor Kendala Kampus'),
  technician('Teknisi GA & Satpam', 'Petugas Penanganan Tiket');

  const UserRole(this.label, this.subtitle);
  final String label;
  final String subtitle;

  bool get isTechnician => this == UserRole.technician;
  bool get isStudent => this == UserRole.student;
}
