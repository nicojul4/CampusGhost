import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/api_config.dart';
import '../../models/report_model.dart';
import '../../providers/api_report_provider.dart';

class ApiReportsScreen extends ConsumerStatefulWidget {
  const ApiReportsScreen({super.key});

  @override
  ConsumerState<ApiReportsScreen> createState() => _ApiReportsScreenState();
}

class _ApiReportsScreenState extends ConsumerState<ApiReportsScreen> {
  void _openCreateReportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: const _CreateReportFormSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(apiReportsNotifierProvider);
    final notifier = ref.read(apiReportsNotifierProvider.notifier);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Laporan Fasilitas Kampus',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              'Live REST API Vertical Slice',
              style: TextStyle(
                fontSize: 12,
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang data',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: state.status == ApiReportStatus.loading
                ? null
                : () => notifier.fetchReports(),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opsi simulasi server',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'reset_empty') {
                ApiConfig.baseUrl = 'http://127.0.0.1:3000/api?simulate_empty=true';
                notifier.fetchReports();
              } else if (val == 'simulate_500') {
                ApiConfig.baseUrl = 'http://127.0.0.1:3000/api?simulate_error=500';
                notifier.fetchReports();
              } else if (val == 'invalid_port') {
                ApiConfig.baseUrl = 'http://127.0.0.1:3999/api';
                notifier.fetchReports();
              } else {
                ApiConfig.baseUrl = ApiConfig.defaultBaseUrl;
                notifier.fetchReports();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'default',
                child: Text('Normal (Backend Aktif)'),
              ),
              const PopupMenuItem(
                value: 'reset_empty',
                child: Text('Simulasi Data Kosong (Empty)'),
              ),
              const PopupMenuItem(
                value: 'simulate_500',
                child: Text('Simulasi Server Error 500 (Error)'),
              ),
              const PopupMenuItem(
                value: 'invalid_port',
                child: Text('Simulasi Jaringan Putus (Offline)'),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(context, state, notifier),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateReportSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat Laporan'),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ApiReportsState state,
    ApiReportsNotifier notifier,
  ) {
    switch (state.status) {
      case ApiReportStatus.loading:
        return const _LoadingView();
      case ApiReportStatus.empty:
        return _EmptyView(onRefresh: () => notifier.fetchReports());
      case ApiReportStatus.error:
        return _ErrorView(
          errorMessage: state.errorMessage ?? 'Terjadi kesalahan saat memuat data.',
          onRetry: () => notifier.retry(),
        );
      case ApiReportStatus.success:
        return _SuccessView(
          reports: state.reports,
          onRefresh: () => notifier.fetchReports(),
        );
    }
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: colors.primary),
          const SizedBox(height: 18),
          Text(
            'Menghubungkan ke API server...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.18),
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_turned_in_outlined,
                size: 64,
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Belum Ada Laporan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Tidak ada laporan fasilitas kampus saat ini atau database masih kosong. Ketuk tombol di bawah untuk membuat laporan baru.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Muat Ulang'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.errorMessage,
    required this.onRetry,
  });

  final String errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.errorContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 58,
                color: colors.error,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Gagal Memuat Data',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.reports,
    required this.onRefresh,
  });

  final List<ReportModel> reports;
  final Future<void> Function() onRefresh;

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'wifi':
      case 'wi-fi':
        return Icons.wifi_tethering_rounded;
      case 'ac':
        return Icons.ac_unit_rounded;
      case 'proyektor':
        return Icons.videocam_rounded;
      case 'toilet':
        return Icons.wc_rounded;
      case 'lift':
        return Icons.elevator_rounded;
      case 'parkiran':
        return Icons.local_parking_rounded;
      default:
        return Icons.report_problem_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final report = reports[index];
          final isResolved = report.status.value.toLowerCase() == 'resolved';

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.outline.withValues(alpha: 0.5)),
            ),
            color: colors.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getCategoryIcon(report.category),
                          color: colors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.category,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    report.locationId,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colors.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isResolved
                              ? colors.primaryContainer
                              : colors.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          report.status.value,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isResolved
                                ? colors.onPrimaryContainer
                                : colors.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    report.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurface,
                      height: 1.35,
                    ),
                  ),
                  if (report.createdAt != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Dilaporkan pada: ${report.createdAt!.toLocal().toString().substring(0, 16)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CreateReportFormSheet extends ConsumerStatefulWidget {
  const _CreateReportFormSheet();

  @override
  ConsumerState<_CreateReportFormSheet> createState() =>
      _CreateReportFormSheetState();
}

class _CreateReportFormSheetState
    extends ConsumerState<_CreateReportFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'Wifi';
  String _selectedLocation = 'Gedung 1 Lantai 3';
  bool _isLoading = false;

  final List<String> _categories = [
    'Wifi',
    'AC',
    'Proyektor',
    'Toilet',
    'Lift',
    'Parkiran',
    'Lainnya',
  ];

  final List<String> _locations = [
    'Gedung 1 Lantai B',
    'Gedung 1 Lantai GF',
    'Gedung 1 Lantai 1',
    'Gedung 1 Lantai 2',
    'Gedung 1 Lantai 3',
    'Gedung 2 Lantai GF',
    'Gedung 2 Lantai 1',
    'Gedung 2 Lantai 2',
    'Gedung 2 Lantai 3',
    'Perpustakaan Lantai GF',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(apiReportsNotifierProvider.notifier);
      await notifier.addReport(
        category: _selectedCategory,
        locationId: _selectedLocation,
        description: _descriptionController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            content: Text(
              'Laporan "$_selectedCategory" berhasil dikirim ke backend!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text('Gagal mengirim laporan: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Laporkan Masalah Fasilitas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Kategori Fasilitas',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _categories
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedLocation,
              decoration: const InputDecoration(
                labelText: 'Lokasi Kampus',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              items: _locations
                  .map((loc) => DropdownMenuItem(
                        value: loc,
                        child: Text(loc),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedLocation = val);
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Deskripsi Masalah',
                hintText: 'Jelaskan kendala fasilitas yang dialami...',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              maxLines: 3,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Deskripsi wajib diisi.';
                }
                if (val.trim().length < 5) {
                  return 'Deskripsi minimal 5 karakter.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Kirim Laporan',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
