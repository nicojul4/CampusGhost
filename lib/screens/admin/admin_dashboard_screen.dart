import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/routes.dart';
import '../../enums/report_status.dart';
import '../../enums/user_role.dart';
import '../../models/admin_models.dart';
import '../../models/notification_model.dart';
import '../../models/report_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/firebase_provider.dart';
import '../../providers/incident_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/technician_tickets_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../widgets/role_switcher_dialog.dart';
import '../../widgets/system_log_viewer_modal.dart';

const _campusGreen = Color(0xFF0B6837);

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final TextEditingController _userSearchCtrl = TextEditingController();
  String _userRoleFilter = 'Semua';
  String _userSearch = '';

  @override
  void dispose() {
    _userSearchCtrl.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(technicianTicketsProvider);
    ref.invalidate(adminUsersProvider);
    ref.invalidate(adminAuditLogsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider);
    final colors = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Panel Administrator',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Kontrol Penuh: ${role.label}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Log Sistem & Tracing',
              icon: const Icon(Icons.terminal_rounded),
              onPressed: () => SystemLogViewerModal.show(context),
            ),
            IconButton(
              tooltip: 'Ganti Peran Pengguna',
              icon: const Icon(Icons.swap_horiz_rounded),
              onPressed: () => showRoleSwitcherDialog(
                context,
                ref,
                fromAdminScreen: true,
              ),
            ),
            IconButton(
              tooltip: 'Segarkan Data',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _refreshAll,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.analytics_outlined), text: 'Pengawasan'),
              Tab(icon: Icon(Icons.people_outline_rounded), text: 'Pengguna'),
              Tab(icon: Icon(Icons.history_edu_rounded), text: 'Audit'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOversightTab(context),
            _buildUsersTab(context),
            _buildAuditTab(context),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (index) {
            if (index == 1) {
              Navigator.pushReplacementNamed(
                  context, AppRoutes.technicianTickets);
            } else if (index == 2) {
              Navigator.pushReplacementNamed(context, AppRoutes.profile);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_rounded),
              label: 'Panel Admin',
            ),
            NavigationDestination(
              icon: Icon(Icons.engineering_rounded),
              label: 'Tiket GA',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 1: PENGAWASAN & PENUGASAN TIKET
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildOversightTab(BuildContext context) {
    final ticketsAsync = ref.watch(technicianTicketsProvider);
    final usersAsync = ref.watch(adminUsersProvider);
    final locations = ref.watch(locationsProvider).asData?.value ?? const [];
    final locMap = {for (final l in locations) l.id: l.name};
    final colors = Theme.of(context).colorScheme;

    return ticketsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Gagal memuat data pengawasan: $err'),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _refreshAll,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
      data: (reports) {
        final total = reports.length;
        final pending =
            reports.where((r) => r.status == ReportStatus.active).length;
        final inProgress =
            reports.where((r) => r.status == ReportStatus.inProgress).length;
        final resolved =
            reports.where((r) => r.status == ReportStatus.resolved).length;
        final rate = total == 0 ? 0 : ((resolved / total) * 100).round();

        final categoryCounts = <String, int>{};
        for (final r in reports) {
          categoryCounts[r.category] = (categoryCounts[r.category] ?? 0) + 1;
        }
        final sortedCategories = categoryCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final technicians = (usersAsync.asData?.value ?? const [])
            .where((u) => u.role == UserRole.technician && u.isActive)
            .toList();

        return RefreshIndicator(
          onRefresh: () async => _refreshAll(),
          child: ListView(
            cacheExtent: 400,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              // Admin Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3A1216), Color(0xFF1F2A22)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings_rounded,
                        color: Colors.redAccent, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pusat Kendali Administrator',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tingkat penyelesaian kampus saat ini: $rate% ($resolved/$total tiket selesai).',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // KPI Row
              Row(
                children: [
                  Expanded(
                    child: _kpiTile(
                        context, 'Total', total, colors.primary, Icons.receipt_long_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _kpiTile(context, 'Menunggu', pending,
                        Colors.amber.shade800, Icons.hourglass_top_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _kpiTile(context, 'Proses', inProgress,
                        Colors.blue.shade700, Icons.build_circle_outlined),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _kpiTile(context, 'Selesai', resolved, _campusGreen,
                        Icons.check_circle_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Top Categories Analytics
              const Text(
                'Distribusi Kendala Fasilitas',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.outline),
                ),
                child: sortedCategories.isEmpty
                    ? Text(
                        'Belum ada data laporan untuk dianalisis.',
                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                      )
                    : Column(
                        children: sortedCategories.take(5).map((entry) {
                          final fraction =
                              total == 0 ? 0.0 : entry.value / total;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(entry.key,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12)),
                                    Text('${entry.value} laporan',
                                        style: TextStyle(
                                            color: colors.onSurfaceVariant,
                                            fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: fraction,
                                    minHeight: 7,
                                    backgroundColor:
                                        colors.surfaceContainerHighest,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 20),

              // Ticket Assignment Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Penugasan & Moderasi Tiket',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(
                        context, AppRoutes.technicianTickets),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Tampilan GA'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (reports.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.outline),
                  ),
                  child: Center(
                    child: Text(
                      'Belum ada laporan fasilitas masuk.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                )
              else
                ...reports.map(
                  (report) => _buildOversightTicketCard(
                    context,
                    report,
                    locationName:
                        locMap[report.locationId] ?? report.locationId,
                    technicians: technicians,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _kpiTile(
    BuildContext context,
    String label,
    int count,
    Color color,
    IconData icon,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: colors.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOversightTicketCard(
    BuildContext context,
    ReportModel report, {
    required String locationName,
    required List<CampusUserSummary> technicians,
  }) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = switch (report.status) {
      ReportStatus.active => Colors.amber.shade800,
      ReportStatus.inProgress => Colors.blue.shade700,
      ReportStatus.resolved => _campusGreen,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${report.category} • $locationName',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report.status.labelIndonesian,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              report.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.engineering_outlined,
                    size: 14, color: colors.primary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    report.assignedTo != null && report.assignedTo!.isNotEmpty
                        ? 'Ditugaskan: ${report.assignedTo}'
                        : 'Belum ditugaskan',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: report.assignedTo != null
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      _showAssignDialog(context, report, technicians),
                  icon: const Icon(Icons.assignment_ind_outlined, size: 16),
                  label: Text(
                    report.assignedTo != null ? 'Ubah Petugas' : 'Tugaskan',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus laporan',
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 19, color: colors.error),
                  onPressed: () => _confirmDeleteTicket(context, report),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAssignDialog(
    BuildContext context,
    ReportModel report,
    List<CampusUserSummary> technicians,
  ) async {
    final customController =
        TextEditingController(text: report.assignedTo ?? '');
    String? chosenTech = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Tugaskan Teknisi GA'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${report.category} • ${report.locationId}',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (technicians.isNotEmpty) ...[
                const Text('Pilih dari Teknisi Terdaftar:',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ...technicians.map(
                  (t) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.engineering_rounded,
                        color: Colors.amber),
                    title: Text(t.displayName),
                    subtitle: Text(t.email, style: const TextStyle(fontSize: 11)),
                    onTap: () => Navigator.pop(dialogCtx, t.displayName),
                  ),
                ),
                const Divider(),
              ],
              const SizedBox(height: 6),
              TextField(
                controller: customController,
                decoration: const InputDecoration(
                  labelText: 'Nama Petugas / Tim GA',
                  hintText: 'Contoh: Pak Budi (Teknisi AC)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, null),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final text = customController.text.trim();
              if (text.isNotEmpty) Navigator.pop(dialogCtx, text);
            },
            child: const Text('Tugaskan'),
          ),
        ],
      ),
    );
    customController.dispose();

    if (chosenTech == null || chosenTech.isEmpty || !mounted) return;
    await ref.read(adminServiceProvider).assignTicket(
          report: report,
          technicianName: chosenTech,
        );
    ref.read(notificationsProvider.notifier).addNotification(
          title: 'Penugasan Baru: ${report.category}',
          message:
              'Administrator menugaskan $chosenTech untuk menangani kendala di ${report.locationId}.',
          category: report.category,
          type: CampusNotificationType.inProgress,
        );
    ref.invalidate(adminAuditLogsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tiket berhasil ditugaskan kepada $chosenTech.'),
        ),
      );
    }
  }

  Future<void> _confirmDeleteTicket(
    BuildContext context,
    ReportModel report,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hapus Laporan?'),
        content: Text(
          'Laporan "${report.category}" di ${report.locationId} akan dihapus permanen oleh Administrator.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(adminServiceProvider).deleteTicket(report);
    ref.invalidate(technicianTicketsProvider);
    ref.invalidate(reportsProvider);
    ref.invalidate(incidentsProvider);
    ref.invalidate(adminAuditLogsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan dihapus oleh Administrator.')),
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 2: MANAJEMEN PENGGUNA & PERAN
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildUsersTab(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final colors = Theme.of(context).colorScheme;

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Gagal memuat pengguna: $err')),
      data: (users) {
        final q = _userSearch.trim().toLowerCase();
        final filtered = users.where((u) {
          if (_userRoleFilter == 'Mahasiswa' && !u.role.isStudent) return false;
          if (_userRoleFilter == 'Teknisi' && !u.role.isTechnician) {
            return false;
          }
          if (_userRoleFilter == 'Admin' && !u.role.isAdmin) return false;
          if (q.isNotEmpty) {
            if (!u.displayName.toLowerCase().contains(q) &&
                !u.email.toLowerCase().contains(q)) {
              return false;
            }
          }
          return true;
        }).toList();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminUsersProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _userSearchCtrl,
                      onChanged: (v) => setState(() => _userSearch = v),
                      decoration: InputDecoration(
                        hintText: 'Cari nama atau email pengguna...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _userSearch.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _userSearchCtrl.clear();
                                  setState(() => _userSearch = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _campusGreen,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    onPressed: () => _showCreateTechnicianDialog(context),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Teknisi'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Semua', 'Mahasiswa', 'Teknisi', 'Admin']
                      .map((label) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              selected: _userRoleFilter == label,
                              label: Text(label),
                              onSelected: (_) =>
                                  setState(() => _userRoleFilter = label),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'Tidak ada pengguna yang cocok.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                )
              else
                ...filtered.map(
                  (u) => _buildUserCard(context, u, isSelf: u.uid == currentUid),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    CampusUserSummary user, {
    required bool isSelf,
  }) {
    final colors = Theme.of(context).colorScheme;
    final roleColor = switch (user.role) {
      UserRole.student => _campusGreen,
      UserRole.technician => Colors.amber.shade800,
      UserRole.admin => Colors.redAccent,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: roleColor.withValues(alpha: 0.15),
                  child: Icon(
                    switch (user.role) {
                      UserRole.student => Icons.school_rounded,
                      UserRole.technician => Icons.engineering_rounded,
                      UserRole.admin => Icons.admin_panel_settings_rounded,
                    },
                    color: roleColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelf) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Anda',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: colors.primary)),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        user.email.isEmpty ? user.uid : user.email,
                        style: TextStyle(
                            fontSize: 12, color: colors.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: user.isActive
                        ? roleColor.withValues(alpha: 0.14)
                        : colors.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.isActive ? user.role.label : 'Nonaktif',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: user.isActive ? roleColor : colors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: isSelf
                      ? null
                      : () => _showChangeUserRoleDialog(context, user),
                  icon: const Icon(Icons.manage_accounts_outlined, size: 16),
                  label: const Text('Ubah Peran', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: isSelf
                      ? null
                      : () => _toggleUserStatus(context, user),
                  icon: Icon(
                    user.isActive
                        ? Icons.person_off_outlined
                        : Icons.person_outline_rounded,
                    size: 16,
                    color: user.isActive ? colors.error : _campusGreen,
                  ),
                  label: Text(
                    user.isActive ? 'Nonaktifkan' : 'Aktifkan',
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelf
                          ? null
                          : (user.isActive ? colors.error : _campusGreen),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateTechnicianDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) => AlertDialog(
          title: const Text('Tambah Akun Teknisi GA'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    enabled: !submitting,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 3)
                            ? 'Nama minimal 3 karakter'
                            : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: emailCtrl,
                    enabled: !submitting,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Kampus / GA',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@'))
                            ? 'Masukkan email yang valid'
                            : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passCtrl,
                    enabled: !submitting,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Kata Sandi Awal',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Kata sandi minimal 6 karakter'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setModalState(() => submitting = true);
                      try {
                        final remote = await ref
                            .read(adminServiceProvider)
                            .createTechnician(
                              displayName: nameCtrl.text,
                              email: emailCtrl.text,
                              password: passCtrl.text,
                            );
                        ref.invalidate(adminUsersProvider);
                        ref.invalidate(adminAuditLogsProvider);
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(remote
                                  ? 'Akun teknisi berhasil dibuat di Firebase.'
                                  : 'Akun teknisi ditambahkan (Mode Preview Lokal).'),
                            ),
                          );
                        }
                      } catch (e) {
                        setModalState(() => submitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal membuat teknisi: $e')),
                          );
                        }
                      }
                    },
              child: Text(submitting ? 'Membuat...' : 'Buat Akun'),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
  }

  Future<void> _showChangeUserRoleDialog(
    BuildContext context,
    CampusUserSummary user,
  ) async {
    UserRole selected = user.role;
    final confirmed = await showDialog<UserRole>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) => AlertDialog(
          title: Text('Ubah Peran: ${user.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: UserRole.values
                .map(
                  (r) => RadioListTile<UserRole>(
                    value: r,
                    groupValue: selected,
                    title: Text(r.label),
                    subtitle: Text(r.subtitle,
                        style: const TextStyle(fontSize: 11)),
                    onChanged: (v) {
                      if (v != null) setModalState(() => selected = v);
                    },
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, selected),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == null || confirmed == user.role || !mounted) return;
    try {
      await ref
          .read(adminServiceProvider)
          .updateUserRole(targetUser: user, newRole: confirmed);
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminAuditLogsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Peran ${user.displayName} diubah menjadi ${confirmed.label}.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah peran: $e')),
        );
      }
    }
  }

  Future<void> _toggleUserStatus(
    BuildContext context,
    CampusUserSummary user,
  ) async {
    final activate = !user.isActive;
    try {
      await ref
          .read(adminServiceProvider)
          .setUserActive(targetUser: user, activate: activate);
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminAuditLogsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(activate
                ? 'Akun ${user.displayName} diaktifkan kembali.'
                : 'Akun ${user.displayName} dinonaktifkan.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui status akun: $e')),
        );
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 3: LOG AUDIT SISTEM
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildAuditTab(BuildContext context) {
    final auditAsync = ref.watch(adminAuditLogsProvider);
    final colors = Theme.of(context).colorScheme;

    return auditAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Gagal memuat log audit: $err')),
      data: (logs) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminAuditLogsProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            OutlinedButton.icon(
              onPressed: () => SystemLogViewerModal.show(context),
              icon: const Icon(Icons.terminal_rounded),
              label: const Text('Buka Log Tracing Runtime Aplikasi'),
            ),
            const SizedBox(height: 12),
            if (logs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history_toggle_off_rounded,
                          size: 48, color: colors.outline),
                      const SizedBox(height: 8),
                      Text(
                        'Belum ada catatan audit administratif.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...logs.map(
                (entry) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colors.outline),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colors.primaryContainer,
                      child: Icon(Icons.verified_user_outlined,
                          size: 18, color: colors.primary),
                    ),
                    title: Text(
                      entry.summary,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Oleh: ${entry.performedBy} • ${_formatTime(entry.timestamp)}',
                      style: TextStyle(
                          fontSize: 11, color: colors.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'Baru saja';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} mnt lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}
