import 'dart:typed_data';

import 'package:flutter/material.dart';

class ReportPhotoViewer {
  static Future<void> show(BuildContext context, Uint8List photo) =>
      showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (context) => _ReportPhotoDialog(photo: photo),
      );
}

class ReportPhotoThumbnail extends StatelessWidget {
  const ReportPhotoThumbnail({super.key, required this.photo});

  final Uint8List photo;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Lihat bukti foto ukuran penuh',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: InkWell(
              onTap: () => ReportPhotoViewer.show(context, photo),
              child: SizedBox(
                width: double.infinity,
                height: 155,
                child: Stack(fit: StackFit.expand, children: [
                  Image.memory(
                    photo,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text('Bukti foto tidak dapat ditampilkan.'),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .68),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.zoom_in_rounded,
                          color: Colors.white, size: 19),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}

class _ReportPhotoDialog extends StatelessWidget {
  const _ReportPhotoDialog({required this.photo});

  final Uint8List photo;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 920,
          maxHeight: size.height * .9,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF111411),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 32,
              offset: Offset(0, 16),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
            child: Row(children: [
              const Icon(Icons.photo_outlined, color: Colors.white70, size: 20),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Bukti foto laporan',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tutup foto',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ]),
          ),
          Expanded(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              boundaryMargin: const EdgeInsets.all(48),
              child: LayoutBuilder(
                builder: (context, constraints) => Image.memory(
                  photo,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Text(
                      'Bukti foto tidak dapat ditampilkan.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 15),
            child: Text(
              'Cubit untuk memperbesar, lalu geser foto untuk melihat detail.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ]),
      ),
    );
  }
}
