import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/routes.dart';
import '../../enums/facility_severity.dart';
import '../../enums/report_category.dart';
import '../../models/incident_model.dart';
import '../../models/location_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firebase_provider.dart';
import '../../providers/incident_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../widgets/campus_ui.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _filter = 'Semua';
  bool _welcomeToastShown = false;

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) {
      return 'Selamat Pagi';
    } else if (hour >= 11 && hour < 15) {
      return 'Selamat Siang';
    } else if (hour >= 15 && hour < 18) {
      return 'Selamat Sore';
    } else {
      return 'Selamat Malam';
    }
  }

  String _getTimeEmoji() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) {
      return '☀️';
    } else if (hour >= 11 && hour < 15) {
      return '🌤️';
    } else if (hour >= 15 && hour < 18) {
      return '🌇';
    } else {
      return '🌙';
    }
  }

  void _showCleanWelcomeToast(String name, bool isDark) {
    if (_welcomeToastShown) return;
    _welcomeToastShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      String greetingName = name;
      try {
        final full =
            await ref.read(profileRepositoryProvider).readCurrentDisplayName();
        if (full.trim().isNotEmpty) {
          greetingName = full.trim().split(' ').first;
        }
      } catch (_) {}
      if (!mounted) return;
      ref
          .read(notificationsProvider.notifier)
          .addWelcomeNotification(greetingName);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B2E21) : const Color(0xFF0B6837),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: isDark ? const Color(0xFF2E4633) : const Color(0xFF1B8A4D),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.waving_hand_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selamat Datang, $greetingName!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pantau dan laporkan kondisi fasilitas kampus dengan mudah.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final incidents = ref.watch(incidentsProvider);
    final reports = ref.watch(reportsProvider);
    final locations = ref.watch(locationsProvider);
    final role = ref.watch(userRoleProvider);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authStateProvider).asData?.value ??
        ref.watch(firebaseAuthProvider).currentUser;
    final savedDisplayName =
        ref.watch(profileDisplayNameProvider).asData?.value;
    final fullName = savedDisplayName ??
        user?.displayName ??
        user?.email?.split('@').first ??
        'Mahasiswa';
    final name = fullName.trim().split(' ').first;

    _showCleanWelcomeToast(name, isDark);

    return Scaffold(
      appBar: CampusHeader(
          onProfile: () => Navigator.pushNamed(context, AppRoutes.profile)),
      body: incidents.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _LoadError(
          onRetry: () => ref.invalidate(incidentsProvider),
        ),
        data: (items) {
          final locationNames = <String, String>{
            for (final location in locations.asData?.value ?? [])
              location.id: location.name,
          };
          final visible = _filter == 'Semua'
              ? items
              : items
                  .where((incident) => incident.category == _filter)
                  .toList();
          return ListView(
            cacheExtent: 400,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            children: [
              Text('Halo, ${_getTimeGreeting()}, $name! ${_getTimeEmoji()}',
                  style: TextStyle(
                      color: colors.primary,
                      fontSize: 23,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Pantau kondisi fasilitas kampus hari ini.',
                  style: TextStyle(color: colors.onSurfaceVariant)),
              const SizedBox(height: 17),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E2B21)
                      : const Color(0xFFE7F3EA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2E4633)
                        : const Color(0xFFC8E3D0),
                  ),
                ),
                child: Row(children: [
                  const Icon(Icons.wifi_tethering_rounded,
                      color: campusGreen, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Live Campus Monitoring: Laporan fasilitas tersinkronisasi otomatis untuk seluruh civitas kampus.',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? colors.onSurface
                            : const Color(0xFF183B22),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              reports.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => _StatsRow(
                    reportCount: 0,
                    incidentCount: items.length,
                    criticalCount: _criticalCount(items)),
                data: (reportItems) => _StatsRow(
                    reportCount: reportItems.length,
                    incidentCount: items.length,
                    criticalCount: _criticalCount(items)),
              ),
              const SizedBox(height: 22),
              _ReportBanner(
                onCreate: () =>
                    Navigator.pushNamed(context, AppRoutes.createReport),
              ),
              const SizedBox(height: 23),
              SectionTitle('Peta Kondisi Kampus',
                  trailing: Text('DATA LOKAL',
                      style: TextStyle(
                          color: colors.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5))),
              const SizedBox(height: 9),
              _CampusMap(
                incidents: items,
                locations: locations.asData?.value ?? const [],
              ),
              const SizedBox(height: 8),
              Row(children: [
                _MapLegend(color: colors.primary, label: 'Normal'),
                const SizedBox(width: 16),
                _MapLegend(color: colors.error, label: 'Ada laporan gangguan'),
              ]),
              const SizedBox(height: 21),
              SectionTitle('Gangguan fasilitas',
                  trailing: TextButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.createReport),
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('Buat laporan'),
                  )),
              const SizedBox(height: 7),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    'Semua',
                    ...ReportCategory.values.map((category) => category.value),
                  ]
                      .map((category) => Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: ChoiceChip(
                              label: Text(category),
                              selected: _filter == category,
                              onSelected: (_) =>
                                  setState(() => _filter = category),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 11),
              if (visible.isEmpty)
                const _EmptyIncidents()
              else
                ...visible.map((incident) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _IncidentCard(
                        incident: incident,
                        locationName: locationNames[incident.locationId] ??
                            incident.locationId,
                        onTap: () => Navigator.pushNamed(
                            context, AppRoutes.detail,
                            arguments: incident.id),
                      ),
                    )),
            ],
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (role.isTechnician) {
            if (index == 1) {
              Navigator.pushNamed(context, AppRoutes.technicianTickets);
            } else if (index == 2) {
              Navigator.pushNamed(context, AppRoutes.profile);
            }
          } else if (role.isAdmin) {
            if (index == 1) {
              Navigator.pushNamed(context, AppRoutes.adminDashboard);
            } else if (index == 2) {
              Navigator.pushNamed(context, AppRoutes.profile);
            }
          } else {
            if (index == 1) Navigator.pushNamed(context, AppRoutes.profile);
          }
        },
        destinations: role.isTechnician
            ? const [
                NavigationDestination(
                    icon: Icon(Icons.grid_view_rounded), label: 'Beranda'),
                NavigationDestination(
                    icon: Icon(Icons.engineering_rounded), label: 'Tiket GA'),
                NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded), label: 'Profil'),
              ]
            : role.isAdmin
                ? const [
                    NavigationDestination(
                        icon: Icon(Icons.grid_view_rounded), label: 'Beranda'),
                    NavigationDestination(
                        icon: Icon(Icons.admin_panel_settings_rounded),
                        label: 'Panel Admin'),
                    NavigationDestination(
                        icon: Icon(Icons.person_outline_rounded),
                        label: 'Profil'),
                  ]
                : const [
                    NavigationDestination(
                        icon: Icon(Icons.grid_view_rounded), label: 'Beranda'),
                    NavigationDestination(
                        icon: Icon(Icons.person_outline_rounded),
                        label: 'Profil'),
                  ],
      ),
    );
  }

  int _criticalCount(List<IncidentModel> incidents) => incidents
      .where((incident) => incident.severity == FacilitySeverity.critical)
      .length;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.reportCount,
    required this.incidentCount,
    required this.criticalCount,
  });

  final int reportCount;
  final int incidentCount;
  final int criticalCount;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: _StatTile(
                value: '$reportCount',
                label: 'Laporan masuk',
                icon: Icons.assignment_outlined)),
        const SizedBox(width: 8),
        Expanded(
            child: _StatTile(
                value: '$incidentCount',
                label: 'Gangguan aktif',
                icon: Icons.warning_amber_rounded)),
        const SizedBox(width: 8),
        Expanded(
            child: _StatTile(
                value: '$criticalCount',
                label: 'Kondisi kritis',
                icon: Icons.error_outline_rounded)),
      ]);
}

