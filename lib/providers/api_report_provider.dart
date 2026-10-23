import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../exceptions/api_exception.dart';
import '../models/report_model.dart';
import '../repositories/report_api_repository.dart';
import '../services/report_api_service.dart';

enum ApiReportStatus { loading, empty, error, success }

class ApiReportsState {
  const ApiReportsState({
    required this.status,
    this.reports = const [],
    this.errorMessage,
    this.isSubmitting = false,
  });

  final ApiReportStatus status;
  final List<ReportModel> reports;
  final String? errorMessage;
  final bool isSubmitting;

  factory ApiReportsState.loading() =>
      const ApiReportsState(status: ApiReportStatus.loading);

  factory ApiReportsState.empty() =>
      const ApiReportsState(status: ApiReportStatus.empty);

  factory ApiReportsState.error(String message) => ApiReportsState(
        status: ApiReportStatus.error,
        errorMessage: message,
      );

  factory ApiReportsState.success(List<ReportModel> reports) =>
      ApiReportsState(
        status: ApiReportStatus.success,
        reports: reports,
      );

  ApiReportsState copyWith({
    ApiReportStatus? status,
    List<ReportModel>? reports,
    String? errorMessage,
    bool? isSubmitting,
  }) {
    return ApiReportsState(
      status: status ?? this.status,
      reports: reports ?? this.reports,
      errorMessage: errorMessage ?? this.errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

final reportApiServiceProvider =
    Provider<ReportApiService>((ref) => ReportApiService());

final reportApiRepositoryProvider = Provider<ReportApiRepository>((ref) {
  final apiService = ref.watch(reportApiServiceProvider);
  return ReportApiRepository(apiService);
});

final apiReportsNotifierProvider =
    NotifierProvider<ApiReportsNotifier, ApiReportsState>(
        ApiReportsNotifier.new);

class ApiReportsNotifier extends Notifier<ApiReportsState> {
  @override
  ApiReportsState build() {
    Future.microtask(() => fetchReports());
    return ApiReportsState.loading();
  }

  Future<void> fetchReports() async {
    state = state.copyWith(status: ApiReportStatus.loading, errorMessage: null);
    try {
      final repository = ref.read(reportApiRepositoryProvider);
      final items = await repository.getReports();
      if (items.isEmpty) {
        state = ApiReportsState.empty();
      } else {
        state = ApiReportsState.success(items);
      }
    } on ApiException catch (e) {
      state = ApiReportsState.error('Gagal memuat laporan (${e.statusCode}): ${e.message}');
    } on NetworkException catch (e) {
      state = ApiReportsState.error('Koneksi bermasalah: ${e.message}');
    } on ValidationException catch (e) {
      state = ApiReportsState.error('Format data tidak valid: ${e.message}');
    } on JsonParsingException catch (e) {
      state = ApiReportsState.error('Gagal membaca data respons: ${e.message}');
    } catch (e) {
      state = ApiReportsState.error('Terjadi kesalahan tidak terduga: $e');
    }
  }

  Future<void> retry() => fetchReports();

  Future<ReportModel> addReport({
    required String category,
    required String locationId,
    required String description,
    String? userId,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final repository = ref.read(reportApiRepositoryProvider);
      final newReport = await repository.createReport(
        category: category,
        locationId: locationId,
        description: description,
        userId: userId,
      );
      await fetchReports();
      return newReport;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }
}
