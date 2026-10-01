import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/incident_model.dart';
import '../repositories/incident_repository.dart';
import 'report_provider.dart';

final incidentRepositoryProvider = Provider<IncidentRepository>(
    (ref) => IncidentRepository(ref.watch(reportRepositoryProvider)));
final incidentsProvider = StreamProvider<List<IncidentModel>>(
    (ref) => ref.watch(incidentRepositoryProvider).watchActive());
final incidentDetailProvider = StreamProvider.family<IncidentModel?, String>(
    (ref, id) => ref.watch(incidentRepositoryProvider).watchById(id));
