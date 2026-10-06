import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report_model.dart';
import '../repositories/report_repository.dart';
import 'firebase_provider.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) =>
    ReportRepository(
        ref.watch(localCampusStoreProvider), ref.watch(firebaseAuthProvider)));
final incidentReportsProvider =
    StreamProvider.family<List<ReportModel>, String>(
        (ref, id) => ref.watch(reportRepositoryProvider).watchIncident(id));
final reportsProvider = StreamProvider<List<ReportModel>>(
    (ref) => ref.watch(reportRepositoryProvider).watchAll());
final userReportsProvider = StreamProvider<List<ReportModel>>(
    (ref) => ref.watch(reportRepositoryProvider).watchCurrentUser());

final reportSubmissionProvider =
    AsyncNotifierProvider<ReportSubmissionNotifier, ReportSubmissionResult?>(
        ReportSubmissionNotifier.new);

class ReportSubmissionNotifier extends AsyncNotifier<ReportSubmissionResult?> {
  @override
  Future<ReportSubmissionResult?> build() async => null;

  Future<ReportSubmissionResult> submit({
    required String locationId,
    required String category,
    required String description,
    String? photoUrl,
  }) async {
    if (state.isLoading) {
      throw StateError('submission_in_progress');
    }
    state = const AsyncLoading();
    try {
      final result = await ref.read(reportRepositoryProvider).submitReport(
            locationId: locationId,
            category: category,
            description: description,
            photoUrl: photoUrl,
          );
      state = AsyncData(result);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