class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 8, 11),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                color: colors.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10)),
      ]),
    );
  }
}

class _ReportBanner extends StatelessWidget {
  const _ReportBanner({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, const Color(0xFF064A29)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
              color: colors.primary.withValues(alpha: .18),
              blurRadius: 16,
              offset: const Offset(0, 7)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(15)),
          child: const Icon(Icons.campaign_outlined,
              color: Colors.white, size: 25),
        ),
        const SizedBox(width: 13),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ada masalah di kampus?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text('Bantu mahasiswa lain dengan melaporkannya.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .82), fontSize: 11)),
            const SizedBox(height: 11),
            OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Buat laporan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: .7)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded,
            color: Colors.white70, size: 25),
      ]),
    );
  }
}

class _CampusMap extends StatelessWidget {
  const _CampusMap({required this.incidents, required this.locations});

  final List<IncidentModel> incidents;
  final List<LocationModel> locations;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 205,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: colors.outline),
      ),
      child: Stack(children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _MapPatternPainter(
                line: colors.outline.withValues(alpha: .4),
                block: colors.surface),
          ),
        ),
        Positioned(
            left: 22,
            top: 20,
            child: _MapPin(
                color: _locationColor(context, incidents, 'Gedung 1'),
                label: 'Gedung 1')),
        Positioned(
            right: 25,
            top: 20,
            child: _MapPin(
                color: _locationColor(context, incidents, 'Gedung 2'),
                label: 'Gedung 2')),
        Positioned(
            left: 28,
            bottom: 20,
            child: _MapPin(
                color: _locationColor(context, incidents, 'Perpustakaan'),
                label: 'Perpustakaan')),
        Positioned(
            left: 152,
            top: 87,
            child: _MapPin(
                color: _locationColor(context, incidents, 'Kantin'),
                label: 'Kantin')),
        Positioned(
            right: 30,
            bottom: 20,
            child: _MapPin(
                color: _locationColor(context, incidents, 'Parkiran'),
                label: 'Parkiran')),
        Positioned(
            right: 18,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${incidents.length} gangguan',
                  style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            )),
      ]),
    );
  }

  Color _locationColor(
      BuildContext context, List<IncidentModel> items, String building) {
    if (locations.isEmpty) return Theme.of(context).colorScheme.outline;
    final locationIds = locations
        .where((location) => location.building.contains(building))
        .map((location) => location.id)
        .toSet();
    final hasActiveIncident =
        items.any((incident) => locationIds.contains(incident.locationId));
    return hasActiveIncident
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: .25), blurRadius: 8)
              ]),
          child: const Icon(Icons.location_on_rounded,
              color: Colors.white, size: 18),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8)),
          child: Text(label,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
        ),
      ]);
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10)),
        ],
      );
}

