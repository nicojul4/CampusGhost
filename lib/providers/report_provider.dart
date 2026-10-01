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
