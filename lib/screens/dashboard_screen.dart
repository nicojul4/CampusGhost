import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../routes/app_routes.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CampusGhost',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        actions: [
          IconButton(
            tooltip: 'Profil',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
            icon: const CircleAvatar(
              radius: 17,
              backgroundColor: Color(0xFFE4ECE5),
              child: Text('N', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text('Halo, ${UserModel.demo.name.split(' ').first} 👋',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Apa yang perlu dibenahi di kampus hari ini?',
              style: TextStyle(color: colors.onSurfaceVariant)),
          const SizedBox(height: 22),
          _ReportBanner(colors: colors),
          const SizedBox(height: 27),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Laporan terbaru',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              TextButton(onPressed: () {}, child: const Text('Lihat semua')),
            ],
          ),
          const SizedBox(height: 8),
          const _ReportCard(
            icon: Icons.lightbulb_outline_rounded,
            tint: Color(0xFFFFF0D7),
            title: 'Lampu koridor mati',
            location: 'Gedung Fakultas • Lantai 2',
            status: 'Diproses',
            statusColor: Color(0xFFB56C12),
            time: '2 jam lalu',
          ),
          const SizedBox(height: 12),
          const _ReportCard(
            icon: Icons.water_drop_outlined,
            tint: Color(0xFFDCECF5),
            title: 'Keran air bocor',
            location: 'Toilet Perpustakaan',
            status: 'Selesai',
            statusColor: Color(0xFF317353),
            time: 'Kemarin',
          ),
          const SizedBox(height: 12),
          const _ReportCard(
            icon: Icons.chair_alt_outlined,
            tint: Color(0xFFECE3F4),
            title: 'Kursi ruang kelas rusak',
            location: 'Ruang Kuliah B-204',
            status: 'Ditinjau',
            statusColor: Color(0xFF68508B),
            time: '2 hari lalu',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) Navigator.pushNamed(context, AppRoutes.profile);
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
}

class _ReportBanner extends StatelessWidget {
  const _ReportBanner({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.campaign_outlined, color: Colors.white),
          ),
          const SizedBox(height: 17),
          const Text('Ada masalah di kampus?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text('Ceritakan kepada kami. Suaramu membuat perubahan.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.82))),
          const SizedBox(height: 19),
          FilledButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Form laporan akan segera hadir.')),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Buat laporan'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.location,
    required this.status,
    required this.statusColor,
    required this.time,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String location;
  final String status;
  final Color statusColor;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(19),
          side: const BorderSide(color: Color(0xFFEDEFEB))),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration:
                  BoxDecoration(color: tint, borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: const Color(0xFF34423A)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(location,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          )),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                            color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(status,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(time,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