class _MapPatternPainter extends CustomPainter {
  const _MapPatternPainter({required this.line, required this.block});

  final Color line;
  final Color block;

  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = line
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(-10, size.height * .75), Offset(size.width * .45, -10), road);
    canvas.drawLine(Offset(size.width * .48, size.height + 5),
        Offset(size.width * .7, -10), road);
    canvas.drawLine(Offset(size.width * .18, size.height * .58),
        Offset(size.width + 12, size.height * .62), road);
    final blocks = Paint()..color = block.withValues(alpha: .75);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .36, 18, 62, 36),
            const Radius.circular(9)),
        blocks);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * .69, size.height * .64, 56, 28),
            const Radius.circular(8)),
        blocks);
  }

  @override
  bool shouldRepaint(covariant _MapPatternPainter oldDelegate) =>
      oldDelegate.line != line || oldDelegate.block != block;
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard(
      {required this.incident,
      required this.locationName,
      required this.onTap});

  final IncidentModel incident;
  final String locationName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final severityColor = switch (incident.severity) {
      FacilitySeverity.critical => colors.error,
      FacilitySeverity.warning => colors.tertiary,
      FacilitySeverity.normal => colors.primary,
    };
    final icon = switch (incident.category) {
      'Lift' => Icons.elevator_outlined,
      'Ac' => Icons.ac_unit_rounded,
      'Toilet' => Icons.wash_outlined,
      'Wifi' => Icons.wifi_rounded,
      'Printer' => Icons.print_outlined,
      'Proyektor' => Icons.videocam_outlined,
      'Parkir' => Icons.local_parking_rounded,
      _ => Icons.build_outlined,
    };
    return ReportSummaryCard(
      icon: icon,
      title: incident.category,
      location: locationName,
      description:
          '${incident.reportCount} laporan mahasiswa mengindikasikan gangguan ini.',
      status: incident.severity.value,
      statusColor: severityColor,
      statusBg: severityColor.withValues(alpha: .12),
      time: incident.lastUpdatedAt == null
          ? 'Baru saja'
          : _relativeTime(incident.lastUpdatedAt!),
      reporter: 'Status ${incident.status.value}',
      onTap: onTap,
    );
  }

  String _relativeTime(DateTime date) {
    final elapsed = DateTime.now().difference(date);
    if (elapsed.inMinutes < 1) return 'Baru saja';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} menit lalu';
    if (elapsed.inDays < 1) return '${elapsed.inHours} jam lalu';
    return '${elapsed.inDays} hari lalu';
  }
}

class _EmptyIncidents extends StatelessWidget {
  const _EmptyIncidents();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 34, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          const Text('Kampus aman! 👻',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text('Belum ada gangguan fasilitas yang aktif.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12)),
        ]),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 38),
            const SizedBox(height: 10),
            const Text('Kondisi kampus gagal dimuat.'),
            TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi')),
          ]),
        ),
      );
}
