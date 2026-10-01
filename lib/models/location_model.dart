class LocationModel {
  const LocationModel({
    required this.id,
    required this.name,
    required this.building,
    required this.floor,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String building;
  final int floor;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
}
