import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/routes.dart';
import '../../services/auth_service.dart';
import '../../providers/auth_provider.dart';
import '../../services/report_photo_codec.dart';
import '../../providers/report_provider.dart';
import '../../widgets/campus_ui.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/theme_mode_scope.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await const AuthService().signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).asData?.value ??
        FirebaseAuth.instance.currentUser;
    final profilePhoto = ref.watch(profilePhotoProvider).asData?.value;
    final reports = ref.watch(userReportsProvider);
    final colors = Theme.of(context).colorScheme;
    final themeMode = ThemeModeScope.of(context);
    final displayName = user?.displayName ?? 'Mahasiswa';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali ke beranda',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title:
            const Text('Profil', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 27, horizontal: 20),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.outline),
            ),
            child: Column(children: [
              CircleAvatar(
                radius: 39,
                backgroundColor: colors.primaryContainer,
                backgroundImage:
                    profilePhoto == null ? null : MemoryImage(profilePhoto),
                child: profilePhoto == null
                    ? Text(
                        displayName.isEmpty
                            ? 'M'
                            : displayName[0].toUpperCase(),
                        style: TextStyle(
                            color: colors.primary,
                            fontSize: 30,
                            fontWeight: FontWeight.w800),
                      )
                    : null,
              ),
              const SizedBox(height: 13),
              Text(displayName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Mahasiswa • CampusGhost',
                  style: TextStyle(color: colors.onSurfaceVariant)),
              const SizedBox(height: 13),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.editProfile),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit profil'),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          const SectionTitle('Ringkasan Kontribusi'),
          const SizedBox(height: 10),
          reports.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Ringkasan gagal dimuat.'),
            data: (items) => Row(children: [
              Expanded(
                  child: _ContributionTile(
                      value: '${items.length}',
                      label: 'Laporan dibuat',
                      icon: Icons.campaign_rounded)),
              const SizedBox(width: 8),
              Expanded(
                  child: _ContributionTile(
                      value:
                          '${items.where((item) => item.status.value == 'Active').length}',
                      label: 'Masih aktif',
                      icon: Icons.pending_actions_rounded)),
              const SizedBox(width: 8),
              Expanded(
                  child: _ContributionTile(
                      value:
                          '${items.where((item) => item.status.value == 'Resolved').length}',
                      label: 'Selesai',
                      icon: Icons.task_alt_rounded)),
            ]),
          ),
          const SizedBox(height: 22),
          const SectionTitle('Riwayat Laporan Saya'),
          const SizedBox(height: 8),
          reports.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Riwayat laporan gagal dimuat.'),
            data: (items) => items.isEmpty
                ? Text('Belum ada laporan yang dibuat.',
                    style: TextStyle(color: colors.onSurfaceVariant))
                : Column(
                    children: items
                        .map((report) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ReportSummaryCard(
                                icon: _categoryIcon(report.category),
                                title: report.category,
                                location: report.locationId,
                                description: report.description,
                                status: report.status.value,
                                statusColor: report.status.value == 'Resolved'
                                    ? colors.primary
                                    : colors.tertiary,
                                statusBg: report.status.value == 'Resolved'
                                    ? colors.primaryContainer
                                    : colors.tertiaryContainer,
                                time: report.createdAt == null
                                    ? 'Sedang diproses'
                                    : _relativeTime(report.createdAt!),
                                reporter: 'Laporan Anda',
                                evidencePhoto:
                                    decodeReportPhoto(report.photoUrl),
                                onTap: () {
                                  final id = report.incidentId;
                                  if (id != null) {
                                    Navigator.pushNamed(
                                        context, AppRoutes.detail,
                                        arguments: id);
                                  }
                                },
                              ),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 21),
          const SectionTitle('Pengaturan'),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: colors.outline)),
            child: SwitchListTile(
              value: themeMode.isDark,
              onChanged: themeMode.onChanged,
              title: const Text('Mode gelap'),
              subtitle: const Text('Sesuaikan tampilan aplikasi'),
              secondary: const Icon(Icons.dark_mode_outlined),
            ),
          ),
          const SizedBox(height: 19),
          _ProfileInfo(
              icon: Icons.email_outlined,
              label: 'Email',
              value: user?.email ?? '-'),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Keluar dari akun',
            icon: Icons.logout_rounded,
            onPressed: () => _logout(context),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text('CampusGhost • Portal Fasilitas Mahasiswa',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: colors.onSurfaceVariant)),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (index) {
          if (index == 0) Navigator.pop(context);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.grid_view_rounded), label: 'Beranda'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded), label: 'Profil'),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) => switch (category) {
        'Lift' => Icons.elevator_outlined,
        'Ac' => Icons.ac_unit_rounded,
        'Toilet' => Icons.wash_outlined,
        'Wifi' => Icons.wifi_rounded,
        'Printer' => Icons.print_outlined,
        'Proyektor' => Icons.videocam_outlined,
        'Parkir' => Icons.local_parking_rounded,
        _ => Icons.build_outlined,
      };

  String _relativeTime(DateTime date) {
    final elapsed = DateTime.now().difference(date);
    if (elapsed.inMinutes < 1) return 'Baru saja';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} menit lalu';
    if (elapsed.inDays < 1) return '${elapsed.inHours} jam lalu';
    return '${elapsed.inDays} hari lalu';
  }
}

class _ContributionTile extends StatelessWidget {
  const _ContributionTile(
      {required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.outline),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: colors.primary, size: 19),
        const SizedBox(height: 7),
        Text(value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10)),
      ]),
    );
  }
}

class _ProfileInfo extends StatelessWidget {
  const _ProfileInfo(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        subtitle: Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600, height: 1.5)),
      );
}
