import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report_model.dart';
import '../repositories/report_repository.dart';
import 'auth_provider.dart';
import 'firebase_provider.dart';

final activeUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  return user?.uid ??
      ref.watch(firebaseAuthProvider).currentUser?.uid ??
      'guest_user';
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) =>
    ReportRepository(
        ref.watch(localCampusStoreProvider), ref.watch(firebaseAuthProvider)));
final incidentReportsProvider =
    StreamProvider.family<List<ReportModel>, String>((ref, id) {
  final userId = ref.watch(activeUserIdProvider);
  return ref.watch(reportRepositoryProvider).watchIncident(id, userId);
});
final reportsProvider = StreamProvider<List<ReportModel>>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  return ref.watch(reportRepositoryProvider).watchReportsForUser(userId);
});
final userReportsProvider = StreamProvider<List<ReportModel>>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  return ref.watch(reportRepositoryProvider).watchReportsForUser(userId);
});

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
