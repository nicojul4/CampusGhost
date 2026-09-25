import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../widgets/primary_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await const AuthService().signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = UserModel.demo;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali ke beranda',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Profil', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFEDEFEB)),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: colors.primaryContainer,
                  child: Text(user.name[0],
                      style: TextStyle(
                          color: colors.primary,
                          fontSize: 30,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 14),
                Text(user.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(user.program,
                    style: TextStyle(color: colors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Informasi akun',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _ProfileInfo(icon: Icons.email_outlined, label: 'Email', value: user.email),
          _ProfileInfo(
              icon: Icons.badge_outlined,
              label: 'Nomor mahasiswa',
              value: user.studentId),
          _ProfileInfo(
              icon: Icons.school_outlined, label: 'Program studi', value: 'Informatika'),
          const SizedBox(height: 25),
          PrimaryButton(
            label: 'Keluar dari akun',
            icon: Icons.logout_rounded,
            onPressed: () => _logout(context),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text('CampusGhost • Prototype v1.0',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    )),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (index) {
          if (index == 0) {
            Navigator.pop(context);
          }
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

class _ProfileInfo extends StatelessWidget {
  const _ProfileInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )),
      subtitle: Text(value,
          style: const TextStyle(fontWeight: FontWeight.w600, height: 1.5)),
    );
  }
}
