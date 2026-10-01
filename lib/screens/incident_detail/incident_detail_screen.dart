import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/incident_model.dart';
import '../../models/report_model.dart';
import '../../config/routes.dart';
import '../../providers/incident_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/report_provider.dart';
import '../../repositories/report_repository.dart';
import '../../widgets/campus_ui.dart';
import '../../services/report_photo_codec.dart';

class IncidentDetailScreen extends ConsumerWidget {
  const IncidentDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidentId = ModalRoute.of(context)?.settings.arguments as String?;
    if (incidentId == null) {
      return const Scaffold(
          body: Center(child: Text('Gangguan tidak ditemukan.')));
    }
    final incident = ref.watch(incidentDetailProvider(incidentId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Gangguan',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded)),
      ),
      body: incident.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _IncidentError(),
        data: (value) => value == null
            ? const Center(child: Text('Gangguan tidak ditemukan.'))
            : _IncidentDetails(incident: value),
      ),
    );
  }
}

class _IncidentDetails extends ConsumerWidget {
  const _IncidentDetails({required this.incident});

  final IncidentModel incident;

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    if (incident.category != 'Wifi') {
      await Navigator.pushNamed(
        context,
        AppRoutes.createReport,
        arguments: {
          'locationId': incident.locationId,
          'category': incident.category,
          'quickReport': true,
        },
      );
      return;
    }
    try {
      final result = await ref.read(reportRepositoryProvider).createQuickReport(
            locationId: incident.locationId,
            category: incident.category,
          );
      if (!context.mounted) return;
      final message = switch (result.state) {
        ReportSubmissionState.duplicate =>
          'Anda baru saja melaporkan masalah ini.',
        ReportSubmissionState.processing =>
          'Laporan sedang diproses. Status akan diperbarui otomatis.',
        ReportSubmissionState.processed => 'Laporan berhasil ditambahkan.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Laporan gagal dikirim. Periksa koneksi dan akun Anda.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final reports = ref.watch(incidentReportsProvider(incident.id));
    final locations = ref.watch(locationsProvider);
    var locationName = incident.locationId;
    for (final location in locations.asData?.value ?? []) {
      if (location.id == incident.locationId) {
        locationName = location.name;
        break;
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.primary, const Color(0xFF064A29)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(21),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 51,
                height: 51,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(15)),
                child: Icon(_categoryIcon(incident.category),
                    color: Colors.white, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(incident.category,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          color: Colors.white70, size: 15),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(locationName,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ),
                    ]),
                  ])),
            ]),
            const SizedBox(height: 17),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _HeroPill(
                  icon: Icons.circle,
                  label: incident.status.value,
                  color: Colors.white),
              _HeroPill(
                  icon: Icons.priority_high_rounded,
                  label: incident.severity.value,
                  color: Colors.white),
            ]),
          ]),
        ),
        const SizedBox(height: 13),
        Row(children: [
          Expanded(
              child: _DetailMetric(
                  icon: Icons.people_alt_outlined,
                  value: '${incident.reportCount}',
                  label: 'Laporan mahasiswa')),
          const SizedBox(width: 9),
          Expanded(
              child: _DetailMetric(
                  icon: Icons.update_rounded,
                  value: _timeLabel(incident.lastUpdatedAt),
                  label: 'Pembaruan terakhir')),
        ]),
        const SizedBox(height: 20),
        const SectionTitle('Tentang gangguan'),
        const SizedBox(height: 8),
        _Panel(
          child: Text(
            'Gangguan ${incident.category} ini dilaporkan oleh ${incident.reportCount} mahasiswa di $locationName. Tingkat keparahan dihitung otomatis dari kategori dan jumlah laporan. Status menjadi Selesai otomatis setelah tidak ada laporan baru selama 24 jam.',
            style: TextStyle(color: colors.onSurface, height: 1.5),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _report(context, ref),
          icon: const Icon(Icons.add_alert_outlined),
          label: Text(incident.category == 'Wifi'
              ? 'Saya Juga Mengalami Ini'
              : 'Laporkan dengan bukti foto'),
          style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              textStyle: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 21),
        SectionTitle('Laporan terbaru',
            trailing: Text('${incident.reportCount} TOTAL',
                style: TextStyle(
                    color: colors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5))),
        const SizedBox(height: 9),
        reports.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('Daftar laporan gagal dimuat.'),
          data: (items) => items.isEmpty
              ? const _Panel(child: Text('Belum ada laporan yang ditampilkan.'))
              : Column(
                  children: items
                      .map((report) => Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: _ReportTile(report: report),
                          ))
                      .toList(),
                ),
        ),
      ],
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

class _HeroPill extends StatelessWidget {
  const _HeroPill(
      {required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric(
      {required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline),
      ),
      child: Row(children: [
        Icon(icon, color: colors.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10)),
        ])),
      ]),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});

  final ReportModel report;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor =
        report.status.value == 'Resolved' ? colors.primary : colors.tertiary;
    return ReportSummaryCard(
      icon: Icons.campaign_outlined,
      title: report.category,
      location: report.locationId,
      description: report.description,
      status: report.status.value,
      statusColor: statusColor,
      statusBg: statusColor.withValues(alpha: .12),
      time:
          report.createdAt == null ? 'Diproses' : _timeLabel(report.createdAt!),
      reporter: 'Laporan mahasiswa',
      evidencePhoto: decodeReportPhoto(report.photoUrl),
    );
  }

  String _timeLabel(DateTime date) {
    final elapsed = DateTime.now().difference(date);
    if (elapsed.inMinutes < 1) return 'Baru saja';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} menit lalu';
    if (elapsed.inDays < 1) return '${elapsed.inHours} jam lalu';
    return '${elapsed.inDays} hari lalu';
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(17),
        ),
        child: child,
      );
}

class _IncidentError extends StatelessWidget {
  const _IncidentError();

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('Detail gangguan gagal dimuat.'),
      );
}
