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

  ReportModel copyWith({
    String? id,
    String? userId,
    String? locationId,
    String? category,
    String? description,
    String? photoUrl,
    ReportStatus? status,
    String? incidentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ReportModel(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        locationId: locationId ?? this.locationId,
        category: category ?? this.category,
        description: description ?? this.description,
        photoUrl: photoUrl ?? this.photoUrl,
        status: status ?? this.status,
        incidentId: incidentId ?? this.incidentId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
