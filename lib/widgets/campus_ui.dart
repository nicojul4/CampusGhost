import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
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
        IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Belum ada notifikasi baru.'))),
            icon: const Icon(Icons.notifications_none_rounded)),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(24),
            child: CircleAvatar(
                radius: 17,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundImage:
                    profilePhoto == null ? null : MemoryImage(profilePhoto),
                child: profilePhoto == null
                    ? Text(initial,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800))
                    : null),
          ),
        ),
      ],
    );
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
      this.onTap});
  final IconData icon;
  final String title, location, description, status, time, reporter;
  final Color statusColor, statusBg;
  final Uint8List? evidencePhoto;
  final VoidCallback? onTap;
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
              ])),
          const SizedBox(width: 6),
          StatusPill(status, color: statusColor, background: statusBg),
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
