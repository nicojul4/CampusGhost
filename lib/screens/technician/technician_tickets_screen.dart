import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/routes.dart';
import '../../enums/report_category.dart';
import '../../enums/report_status.dart';
import '../../enums/user_role.dart';
import '../../models/report_model.dart';
import '../../providers/incident_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/technician_tickets_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../services/report_photo_codec.dart';
import '../../widgets/campus_ui.dart';
import '../../widgets/report_photo_viewer.dart';
import '../../widgets/role_switcher_dialog.dart';
import '../../widgets/system_log_viewer_modal.dart';

class TechnicianTicketsScreen extends ConsumerStatefulWidget {
  const TechnicianTicketsScreen({super.key});

  @override
  ConsumerState<TechnicianTicketsScreen> createState() =>
      _TechnicianTicketsScreenState();
}

class _TechnicianTicketsScreenState
    extends ConsumerState<TechnicianTicketsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'Semua';
  String _categoryFilter = 'Semua';
  String _searchQuery = '';
  String? _processingReportId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(technicianTicketsProvider);
    final locations = ref.watch(locationsProvider).asData?.value ?? const [];
    final locationNames = <String, String>{
      for (final loc in locations) loc.id: loc.name,
    };
    final role = ref.watch(userRoleProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tiket Kendala Fasilitas',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Panel Tindakan: ${role.label}',
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
              fromTechnicianScreen: true,
            ),
          ),
          IconButton(
            tooltip: 'Bersihkan Semua Tiket Demo',
            icon: const Icon(Icons.cleaning_services_outlined),
            onPressed: _clearAllDemoTickets,
          ),
          IconButton(
            tooltip: 'Segarkan Tiket',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(technicianTicketsProvider),
          ),
        ],
      ),
      body: ticketsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Gagal memuat tiket: $error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(technicianTicketsProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (reports) {
          final pendingCount = reports
              .where((r) => r.status == ReportStatus.active)
              .length;
          final inProgressCount = reports
              .where((r) => r.status == ReportStatus.inProgress)
              .length;
          final resolvedCount = reports
              .where((r) => r.status == ReportStatus.resolved)
              .length;

          final query = _searchQuery.trim().toLowerCase();
          final filtered = reports.where((report) {
            if (_statusFilter == 'Menunggu' &&
                report.status != ReportStatus.active) {
              return false;
            }
            if (_statusFilter == 'Sedang Dikerjakan' &&
                report.status != ReportStatus.inProgress) {
              return false;
            }
            if (_statusFilter == 'Selesai' &&
                report.status != ReportStatus.resolved) {
              return false;
            }
            if (_categoryFilter != 'Semua' &&
                report.category.toLowerCase() !=
                    _categoryFilter.toLowerCase()) {
              return false;
            }
            if (query.isNotEmpty) {
              final locName =
                  (locationNames[report.locationId] ?? report.locationId)
                      .toLowerCase();
              final desc = report.description.toLowerCase();
              final cat = report.category.toLowerCase();
              final reporter = (report.reporterName ?? '').toLowerCase();
              if (!locName.contains(query) &&
                  !desc.contains(query) &&
                  !cat.contains(query) &&
                  !reporter.contains(query)) {
                return false;
              }
            }
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(technicianTicketsProvider);
              await Future<void>.delayed(const Duration(milliseconds: 300));
            },
            child: ListView(
              cacheExtent: 400,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // Switch Role Banner
                _buildRoleBanner(context, role),
                const SizedBox(height: 14),

                // Summary Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Menunggu',
                        count: pendingCount,
                        color: Colors.amber.shade800,
                        icon: Icons.hourglass_top_rounded,
                        onTap: () => setState(() => _statusFilter = 'Menunggu'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Dikerjakan',
                        count: inProgressCount,
                        color: Colors.blue.shade700,
                        icon: Icons.build_circle_outlined,
                        onTap: () =>
                            setState(() => _statusFilter = 'Sedang Dikerjakan'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Selesai',
                        count: resolvedCount,
                        color: campusGreen,
                        icon: Icons.check_circle_outline_rounded,
                        onTap: () => setState(() => _statusFilter = 'Selesai'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Cari lokasi, kendala, atau pelapor...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            tooltip: 'Hapus pencarian',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      'Semua',
                      'Menunggu',
                      'Sedang Dikerjakan',
                      'Selesai',
                    ].map((filterLabel) {
                      final selected = _statusFilter == filterLabel;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: selected,
                          label: Text(filterLabel),
                          onSelected: (_) =>
                              setState(() => _statusFilter = filterLabel),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      'Semua',
                      ...ReportCategory.values.map((c) => c.value),
                    ].map((categoryLabel) {
                      final selected = _categoryFilter == categoryLabel;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: selected,
                          label: Text(
                            categoryLabel == 'Semua'
                                ? 'Semua Kategori'
                                : categoryLabel,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onSelected: (_) =>
                              setState(() => _categoryFilter = categoryLabel),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                if (filtered.isEmpty)
                  _buildEmptyState(context, totalCount: reports.length)
                else
                  ...filtered.map(
                    (report) => _buildTicketCard(
                      context,
                      report,
                      locationName:
                          locationNames[report.locationId] ?? report.locationId,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: role.isAdmin ? 1 : 0,
        onDestinationSelected: (index) {
          if (role.isAdmin) {
            if (index == 0) {
              Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
            } else if (index == 2) {
              Navigator.pushReplacementNamed(context, AppRoutes.profile);
            }
          } else {
            if (index == 1) {
              Navigator.pushReplacementNamed(context, AppRoutes.profile);
            }
          }
        },
        destinations: role.isAdmin
            ? const [
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
              ]
            : const [
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
    );
  }

  Widget _buildRoleBanner(BuildContext context, UserRole currentRole) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2E24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E4633)),
      ),
      child: Row(
        children: [
          const Icon(Icons.engineering_rounded, color: Colors.amber, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Peran Aktif: ${currentRole.label}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Kelola seluruh antrean tiket fasilitas kampus secara real-time.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => showRoleSwitcherDialog(
              context,
              ref,
              fromTechnicianScreen: true,
            ),
            child: const Text('Ganti Peran'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {required int totalCount}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 54,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: .5),
            ),
            const SizedBox(height: 12),
            Text(
              totalCount == 0
                  ? 'Belum Ada Laporan Masuk'
                  : 'Tidak Ada Tiket yang Cocok',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              totalCount == 0
                  ? 'Laporan fasilitas dari mahasiswa dan dosen akan otomatis muncul di sini.'
                  : 'Coba ubah filter status, kategori, atau kata kunci pencarian.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(
    BuildContext context,
    ReportModel report, {
    required String locationName,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isProcessing = _processingReportId == report.id;
    final statusColor = switch (report.status) {
      ReportStatus.active => Colors.amber.shade800,
      ReportStatus.inProgress => Colors.blue.shade600,
      ReportStatus.resolved => campusGreen,
    };

    final photoBytes = report.photoUrl != null
        ? decodeReportPhoto(report.photoUrl)
        : null;

    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.only(bottom: 14),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: report.status == ReportStatus.inProgress
                ? Colors.blue.shade300
                : colors.outline,
            width: report.status == ReportStatus.inProgress ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category & Status Badge Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _categoryIcon(report.category),
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.category,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 13, color: colors.onSurfaceVariant),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                locationName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: statusColor.withValues(alpha: .4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          report.status.labelIndonesian,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                report.description,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.onSurface,
                  height: 1.4,
                ),
              ),

              // GPS / Location Detail badge (if available)
              if (report.locationDetail != null ||
                  (report.latitude != null && report.longitude != null)) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.gps_fixed_rounded,
                          size: 13, color: colors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          report.locationDetail ??
                              'GPS: ${report.latitude!.toStringAsFixed(5)}, ${report.longitude!.toStringAsFixed(5)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),

              // Photo Preview with zoom (if available)
              if (photoBytes != null) ...[
                ReportPhotoThumbnail(photo: photoBytes),
                const SizedBox(height: 10),
              ],

              // Technician Note Callout (if available)
              if (report.technicianNote != null &&
                  report.technicianNote!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: campusGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: campusGreen.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.assignment_turned_in_outlined,
                          size: 16, color: campusGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Catatan Perbaikan: ${report.technicianNote}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Timestamp, Assigned Technician & Reporter info
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 13, color: colors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        _timeLabel(report.createdAt),
                        style: TextStyle(
                            fontSize: 11, color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 13, color: colors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Pelapor: ${report.reporterName ?? 'Mahasiswa'}',
                        style: TextStyle(
                            fontSize: 11, color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  if (report.assignedTo != null &&
                      report.assignedTo!.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.engineering_outlined,
                            size: 13, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Petugas: ${report.assignedTo}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Action Buttons
              if (isProcessing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else
                Row(
                  children: [
                    if (report.status == ReportStatus.active) ...[
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _handleStartWorking(report),
                          icon: const Icon(Icons.build_rounded, size: 16),
                          label: const Text('Mulai Kerjakan'),
                        ),
                      ),
                    ] else if (report.status == ReportStatus.inProgress) ...[
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: campusGreen,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _handleResolve(report),
                          icon:
                              const Icon(Icons.check_circle_rounded, size: 16),
                          label: const Text('Tandai Selesai'),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _handleReopen(report),
                          icon: const Icon(Icons.replay_rounded, size: 16),
                          label: const Text('Buka Ulang Tiket'),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleStartWorking(ReportModel report) async {
    setState(() => _processingReportId = report.id);
    try {
      await ref.read(technicianActionProvider).startWorking(report);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.blue.shade700,
            content: Text(
              'Tiket "${report.category}" kini statusnya: Sedang Dikerjakan. Mahasiswa mendapatkan notifikasi real-time.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Gagal memperbarui status: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingReportId = null);
    }
  }

  Future<void> _handleResolve(ReportModel report) async {
    final note = await showDialog<String?>(
      context: context,
      builder: (_) => _ResolveTicketDialog(report: report),
    );
    if (note == null || !mounted) return;

    setState(() => _processingReportId = report.id);
    try {
      await ref
          .read(technicianActionProvider)
          .resolveTicket(report, technicianNote: note);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: campusGreen,
            content: Text(
              'Perbaikan berhasil diselesaikan! Notifikasi konfirmasi selesai telah dikirim.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Gagal memperbarui status: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingReportId = null);
    }
  }

  Future<void> _handleReopen(ReportModel report) async {
    setState(() => _processingReportId = report.id);
    try {
      await ref.read(technicianActionProvider).reopenTicket(report);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tiket dibuka kembali untuk pengecekan.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Gagal membuka tiket: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingReportId = null);
    }
  }

  Future<void> _clearAllDemoTickets() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.cleaning_services_rounded,
            color: Colors.deepOrange, size: 34),
        title: const Text('Bersihkan Semua Tiket?'),
        content: const Text(
          'Seluruh laporan di penyimpanan lokal maupun Firestore yang dapat diakses akan dihapus agar demo bisa dimulai dari nol.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(reportRepositoryProvider).clearAllReports();
    ref.read(notificationsProvider.notifier).clearAll();
    ref.invalidate(reportsProvider);
    ref.invalidate(userReportsProvider);
    ref.invalidate(incidentsProvider);
    ref.invalidate(technicianTicketsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Antrean tiket GA sudah bersih total!'),
        ),
      );
    }
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

  String _timeLabel(DateTime? date) {
    if (date == null) return 'Baru saja';
    final elapsed = DateTime.now().difference(date);
    if (elapsed.inMinutes < 1) return 'Baru saja';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} mnt lalu';
    if (elapsed.inDays < 1) return '${elapsed.inHours} jam lalu';
    return '${elapsed.inDays} hari lalu';
  }
}

/// Dialog konfirmasi penyelesaian tiket oleh Teknisi GA dengan catatan perbaikan.
class _ResolveTicketDialog extends StatefulWidget {
  const _ResolveTicketDialog({required this.report});

  final ReportModel report;

  @override
  State<_ResolveTicketDialog> createState() => _ResolveTicketDialogState();
}

class _ResolveTicketDialogState extends State<_ResolveTicketDialog> {
  final TextEditingController _noteController = TextEditingController();

  static const _quickTemplates = [
    'Perbaikan selesai & fasilitas diuji normal.',
    'Komponen rusak sudah diganti.',
    'Jaringan / perangkat telah di-reset & stabil.',
    'Area sudah dibersihkan dan aman digunakan.',
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: campusGreen),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Selesaikan Tiket',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.report.category} • ${widget.report.locationId}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Catatan Perbaikan (Opsional)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Tulis tindakan perbaikan yang sudah dilakukan...',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quickTemplates
                  .map(
                    (tpl) => ActionChip(
                      label: Text(tpl, style: const TextStyle(fontSize: 11)),
                      onPressed: () => setState(() => _noteController.text = tpl),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: campusGreen),
          onPressed: () => Navigator.pop(context, _noteController.text.trim()),
          icon: const Icon(Icons.task_alt_rounded, size: 18),
          label: const Text('Selesaikan'),
        ),
      ],
    );
  }
}
