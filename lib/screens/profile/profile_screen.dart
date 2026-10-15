import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/routes.dart';
import '../../enums/report_status.dart';
import '../../models/report_model.dart';
import '../../services/auth_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firebase_provider.dart';
import '../../providers/incident_provider.dart';
import '../../services/report_photo_codec.dart';
import '../../providers/report_provider.dart';
import '../../widgets/campus_ui.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/theme_mode_scope.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await const AuthService().signOut();
    ref.invalidate(reportsProvider);
    ref.invalidate(userReportsProvider);
    ref.invalidate(incidentsProvider);
    ref.invalidate(profilePhotoProvider);
    ref.invalidate(authStateProvider);
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.login, (route) => false);
    }
  }

  Future<void> _editReport(
    BuildContext context,
    WidgetRef ref,
    ReportModel report,
  ) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _EditReportDialog(
        report: report,
        onSave: (description, status) =>
            ref.read(reportRepositoryProvider).updateReport(
                  reportId: report.id,
                  description: description,
                  status: status,
                ),
      ),
    );

    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Laporan ${report.category} berhasil diperbarui.'),
      ));
    }
  }

  Future<void> _deleteReport(
    BuildContext context,
    WidgetRef ref,
    ReportModel report,
  ) async {
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: colors.error, size: 36),
        title: const Text('Hapus Laporan?'),
        content: Text(
          'Laporan "${report.category}" di ${report.locationId} akan dihapus secara permanen dari penyimpanan lokal perangkat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(reportRepositoryProvider).deleteReport(report.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Laporan ${report.category} berhasil dihapus.'),
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gagal menghapus laporan. Silakan coba lagi.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).asData?.value ??
        ref.watch(firebaseAuthProvider).currentUser;
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
            error: (_, __) => TextButton.icon(
              onPressed: () => ref.invalidate(userReportsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Ringkasan gagal dimuat. Coba lagi'),
            ),
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
            error: (_, __) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Riwayat laporan gagal dimuat.'),
                TextButton.icon(
                  onPressed: () => ref.invalidate(userReportsProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba lagi'),
                ),
              ]),
            ),
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
                                onEdit: () => _editReport(context, ref, report),
                                onDelete: () =>
                                    _deleteReport(context, ref, report),
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
          Material(
            color: colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
              side: BorderSide(color: colors.outline),
            ),
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
            onPressed: () => _logout(context, ref),
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

class _EditReportDialog extends StatefulWidget {
  const _EditReportDialog({required this.report, required this.onSave});

  final ReportModel report;
  final Future<void> Function(String description, ReportStatus status) onSave;

  @override
  State<_EditReportDialog> createState() => _EditReportDialogState();
}

class _EditReportDialogState extends State<_EditReportDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  late ReportStatus _selectedStatus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.report.description);
    _selectedStatus = widget.report.status;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.onSave(_controller.text.trim(), _selectedStatus);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gagal memperbarui laporan. Silakan coba lagi.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(children: [
        Icon(Icons.edit_note_rounded, color: colors.primary),
        const SizedBox(width: 8),
        const Text('Edit Laporan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ]),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kategori: ${widget.report.category} • Lokasi: ${widget.report.locationId}',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              const Text('Deskripsi Kendala',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _controller,
                maxLines: 3,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  hintText: 'Jelaskan kendala fasilitas minimal 10 karakter',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 10) {
                    return 'Deskripsi minimal 10 karakter.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const Text('Status Laporan',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              SegmentedButton<ReportStatus>(
                segments: const [
                  ButtonSegment(
                    value: ReportStatus.active,
                    label: Text('Aktif'),
                    icon: Icon(Icons.pending_actions_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: ReportStatus.resolved,
                    label: Text('Selesai'),
                    icon: Icon(Icons.task_alt_rounded, size: 16),
                  ),
                ],
                selected: {_selectedStatus},
                onSelectionChanged: _isSaving
                    ? null
                    : (selection) =>
                        setState(() => _selectedStatus = selection.first),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _submit,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
        ),
      ],
    );
  }
}
