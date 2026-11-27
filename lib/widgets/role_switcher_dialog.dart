import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/routes.dart';
import '../enums/user_role.dart';
import '../providers/user_role_provider.dart';

const _campusGreen = Color(0xFF0B6837);

/// Menampilkan dialog pemilihan peran pengguna secara terpusat untuk
/// Mahasiswa/Dosen, Teknisi GA & Satpam, dan Administrator.
Future<void> showRoleSwitcherDialog(
  BuildContext context,
  WidgetRef ref, {
  bool fromTechnicianScreen = false,
  bool fromAdminScreen = false,
}) async {
  final currentRole = ref.read(userRoleProvider);
  final canSwitchToTechnician =
      kDebugMode || currentRole.isTechnician || currentRole.isAdmin;
  final canSwitchToAdmin = kDebugMode || currentRole.isAdmin;

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: Row(
        children: [
          const Expanded(
            child: Text(
              'Pilih Peran Pengguna',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Segarkan peran dari server',
            icon: const Icon(Icons.sync_rounded, size: 20),
            onPressed: () async {
              await ref.read(userRoleProvider.notifier).refreshFromToken();
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              if (context.mounted) {
                final updated = ref.read(userRoleProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Peran disinkronkan: ${updated.label}'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const Icon(Icons.school_rounded, color: _campusGreen),
            title: const Text('Mahasiswa / Dosen'),
            subtitle: const Text('Pelapor kendala fasilitas kampus'),
            trailing: currentRole == UserRole.student
                ? const Icon(Icons.check_circle_rounded, color: _campusGreen)
                : const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () {
              final messenger = ScaffoldMessenger.maybeOf(context);
              Navigator.pop(dialogCtx);
              if (currentRole == UserRole.student) return;
              ref
                  .read(userRoleProvider.notifier)
                  .updateFromClaimValue(UserRole.student.toClaimValue());
              messenger?.clearSnackBars();
              if ((fromTechnicianScreen || fromAdminScreen) && context.mounted) {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
                }
              }
              messenger?.showSnackBar(
                const SnackBar(
                  duration: Duration(seconds: 2),
                  content: Text('Berpindah ke tampilan Mahasiswa / Dosen.'),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading:
                const Icon(Icons.engineering_rounded, color: Colors.amber),
            title: const Text('Teknisi GA & Satpam'),
            subtitle: Text(
              canSwitchToTechnician
                  ? 'Penerima tiket & penanganan perbaikan'
                  : 'Memerlukan akses akun Teknisi GA',
            ),
            trailing: currentRole == UserRole.technician
                ? const Icon(Icons.check_circle_rounded, color: _campusGreen)
                : (canSwitchToTechnician
                    ? const Icon(Icons.arrow_forward_ios_rounded, size: 14)
                    : const Icon(Icons.lock_outline_rounded, size: 16)),
            enabled: canSwitchToTechnician,
            onTap: canSwitchToTechnician
                ? () {
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    final navigator = Navigator.of(context);
                    Navigator.pop(dialogCtx);
                    if (currentRole == UserRole.technician) return;
                    ref
                        .read(userRoleProvider.notifier)
                        .updateFromClaimValue(
                            UserRole.technician.toClaimValue());
                    messenger?.clearSnackBars();
                    if (fromAdminScreen && context.mounted) {
                      navigator.pushReplacementNamed(
                          AppRoutes.technicianTickets);
                    } else if (!fromTechnicianScreen) {
                      messenger?.showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 3),
                          backgroundColor: const Color(0xFF1B2E24),
                          content: const Text(
                            'Mode Teknisi GA & Satpam aktif!',
                            style: TextStyle(color: Colors.white),
                          ),
                          action: SnackBarAction(
                            label: 'Buka Tiket GA',
                            textColor: Colors.amber,
                            onPressed: () {
                              messenger.clearSnackBars();
                              navigator.pushNamed(AppRoutes.technicianTickets);
                            },
                          ),
                        ),
                      );
                    }
                  }
                : null,
          ),
          const Divider(),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.redAccent,
            ),
            title: const Text('Administrator'),
            subtitle: Text(
              canSwitchToAdmin
                  ? 'Pengelola sistem, pengguna & penugasan'
                  : 'Memerlukan akses akun Administrator',
            ),
            trailing: currentRole == UserRole.admin
                ? const Icon(Icons.check_circle_rounded, color: _campusGreen)
                : (canSwitchToAdmin
                    ? const Icon(Icons.arrow_forward_ios_rounded, size: 14)
                    : const Icon(Icons.lock_outline_rounded, size: 16)),
            enabled: canSwitchToAdmin,
            onTap: canSwitchToAdmin
                ? () {
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    final navigator = Navigator.of(context);
                    Navigator.pop(dialogCtx);
                    if (currentRole == UserRole.admin) return;
                    ref
                        .read(userRoleProvider.notifier)
                        .updateFromClaimValue(UserRole.admin.toClaimValue());
                    messenger?.clearSnackBars();
                    if (fromTechnicianScreen && context.mounted) {
                      navigator.pushReplacementNamed(AppRoutes.adminDashboard);
                    } else if (!fromAdminScreen) {
                      messenger?.showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 3),
                          backgroundColor: const Color(0xFF3A1216),
                          content: const Text(
                            'Mode Administrator aktif!',
                            style: TextStyle(color: Colors.white),
                          ),
                          action: SnackBarAction(
                            label: 'Buka Panel Admin',
                            textColor: Colors.redAccent.shade100,
                            onPressed: () {
                              messenger.clearSnackBars();
                              navigator.pushNamed(AppRoutes.adminDashboard);
                            },
                          ),
                        ),
                      );
                    }
                  }
                : null,
          ),
        ],
      ),
    ),
  );
}
