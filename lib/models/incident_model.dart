import '../enums/facility_severity.dart';
import '../enums/incident_status.dart';

class IncidentModel {
  const IncidentModel({
    required this.id,
    required this.locationId,
    required this.category,
    required this.reportCount,
    required this.status,
    required this.severity,
    required this.firstReportedAt,
    required this.lastUpdatedAt,
  });

  final String id;
  final String locationId;
  final String category;
  final int reportCount;
  final IncidentStatus status;
  final FacilitySeverity severity;
  final DateTime? firstReportedAt;
  final DateTime? lastUpdatedAt;
}
