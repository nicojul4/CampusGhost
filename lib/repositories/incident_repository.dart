import '../enums/facility_severity.dart';
import '../enums/incident_status.dart';
import '../enums/report_status.dart';
import '../models/incident_model.dart';
import 'report_repository.dart';

class IncidentRepository {
  IncidentRepository(this._reportRepository);

  final ReportRepository _reportRepository;

  Stream<List<IncidentModel>> watchActive() async* {
    await for (final reports in _reportRepository.watchCurrentUser()) {
      final groups = <String, List<dynamic>>{};
      for (final report in reports) {
        if (report.status != ReportStatus.active) continue;
        final incidentId = report.incidentId;
        if (incidentId == null) continue;
        (groups[incidentId] ??= []).add(report);
      }
      yield groups.entries.map((entry) {
        final group = entry.value;
        final newest = group
            .map((report) => report.createdAt)
            .whereType<DateTime>()
            .fold<DateTime?>(
                null,
                (latest, date) =>
                    latest == null || date.isAfter(latest) ? date : latest);
        final first = group
            .map((report) => report.createdAt)
            .whereType<DateTime>()
            .fold<DateTime?>(
                null,
                (earliest, date) => earliest == null || date.isBefore(earliest)
                    ? date
                    : earliest);
        final category = group.first.category;
        final weight = switch (category) {
          'Lift' => 3,
          'Ac' || 'Parkir' => 2,
          _ => 1,
        };
        final score = group.length * weight;
        return IncidentModel(
          id: entry.key,
          locationId: group.first.locationId,
          category: category,
          reportCount: group.length,
          status: IncidentStatus.active,
          severity:
              score >= 3 ? FacilitySeverity.critical : FacilitySeverity.warning,
          firstReportedAt: first,
          lastUpdatedAt: newest,
        );
      }).toList()
        ..sort((a, b) => (b.lastUpdatedAt ?? DateTime(0))
            .compareTo(a.lastUpdatedAt ?? DateTime(0)));
    }
  }

  Stream<IncidentModel?> watchById(String id) async* {
    await for (final incidents in watchActive()) {
      IncidentModel? selected;
      for (final incident in incidents) {
        if (incident.id == id) selected = incident;
      }
      yield selected;
    }
  }
}
