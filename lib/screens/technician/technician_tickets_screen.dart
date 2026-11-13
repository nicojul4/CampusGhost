import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../enums/report_status.dart';
import '../../enums/user_role.dart';
import '../../models/report_model.dart';
import '../../providers/technician_tickets_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../services/report_photo_codec.dart';

const campusGreen = Color(0xFF0B6837);

class TechnicianTicketsScreen extends ConsumerStatefulWidget {
  const TechnicianTicketsScreen({super.key});

  @override
  ConsumerState<TechnicianTicketsScreen> createState() =>
      _TechnicianTicketsScreenState();
}

class _TechnicianTicketsScreenState
    extends ConsumerState<TechnicianTicketsScreen> {
  String _statusFilter = 'Semua';
  String? _processingReportId;

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(technicianTicketsProvider);
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
            tooltip: 'Ganti Peran Pengguna',
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: () => _showRoleDialog(context),
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

          final filtered = reports.where((report) {
            if (_statusFilter == 'Menunggu') {
              return report.status == ReportStatus.active;
            }
            if (_statusFilter == 'Sedang Dikerjakan') {
              return report.status == ReportStatus.inProgress;
            }
            if (_statusFilter == 'Selesai') {
              return report.status == ReportStatus.resolved;
            }
            return true;
          }).toList();

          return ListView(
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
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Dikerjakan',
                      count: inProgressCount,
                      color: Colors.blue.shade700,
                      icon: Icons.build_circle_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Selesai',
                      count: resolvedCount,
                      color: campusGreen,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Filter Chips
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
              const SizedBox(height: 16),

              if (filtered.isEmpty)
                _buildEmptyState(context)
              else
                ...filtered.map((report) => _buildTicketCard(context, report)),
            ],
          );
        },
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
                  'Sebagai Teknisi/Satpam, Anda dapat mengubah status penanganan fasilitas kampus.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showRoleDialog(context),
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
  }) {
    return Container(
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
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 54,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: .5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tidak Ada Tiket di Kategori Ini',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Semua laporan fasilitas pada filter "$_statusFilter" sudah tertangani.',
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

  Widget _buildTicketCard(BuildContext context, ReportModel report) {
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

    return Card(
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
                              report.locationId,
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
                    border: Border.all(color: statusColor.withValues(alpha: .4)),
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
              style: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.4),
            ),
            const SizedBox(height: 10),

            // Photo Preview (if available)
            if (photoBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  photoBytes,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Timestamp & Reporter info
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 13, color: colors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  _timeLabel(report.createdAt),
                  style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  'Pelapor: Mahasiswa',
                  style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
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
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
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
    setState(() => _processingReportId = report.id);
    try {
      await ref.read(technicianActionProvider).resolveTicket(report);
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

  void _showRoleDialog(BuildContext context) {
    final currentRole = ref.read(userRoleProvider);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Pilih Peran Pengguna'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.school_rounded, color: campusGreen),
              title: const Text('Mahasiswa / Dosen'),
              subtitle: const Text('Pelapor kendala fasilitas & pemantauan'),
              trailing: currentRole == UserRole.student
                  ? const Icon(Icons.check_circle_rounded, color: campusGreen)
                  : null,
              onTap: () {
                ref
                    .read(userRoleProvider.notifier)
                    .setRole(UserRole.student);
                Navigator.pop(dialogCtx);
              },
            ),
            const Divider(),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.engineering_rounded,
                  color: Colors.amber),
              title: const Text('Teknisi GA & Satpam'),
              subtitle: const Text('Penerima tiket & eksekutor perbaikan'),
              trailing: currentRole == UserRole.technician
                  ? const Icon(Icons.check_circle_rounded, color: campusGreen)
                  : null,
              onTap: () {
                ref
                    .read(userRoleProvider.notifier)
                    .setRole(UserRole.technician);
                Navigator.pop(dialogCtx);
              },
            ),
          ],
        ),
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

  String _timeLabel(DateTime? date) {
    if (date == null) return 'Baru saja';
    final elapsed = DateTime.now().difference(date);
    if (elapsed.inMinutes < 1) return 'Baru saja';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} mnt lalu';
    if (elapsed.inDays < 1) return '${elapsed.inHours} jam lalu';
    return '${elapsed.inDays} hari lalu';
  }
}
