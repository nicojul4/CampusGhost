import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../enums/user_role.dart';
import '../models/notification_model.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/user_role_provider.dart';
import 'report_photo_viewer.dart';

const campusGreen = Color(0xFF0B6837);
const campusOrange = Color(0xFFF16E21);
const campusInk = Color(0xFF191D1A);
const campusMuted = Color(0xFF657168);
const campusLine = Color(0xFFE1E8E2);

class CampusHeader extends ConsumerWidget implements PreferredSizeWidget {
  const CampusHeader(
      {super.key, required this.onProfile, this.title = 'CampusGhost'});
  final VoidCallback onProfile;
  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).asData?.value;
    final profilePhoto = ref.watch(profilePhotoProvider).asData?.value;
    final unreadNotifs = ref.watch(unreadNotificationsCountProvider);
    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : user?.email?.split('@').first ?? 'Mahasiswa';
    final initial = name.isEmpty ? 'M' : name[0].toUpperCase();

    return AppBar(
      titleSpacing: 16,
      title: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'web/icons/Ghost Campus Map Pin Icon.png',
            width: 38,
            height: 38,
            fit: BoxFit.cover,
            semanticLabel: 'Logo CampusGhost',
          ),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          Text('Pradita University',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]),
      ]),
      actions: [
        Consumer(
          builder: (context, ref, _) {
            final role = ref.watch(userRoleProvider);
            final isTech = role.isTechnician;
            return IconButton(
              tooltip: 'Peran: ${role.label} (Klik untuk ganti)',
              onPressed: () => _showRoleDialog(context, ref),
              icon: Icon(
                isTech ? Icons.engineering_rounded : Icons.school_outlined,
                color: isTech ? Colors.amber : null,
              ),
            );
          },
        ),
        IconButton(
          tooltip: 'Notifikasi Kampus',
          onPressed: () => _openNotificationsSheet(context),
          icon: Badge(
            isLabelVisible: unreadNotifs > 0,
            label: Text(
              '$unreadNotifs',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: Icon(
              unreadNotifs > 0
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Buka profil',
          onPressed: onProfile,
          icon: CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundImage:
                profilePhoto == null ? null : MemoryImage(profilePhoto),
            child: profilePhoto == null
                ? Text(initial,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800))
                : null,
          ),
        ),
      ],
    );
  }

  void _showRoleDialog(BuildContext context, WidgetRef ref) {
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
              subtitle: const Text('Pelapor kendala fasilitas kampus'),
              trailing: currentRole == UserRole.student
                  ? const Icon(Icons.check_circle_rounded, color: campusGreen)
                  : null,
              enabled: currentRole == UserRole.student,
            ),
            const Divider(),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading:
                  const Icon(Icons.engineering_rounded, color: Colors.amber),
              title: const Text('Teknisi GA & Satpam'),
              subtitle: const Text('Penerima tiket & penanganan perbaikan'),
              trailing: currentRole == UserRole.technician
                  ? const Icon(Icons.check_circle_rounded, color: campusGreen)
                  : null,
              enabled: currentRole == UserRole.technician,
            ),
            const Divider(),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading:
                  const Icon(Icons.admin_panel_settings_rounded, color: Colors.red),
              title: const Text('Administrator'),
              subtitle: const Text('Pengelola sistem & penugasan'),
              trailing: currentRole == UserRole.admin
                  ? const Icon(Icons.check_circle_rounded, color: campusGreen)
                  : null,
              enabled: currentRole == UserRole.admin,
            ),
          ],
        ),
      ),
    );
  }

  void _openNotificationsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => const _CampusNotificationsSheet(),
    );
  }
}

class _CampusNotificationsSheet extends ConsumerWidget {
  const _CampusNotificationsSheet();

  IconData _iconForCategory(String category) => switch (category.toLowerCase()) {
        'wifi' => Icons.wifi_rounded,
        'ac' => Icons.ac_unit_rounded,
        'lift' => Icons.elevator_outlined,
        'toilet' => Icons.wash_outlined,
        'proyektor' => Icons.videocam_outlined,
        'printer' => Icons.print_outlined,
        'parkir' => Icons.local_parking_rounded,
        _ => Icons.campaign_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    final colors = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_active_rounded,
                        color: colors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Notifikasi Kampus',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
                if (notifications.any((n) => !n.isRead))
                  TextButton.icon(
                    onPressed: () => notifier.markAllAsRead(),
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: const Text('Tandai dibaca',
                        style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pembaruan penanganan fasilitas oleh teknisi & satpam kampus',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Expanded(
              child: notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 48, color: colors.onSurfaceVariant),
                          const SizedBox(height: 10),
                          Text(
                            'Belum ada notifikasi baru.',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        final icon = _iconForCategory(item.category);
                        final isUnread = !item.isRead;

                        final statusBadge = switch (item.type) {
                          CampusNotificationType.inProgress => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colors.tertiaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Sedang Dikerjakan',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colors.onTertiaryContainer,
                                ),
                              ),
                            ),
                          CampusNotificationType.resolved => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Selesai',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                            ),
                          CampusNotificationType.info => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Info',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                        };

                        return InkWell(
                          onTap: () => notifier.markAsRead(item.id),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isUnread
                                  ? colors.primaryContainer
                                      .withValues(alpha: 0.25)
                                  : colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isUnread
                                    ? colors.primary.withValues(alpha: 0.3)
                                    : colors.outlineVariant,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: colors.primaryContainer,
                                  child: Icon(icon,
                                      color: colors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: TextStyle(
                                                fontWeight: isUnread
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                fontSize: 13,
                                                color: colors.onSurface,
                                              ),
                                            ),
                                          ),
                                          if (isUnread) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: colors.primary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.message,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.onSurfaceVariant,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          statusBadge,
                                          Text(
                                            _formatTime(item.createdAt),
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface)),
        if (trailing != null) trailing!,
      ]);
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.text,
      {super.key, required this.color, required this.background});
  final String text;
  final Color color;
  final Color background;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

