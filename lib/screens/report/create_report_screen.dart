import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../enums/report_category.dart';
import '../../providers/location_provider.dart';
import '../../providers/report_provider.dart';
import '../../repositories/report_repository.dart';
import '../../services/camera_photo_service.dart';
import '../../services/location_service.dart';
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
  int? _photoSizeBytes;
  bool _initialArgumentsHandled = false;

  // State Advanced Feature: GPS Lokasi
  bool _isGettingLocation = false;
  CampusCoordinates? _campusCoordinates;
  String? _locationError;

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

  bool get _hasUnsavedChanges =>
      _description.text.trim().isNotEmpty ||
      _photoBytes != null ||
      _campusCoordinates != null;

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 36),
        title: const Text('Buang Laporan?'),
        content: const Text(
          'Data laporan yang sedang Anda isi belum tersimpan dan akan hilang jika keluar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Lanjut Mengisi'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Buang'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  // ===========================================================================
  // ADVANCED FEATURE 2: LOKASI (GPS) & PENANGANAN IZIN
  // ===========================================================================
  Future<void> _fetchGpsCoordinates() async {
    final locationService = ref.read(locationServiceProvider);
    setState(() {
      _isGettingLocation = true;
      _locationError = null;
    });

    try {
      final permStatus = await locationService.checkPermission();

      if (permStatus == LocationPermissionState.serviceDisabled) {
        if (!mounted) return;
        setState(() => _isGettingLocation = false);
        await _showGpsDisabledDialog(locationService);
        return;
      }

      if (permStatus == LocationPermissionState.deniedForever) {
        if (!mounted) return;
        setState(() => _isGettingLocation = false);
        await _showPermissionDeniedForeverDialog(locationService);
        return;
      }

      if (permStatus == LocationPermissionState.denied) {
        final newPerm = await locationService.requestPermission();
        if (newPerm == LocationPermissionState.denied) {
          if (!mounted) return;
          setState(() {
            _isGettingLocation = false;
            _locationError = 'Izin lokasi ditolak. Anda dapat mencoba lagi.';
          });
          _showPermissionDeniedDialog();
          return;
        } else if (newPerm == LocationPermissionState.deniedForever) {
          if (!mounted) return;
          setState(() => _isGettingLocation = false);
          await _showPermissionDeniedForeverDialog(locationService);
          return;
        }
      }

      // Ambil koordinat GPS riil perangkat
      final coords = await locationService.getCurrentCoordinates();
      if (!mounted) return;

      if (coords != null) {
        setState(() {
          _campusCoordinates = coords;
          _isGettingLocation = false;
          _locationError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Koordinat GPS berhasil diperoleh: ${coords.formattedCoordinates}'),
          backgroundColor: campusGreen,
        ));
      } else {
        // Fallback koordinat jika perangkat tidak memiliki sensor GPS aktif
        setState(() {
          _campusCoordinates = locationService.getDefaultCampusCoordinates();
          _isGettingLocation = false;
          _locationError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sinyal GPS lemah, koordinat area Kampus Pradita diterapkan.'),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGettingLocation = false;
        _locationError = 'Gagal membaca GPS: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal mendapatkan lokasi GPS: $e'),
      ));
    }
  }

  Future<void> _showGpsDisabledDialog(LocationService service) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_off_rounded, color: Colors.orange, size: 36),
        title: const Text('Layanan Lokasi (GPS) Non-Aktif'),
        content: const Text(
          'Layanan GPS pada perangkat Anda sedang dimatikan. Aktifkan GPS untuk mendeteksi posisi otomatis atau gunakan titik default kampus.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _campusCoordinates = service.getDefaultCampusCoordinates();
                _locationError = null;
              });
            },
            child: const Text('Pakai Default Kampus'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              service.openLocationSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Buka Pengaturan GPS'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.security_update_warning_rounded, color: Colors.amber, size: 36),
        title: const Text('Izin Lokasi Dibutuhkan'),
        content: const Text(
          'CampusGhost memerlukan izin akses lokasi untuk menandai titik fasilitas kampus secara akurat pada peta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _fetchGpsCoordinates();
            },
            child: const Text('Coba Minta Ulang'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPermissionDeniedForeverDialog(LocationService service) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.block_rounded, color: Colors.red, size: 36),
        title: const Text('Izin Lokasi Ditolak Permanen'),
        content: const Text(
          'Izin lokasi telah ditolak secara permanen. Anda dapat mengaktifkannya melalui Pengaturan Aplikasi atau melanjutkan dengan titik default kampus.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _campusCoordinates = service.getDefaultCampusCoordinates();
                _locationError = null;
              });
            },
            child: const Text('Gunakan Default Kampus'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              service.openAppSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ADVANCED FEATURE 3: KAMERA / FOTO & BOTTOM SHEET PEMILIH
  // ===========================================================================
  Future<void> _showPhotoPickerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Lampirkan Bukti Foto Fasilitas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ambil langsung dengan kamera atau unggah dari galeri dokumen.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: campusGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: campusGreen),
                ),
                title: const Text('Ambil Foto Kamera', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Potret langsung kondisi fasilitas saat ini'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _capturePhoto(PhotoSource.camera);
                },
              ),
              const Divider(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.blue),
                ),
                title: const Text('Pilih dari Galeri / Dokumen', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Pilih foto tersimpan dari galeri atau berkas'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _capturePhoto(PhotoSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _capturePhoto(PhotoSource source) async {
    final photoService = ref.read(cameraPhotoServiceProvider);
    try {
      final result = await photoService.pickPhoto(source: source);
      // User membatalkan pemilihan kamera/galeri tanpa memilih
      if (result == null) return;

      setState(() {
        _photoBytes = result.bytes;
        _photoMimeType = result.mimeType;
        _photoSizeBytes = result.fileSizeBytes;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Foto berhasil ditambahkan (${(result.fileSizeBytes / 1024).toStringAsFixed(0)} KB)'),
          backgroundColor: campusGreen,
        ));
      }
    } on PhotoPermissionDeniedException {
      if (mounted) await _showCameraPermissionDialog(source);
    } on PhotoSizeLimitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ));
      }
    } on UnsupportedPhotoFormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal mengambil foto: $e'),
        ));
      }
    }
  }

  Future<void> _showCameraPermissionDialog(PhotoSource source) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.no_photography_outlined, color: Colors.orange),
        title: const Text('Izin Kamera Ditolak'),
        content: const Text(
          'Izinkan akses kamera untuk mengambil bukti foto. Jika izin pernah ditolak permanen, aktifkan dari pengaturan aplikasi. Anda tetap dapat memilih foto dari galeri.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Pilih Galeri'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(locationServiceProvider).openAppSettings();
            },
            child: const Text('Buka Pengaturan'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _capturePhoto(source);
            },
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  void _removePhoto() {
    setState(() {
      _photoBytes = null;
      _photoMimeType = null;
      _photoSizeBytes = null;
    });
  }

  // ===========================================================================
  // SUBMIT LAPORAN DENGAN VALIDASI LENGKAP & DOUBLE-SUBMIT GUARD
  // ===========================================================================
  Future<void> _submit() async {
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pilih kategori fasilitas terlebih dahulu.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    if (_category != ReportCategory.wifi && _photoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tambahkan bukti foto untuk kategori ini (Wajib).'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    if (!_formKey.currentState!.validate() ||
        ref.read(reportSubmissionProvider).isLoading) {
      return;
    }

    try {
      final locationDetail = _campusCoordinates != null
          ? '${_campusCoordinates!.campusBuilding ?? "Kampus Pradita"} (GPS: ${_campusCoordinates!.formattedCoordinates})'
          : null;

      final result = await ref.read(reportSubmissionProvider.notifier).submit(
            locationId: _locationId!,
            category: _category!.value,
            description: _description.text.trim(),
            photoUrl: _photoBytes == null
                ? null
                : encodeReportPhoto(_photoBytes!, _photoMimeType!),
            latitude: _campusCoordinates?.latitude,
            longitude: _campusCoordinates?.longitude,
            locationDetail: locationDetail,
          );

      if (!mounted) return;

      final message = switch (result.state) {
        ReportSubmissionState.duplicate =>
          'Anda baru saja melaporkan masalah ini dalam 5 menit terakhir.',
        ReportSubmissionState.processing =>
          'Laporan sedang diproses. Status akan diperbarui otomatis.',
        ReportSubmissionState.processed =>
          'Laporan berhasil dikirim dan tersimpan secara persisten!',
      };

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            result.state == ReportSubmissionState.duplicate
                ? Icons.hourglass_top_rounded
                : Icons.check_circle_rounded,
            color: result.state == ReportSubmissionState.duplicate
                ? Colors.amber
                : campusGreen,
            size: 40,
          ),
          title: Text(result.state == ReportSubmissionState.duplicate
              ? 'Laporan Duplikat'
              : 'Laporan Terkirim'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context); // Kembali ke dashboard
              },
              child: const Text('OK, Selesai'),
            ),
          ],
        ),
      );
    } on RequiredReportPhotoException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tambahkan bukti foto untuk kategori ini.'),
          backgroundColor: Colors.red,
        ));
      }
    } on InvalidReportPhotoException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bukti foto tidak valid. Pilih file gambar kembali.'),
          backgroundColor: Colors.red,
        ));
      }
    } on LocalPhotoStorageLimitException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Penyimpanan bukti foto akun ini penuh (maks 3 MB).'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Laporan gagal disimpan: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(locationsProvider);
    final submission = ref.watch(reportSubmissionProvider);
    final isSubmitting = submission.isLoading;
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscardChanges();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              final shouldPop = await _confirmDiscardChanges();
              if (shouldPop && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text('Buat Laporan Fasilitas', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: locations.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Lokasi fasilitas kampus gagal dimuat.'),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => ref.invalidate(locationsProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
              ),
            ]),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_city_rounded, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('Belum ada lokasi kampus terdaftar.'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => ref.invalidate(locationsProvider),
                      child: const Text('Muat Ulang'),
                    ),
                  ],
                ),
              );
            }
            _locationId ??= items.first.id;

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Text(
                    'Bantu kami menjaga kenyamanan dan kelayakan fasilitas Pradita University.',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // 1. KATEGORI FASILITAS
                  const SectionTitle('1. Pilih Kategori Fasilitas'),
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
                      return InkWell(
                        onTap: isSubmitting ? null : () => setState(() => _category = category),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          decoration: BoxDecoration(
                            color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? colors.primary : colors.outline,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(children: [
                            Icon(
                              _categoryIcon(category),
                              size: 20,
                              color: selected ? colors.primary : colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                category.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? colors.primary : colors.onSurface,
                                ),
                              ),
                            ),
                            if (selected)
                              Icon(Icons.check_circle, size: 16, color: colors.primary),
                          ]),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // 2. LOKASI KAMPUS & GPS
                  const SectionTitle('2. Lokasi Kampus & Koordinat GPS'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: items.any((item) => item.id == _locationId)
                        ? _locationId
                        : items.first.id,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.business_rounded),
                      hintText: 'Pilih lokasi / gedung kampus',
                    ),
                    items: items
                        .map((location) => DropdownMenuItem(
                              value: location.id,
                              child: Text(location.name),
                            ))
                        .toList(),
                    onChanged: isSubmitting
                        ? null
                        : (value) => setState(() => _locationId = value),
                    validator: (value) => value == null ? 'Pilih lokasi kampus' : null,
                  ),
                  const SizedBox(height: 10),

                  // GPS COORDINATES CARD / BUTTON
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _campusCoordinates != null ? campusGreen : colors.outline,
                        width: _campusCoordinates != null ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.gps_fixed_rounded,
                              size: 18,
                              color: _campusCoordinates != null ? campusGreen : colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Koordinat GPS Fasilitas',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                            if (_isGettingLocation)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else if (_campusCoordinates != null)
                              IconButton(
                                tooltip: 'Hapus koordinat GPS',
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: isSubmitting ? null : () => setState(() => _campusCoordinates = null),
                              ),
                          ],
                        ),
                        if (_campusCoordinates != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: campusGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.pin_drop_rounded, size: 14, color: campusGreen),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Lat: ${_campusCoordinates!.latitude.toStringAsFixed(6)}, Lng: ${_campusCoordinates!.longitude.toStringAsFixed(6)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: campusGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_campusCoordinates!.campusBuilding != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    _campusCoordinates!.campusBuilding!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 6),
                          Text(
                            'Deteksi koordinat satelit otomatis saat Anda berada di lokasi gangguan.',
                            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: (isSubmitting || _isGettingLocation)
                              ? null
                              : _fetchGpsCoordinates,
                          icon: Icon(
                            _campusCoordinates == null
                                ? Icons.my_location_rounded
                                : Icons.refresh_rounded,
                            size: 16,
                          ),
                          label: Text(
                            _isGettingLocation
                                ? 'Mencari Koordinat GPS...'
                                : (_campusCoordinates == null
                                    ? 'Ambil Koordinat GPS Sekarang'
                                    : 'Perbarui Koordinat GPS'),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        if (_locationError != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _locationError!,
                            style: const TextStyle(color: Colors.red, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. JELASKAN KENDALA
                  const SectionTitle('3. Jelaskan Kendala'),
                  const SizedBox(height: 7),
                  TextFormField(
                    controller: _description,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    enabled: !isSubmitting,
                    decoration: const InputDecoration(
                      filled: true,
                      alignLabelWithHint: true,
                      hintText: 'Contoh: Wi-Fi sering terputus di area meja belajar lantai 3 dekat lift...',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Deskripsi kendala wajib diisi.';
                      }
                      if (value.trim().length < 10) {
                        return 'Jelaskan kendala minimal 10 karakter.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 4. BUKTI FOTO (KAMERA / GALERI)
                  SectionTitle(
                    '4. Bukti Foto Fasilitas${_category == ReportCategory.wifi ? ' (Opsional)' : ' (Wajib)'}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _category == ReportCategory.wifi
                        ? 'Screenshot sinyal Wi-Fi opsional. Maks 1 MB per file.'
                        : 'Lampirkan foto kondisi nyata fasilitas rusak/terkendala. Maks 1 MB.',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                  ),
                  const SizedBox(height: 10),

                  if (_photoBytes == null)
                    OutlinedButton.icon(
                      onPressed: isSubmitting ? null : _showPhotoPickerSheet,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Ambil Foto Kamera / Unggah Galeri'),
                    )
                  else ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Image.memory(
                            _photoBytes!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                          Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              tooltip: 'Hapus foto',
                              onPressed: isSubmitting ? null : _removePhoto,
                              icon: const Icon(Icons.close_rounded, color: Colors.white),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_photoSizeBytes != null ? (_photoSizeBytes! / 1024).toStringAsFixed(0) : 0} KB • ${_photoMimeType ?? 'image'}',
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: isSubmitting ? null : _showPhotoPickerSheet,
                      icon: const Icon(Icons.change_circle_outlined, size: 18),
                      label: const Text('Ganti Foto Lain'),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // SUBMIT BUTTON
                  PrimaryButton(
                    onPressed: isSubmitting ? null : _submit,
                    isLoading: isSubmitting,
                    icon: Icons.send_rounded,
                    label: isSubmitting ? 'Mengirim Laporan...' : 'Kirim Laporan Fasilitas',
                  ),
                ],
              ),
            );
          },
        ),
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
