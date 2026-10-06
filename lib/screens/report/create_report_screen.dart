import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../enums/report_category.dart';
import '../../providers/location_provider.dart';
import '../../providers/report_provider.dart';
import '../../repositories/report_repository.dart';
import '../../services/report_photo_codec.dart';
import '../../widgets/campus_ui.dart';
import '../../widgets/primary_button.dart';

class CreateReportScreen extends ConsumerStatefulWidget {
  const CreateReportScreen({super.key});

  @override
  ConsumerState<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends ConsumerState<CreateReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  String? _locationId;
  ReportCategory? _category;
  Uint8List? _photoBytes;
  String? _photoMimeType;
  bool _initialArgumentsHandled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialArgumentsHandled) return;
    _initialArgumentsHandled = true;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is! Map) return;
    _locationId = arguments['locationId'] as String?;
    final categoryValue = arguments['category'] as String?;
    for (final category in ReportCategory.values) {
      if (category.value == categoryValue) _category = category;
    }
    if (arguments['quickReport'] == true) {
      _description.text = 'Saya juga mengalami masalah ini.';
    }
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Foto atau screenshot',
            extensions: ['jpg', 'jpeg', 'png', 'webp'],
          ),
        ],
      );
      if (file == null) return;
      if (await file.length() > maxReportPhotoBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ukuran foto maksimal 1 MB.'),
        ));
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > maxReportPhotoBytes) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ukuran foto maksimal 1 MB.'),
        ));
        return;
      }
      final mimeType = detectReportPhotoMimeType(bytes);
      if (mimeType == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pilih file gambar JPG, PNG, atau WebP yang valid.'),
        ));
        return;
      }
      setState(() {
        _photoBytes = bytes;
        _photoMimeType = mimeType;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Foto tidak dapat dibaca. Silakan pilih ulang.'),
      ));
    }
  }

  void _removePhoto() => setState(() {
        _photoBytes = null;
        _photoMimeType = null;
      });

  Future<void> _submit() async {
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pilih kategori fasilitas terlebih dahulu.'),
      ));
      return;
    }
    if (_category != ReportCategory.wifi && _photoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tambahkan bukti foto untuk kategori ini.'),
      ));
      return;
    }
    if (!_formKey.currentState!.validate() ||
        ref.read(reportSubmissionProvider).isLoading) {
      return;
    }
    try {
      final result = await ref.read(reportSubmissionProvider.notifier).submit(
            locationId: _locationId!,
            category: _category!.value,
            description: _description.text.trim(),
            photoUrl: _photoBytes == null
                ? null
                : encodeReportPhoto(_photoBytes!, _photoMimeType!),
          );
      if (!mounted) return;
      final message = switch (result.state) {
        ReportSubmissionState.duplicate =>
          'Anda baru saja melaporkan masalah ini.',
        ReportSubmissionState.processing =>
          'Laporan sedang diproses. Status akan diperbarui otomatis.',
        ReportSubmissionState.processed => 'Laporan berhasil dibuat.',
      };
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.hourglass_top_rounded),
          title: Text(result.state == ReportSubmissionState.duplicate
              ? 'Laporan belum dikirim'
              : 'Laporan dikirim'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: const Text('Kembali'),
            ),
          ],
        ),
      );
    } on RequiredReportPhotoException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tambahkan bukti foto untuk kategori ini.'),
        ));
      }
    } on InvalidReportPhotoException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bukti foto tidak valid. Pilih file gambar kembali.'),
        ));
      }
    } on LocalPhotoStorageLimitException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Penyimpanan bukti foto akun ini penuh. Hapus data aplikasi atau gunakan foto yang lebih kecil.'),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Laporan gagal disimpan. Silakan coba kembali.')));
      }
    } finally {}
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(locationsProvider);
    final submission = ref.watch(reportSubmissionProvider);
    final isSubmitting = submission.isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Buat laporan')),
      body: locations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Lokasi gagal dimuat.'),
            TextButton.icon(
              onPressed: () => ref.invalidate(locationsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ]),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Belum ada lokasi terdaftar.'));
          }
          _locationId ??= items.first.id;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Text('Bantu kami menjaga kampus tetap nyaman.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13)),
                const SizedBox(height: 20),
                const SectionTitle('Pilih kategori fasilitas'),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ReportCategory.values.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 9,
                    crossAxisSpacing: 9,
                    childAspectRatio: 2.7,
                  ),
                  itemBuilder: (context, index) {
                    final category = ReportCategory.values[index];
                    final selected = _category == category;
                    final colors = Theme.of(context).colorScheme;
                    return InkWell(
                      onTap: () => setState(() => _category = category),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        decoration: BoxDecoration(
                          color: selected
                              ? colors.primaryContainer
                              : colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? colors.primary : colors.outline,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(children: [
                          Icon(_categoryIcon(category),
                              size: 20,
                              color: selected
                                  ? colors.primary
                                  : colors.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(category.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? colors.primary
                                      : colors.onSurface,
                                )),
                          ),
                          if (selected)
                            Icon(Icons.check_circle,
                                size: 16, color: colors.primary),
                        ]),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 19),
                const SectionTitle('Lokasi fasilitas'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: items.any((item) => item.id == _locationId)
                      ? _locationId
                      : null,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on_outlined),
                    hintText: 'Pilih lokasi kampus',
                  ),
                  items: items
                      .map((location) => DropdownMenuItem(
                            value: location.id,
                            child: Text(location.name),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _locationId = value),
                  validator: (value) => value == null ? 'Pilih lokasi' : null,
                ),
                const SizedBox(height: 17),
                const SectionTitle('Jelaskan kendala'),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 6,
                  maxLength: 500,
                  decoration: const InputDecoration(
                      filled: true,
                      alignLabelWithHint: true,
                      hintText: 'Jelaskan kendala secara singkat dan jelas...'),
                  validator: (value) =>
                      value == null || value.trim().length < 10
                          ? 'Jelaskan kendala minimal 10 karakter'
                          : null,
                ),
                const SizedBox(height: 17),
                SectionTitle(
                    'Bukti foto${_category == ReportCategory.wifi ? ' (opsional)' : ' (wajib)'}'),
                const SizedBox(height: 6),
                Text(
                  _category == ReportCategory.wifi
                      ? 'Screenshot WiFi opsional. Batas foto 1 MB per file dan 3 MB total untuk akun ini.'
                      : 'Lampirkan foto kondisi fasilitas. Maksimal 1 MB per foto, 3 MB total untuk akun ini.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 9),
                OutlinedButton.icon(
                  onPressed: isSubmitting ? null : _pickPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(_photoBytes == null
                      ? 'Pilih foto atau screenshot'
                      : 'Ganti bukti foto'),
                ),
                if (_photoBytes != null) ...[
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(alignment: Alignment.topRight, children: [
                      Image.memory(
                        _photoBytes!,
                        width: double.infinity,
                        height: 190,
                        fit: BoxFit.cover,
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Hapus foto',
                        onPressed: _removePhoto,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 18),
                PrimaryButton(
                  onPressed: isSubmitting ? null : _submit,
                  isLoading: isSubmitting,
                  icon: Icons.send_rounded,
                  label:
                      isSubmitting ? 'Mengirim...' : 'Kirim Laporan Fasilitas',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _categoryIcon(ReportCategory category) => switch (category) {
        ReportCategory.lift => Icons.elevator_outlined,
        ReportCategory.ac => Icons.ac_unit_rounded,
        ReportCategory.toilet => Icons.wash_outlined,
        ReportCategory.wifi => Icons.wifi_rounded,
        ReportCategory.printer => Icons.print_outlined,
        ReportCategory.proyektor => Icons.videocam_outlined,
        ReportCategory.parkir => Icons.local_parking_rounded,
        ReportCategory.lainnya => Icons.build_outlined,
      };
}
