import '../enums/report_status.dart';

class ReportModel {
  const ReportModel({
    required this.id,
    required this.userId,
    required this.locationId,
    required this.category,
    required this.description,
    required this.status,
    required this.incidentId,
    required this.createdAt,
    required this.updatedAt,
    this.photoUrl,
  });

  final String id;
  final String userId;
  final String locationId;
  final String category;
  final String description;
  final String? photoUrl;
  final ReportStatus status;
  final String? incidentId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