class ReportSummaryCard extends StatelessWidget {
  const ReportSummaryCard(
      {super.key,
      required this.icon,
      required this.title,
      required this.location,
      required this.description,
      required this.status,
      required this.statusColor,
      required this.statusBg,
      required this.time,
      required this.reporter,
      this.evidencePhoto,
      this.coordinates,
      this.onTap,
      this.onEdit,
      this.onDelete});
  final IconData icon;
  final String title, location, description, status, time, reporter;
  final Color statusColor, statusBg;
  final Uint8List? evidencePhoto;
  final String? coordinates;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: campusLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: statusBg, borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: statusColor)),
          const SizedBox(width: 11),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 3),
                Text(location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12)),
                if (coordinates != null && coordinates!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.pin_drop_rounded, size: 12, color: campusGreen),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        coordinates!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: campusGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ]),
                ],
              ])),
          const SizedBox(width: 6),
          StatusPill(status, color: statusColor, background: statusBg),
          if (onEdit != null || onDelete != null) ...[
            const SizedBox(width: 2),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Opsi laporan',
              onSelected: (value) {
                if (value == 'edit' && onEdit != null) onEdit!();
                if (value == 'delete' && onDelete != null) onDelete!();
              },
              itemBuilder: (context) => [
                if (onEdit != null)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Edit laporan'),
                    ]),
                  ),
                if (onDelete != null)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      Text('Hapus laporan',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ]),
                  ),
              ],
            ),
          ],
        ]),
        const SizedBox(height: 11),
        Text(description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.4,
                fontSize: 12)),
        if (evidencePhoto != null) ...[
          const SizedBox(height: 10),
          Text('Bukti foto',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          ReportPhotoThumbnail(photo: evidencePhoto!),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.schedule_rounded,
              size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text('$reporter • $time',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (onTap != null) ...[
            const Spacer(),
            const Text('Lihat detail',
                style: TextStyle(
                    color: campusGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 11)),
            const SizedBox(width: 3),
            const Icon(Icons.chevron_right, size: 16, color: campusGreen),
          ],
        ]),
      ]),
    );
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: onTap == null
          ? card
          : InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: card,
            ),
    );
  }
}

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.label = 'Masuk dengan Akun Google',
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1F2620) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF3E4D41) : const Color(0xFFD3DDD5);
    final textColor =
        isDark ? const Color(0xFFE2EBE3) : const Color(0xFF2E3D31);

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          side: BorderSide(color: borderColor, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          elevation: isDark ? 0 : 0.5,
          shadowColor: const Color(0x10000000),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDark ? Colors.white : campusGreen,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const GoogleLogo(size: 20),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        letterSpacing: .1,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.scale(scale, scale);

    // Blue (#4285F4)
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final bluePath = Path()
      ..moveTo(23.745, 12.27)
      ..cubicTo(23.745, 11.57, 23.685, 10.87, 23.555, 10.2)
      ..lineTo(12.0, 10.2)
      ..lineTo(12.0, 14.71)
      ..lineTo(18.6, 14.71)
      ..cubicTo(18.31, 16.23, 17.46, 17.53, 16.2, 18.39)
      ..lineTo(16.2, 21.44)
      ..lineTo(20.08, 21.44)
      ..cubicTo(22.35, 19.35, 23.745, 16.27, 23.745, 12.27)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Green (#34A853)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    final greenPath = Path()
      ..moveTo(12.0, 24.0)
      ..cubicTo(15.24, 24.0, 17.95, 22.92, 19.93, 21.09)
      ..lineTo(16.05, 18.04)
      ..cubicTo(14.97, 18.76, 13.6, 19.2, 12.0, 19.2)
      ..cubicTo(8.88, 19.2, 6.23, 17.1, 5.28, 14.27)
      ..lineTo(1.25, 14.27)
      ..lineTo(1.25, 17.42)
      ..cubicTo(3.26, 21.36, 7.34, 24.0, 12.0, 24.0)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow (#FBBC05)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final yellowPath = Path()
      ..moveTo(5.28, 14.27)
      ..cubicTo(5.03, 13.55, 4.9, 12.78, 4.9, 12.0)
      ..cubicTo(4.9, 11.22, 5.03, 10.45, 5.28, 9.73)
      ..lineTo(5.28, 6.58)
      ..lineTo(1.25, 6.58)
      ..cubicTo(0.45, 8.18, 0.0, 9.99, 0.0, 12.0)
      ..cubicTo(0.0, 14.01, 0.45, 15.82, 1.25, 17.42)
      ..lineTo(5.28, 14.27)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Red (#EA4335)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final redPath = Path()
      ..moveTo(12.0, 4.75)
      ..cubicTo(13.77, 4.75, 15.35, 5.36, 16.6, 6.55)
      ..lineTo(20.02, 3.13)
      ..cubicTo(17.95, 1.19, 15.24, 0.0, 12.0, 0.0)
      ..cubicTo(7.34, 0.0, 3.26, 2.64, 1.25, 6.58)
      ..lineTo(5.28, 9.73)
      ..cubicTo(6.23, 6.9, 8.88, 4.75, 12.0, 4.75)
      ..close();
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
