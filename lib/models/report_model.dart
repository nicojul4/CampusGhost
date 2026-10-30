import '../enums/report_status.dart';
import '../exceptions/api_exception.dart';

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
    this.latitude,
    this.longitude,
    this.locationDetail,
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
  final double? latitude;
  final double? longitude;
  final String? locationDetail;

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('id') || json['id'] is! String || (json['id'] as String).trim().isEmpty) {
      throw const ValidationException('Field "id" wajib diisi dan harus berupa String non-empty.');
    }
    if (!json.containsKey('category') || json['category'] is! String || (json['category'] as String).trim().isEmpty) {
      throw const ValidationException('Field "category" wajib diisi dan harus berupa String non-empty.');
    }
    if (!json.containsKey('description') || json['description'] is! String || (json['description'] as String).trim().isEmpty) {
      throw const ValidationException('Field "description" wajib diisi dan harus berupa String non-empty.');
    }
    if (!json.containsKey('locationId') || json['locationId'] is! String || (json['locationId'] as String).trim().isEmpty) {
      throw const ValidationException('Field "locationId" wajib diisi dan harus berupa String non-empty.');
    }

    final userIdRaw = json['userId'];
    final userId = (userIdRaw is String && userIdRaw.isNotEmpty) ? userIdRaw : 'guest_user';

    final statusRaw = json['status'];
    final ReportStatus status;
    if (statusRaw is String) {
      status = ReportStatus.fromValue(statusRaw);
    } else if (statusRaw == null) {
      status = ReportStatus.active;
    } else {
      throw const ValidationException('Field "status" harus berupa String.');
    }

    DateTime? createdAt;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is String) {
        createdAt = DateTime.tryParse(json['createdAt'] as String);
        if (createdAt == null) {
          throw const ValidationException('Format "createdAt" tidak valid.');
        }
      } else {
        throw const ValidationException('Field "createdAt" harus berupa String format ISO-8601.');
      }
    }

    DateTime? updatedAt;
    if (json['updatedAt'] != null) {
      if (json['updatedAt'] is String) {
        updatedAt = DateTime.tryParse(json['updatedAt'] as String);
        if (updatedAt == null) {
          throw const ValidationException('Format "updatedAt" tidak valid.');
        }
      } else {
        throw const ValidationException('Field "updatedAt" harus berupa String format ISO-8601.');
      }
    }

    final photoUrlRaw = json['photoUrl'];
    if (photoUrlRaw != null && photoUrlRaw is! String) {
      throw const ValidationException('Field "photoUrl" harus berupa String.');
    }

    final incidentIdRaw = json['incidentId'];
    if (incidentIdRaw != null && incidentIdRaw is! String) {
      throw const ValidationException('Field "incidentId" harus berupa String.');
    }

    double? latitude;
    if (json['latitude'] != null) {
      if (json['latitude'] is num) {
        latitude = (json['latitude'] as num).toDouble();
      } else {
        throw const ValidationException('Field "latitude" harus berupa angka desimal.');
      }
    }

    double? longitude;
    if (json['longitude'] != null) {
      if (json['longitude'] is num) {
        longitude = (json['longitude'] as num).toDouble();
      } else {
        throw const ValidationException('Field "longitude" harus berupa angka desimal.');
      }
    }

    final locationDetailRaw = json['locationDetail'];
    if (locationDetailRaw != null && locationDetailRaw is! String) {
      throw const ValidationException('Field "locationDetail" harus berupa String.');
    }

    return ReportModel(
      id: json['id'] as String,
      userId: userId,
      locationId: json['locationId'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      photoUrl: photoUrlRaw as String?,
      status: status,
      incidentId: incidentIdRaw as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
      latitude: latitude,
      longitude: longitude,
      locationDetail: locationDetailRaw as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'locationId': locationId,
        'category': category,
        'description': description,
        'photoUrl': photoUrl,
        'status': status.value,
        'incidentId': incidentId,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (locationDetail != null) 'locationDetail': locationDetail,
      };

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
    double? latitude,
    double? longitude,
    String? locationDetail,
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
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        locationDetail: locationDetail ?? this.locationDetail,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          locationId == other.locationId &&
          category == other.category &&
          description == other.description &&
          status == other.status &&
          photoUrl == other.photoUrl &&
          incidentId == other.incidentId &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          locationDetail == other.locationDetail;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      locationId.hashCode ^
      category.hashCode ^
      description.hashCode ^
      status.hashCode ^
      photoUrl.hashCode ^
      incidentId.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      locationDetail.hashCode;
}
