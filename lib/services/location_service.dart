import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationPermissionState {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  unavailable,
}

class CampusCoordinates {
  const CampusCoordinates({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.campusBuilding,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;
  final String? campusBuilding;
  final DateTime timestamp;

  String get formattedCoordinates =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

/// Service untuk menangani geolokasi GPS dengan penanganan izin lengkap
/// (granted, denied, deniedForever, serviceDisabled).
class LocationService {
  const LocationService();

  // Koordinat Utama Kampus Pradita University (Gading Serpong)
  static const double praditaLat = -6.2607827;
  static const double praditaLng = 106.6184306;

  /// Memeriksa status izin lokasi saat ini
  Future<LocationPermissionState> checkPermission() async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        return LocationPermissionState.serviceDisabled;
      }
      final permission = await Geolocator.checkPermission();
      return _mapPermission(permission);
    } catch (e) {
      debugPrint('LocationService checkPermission error: $e');
      return LocationPermissionState.unavailable;
    }
  }

  /// Meminta izin akses lokasi kepada pengguna
  Future<LocationPermissionState> requestPermission() async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        return LocationPermissionState.serviceDisabled;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return _mapPermission(permission);
    } catch (e) {
      debugPrint('LocationService requestPermission error: $e');
      return LocationPermissionState.unavailable;
    }
  }

  /// Mengambil koordinat GPS terkini dengan timeout dan penanganan platform
  Future<CampusCoordinates?> getCurrentCoordinates({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final permissionState = await requestPermission();
      if (permissionState != LocationPermissionState.granted) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final building = matchCampusBuilding(position.latitude, position.longitude);

      return CampusCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        campusBuilding: building,
        timestamp: position.timestamp,
      );
    } catch (e) {
      debugPrint('LocationService getCurrentCoordinates error: $e');
      // Coba ambil last known position jika timeout atau gagal
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return CampusCoordinates(
            latitude: lastKnown.latitude,
            longitude: lastKnown.longitude,
            accuracy: lastKnown.accuracy,
            campusBuilding: matchCampusBuilding(lastKnown.latitude, lastKnown.longitude),
            timestamp: lastKnown.timestamp,
          );
        }
      } catch (_) {}
      return null;
    }
  }

  /// Koordinat default kampus jika pengguna memilih fallback manual
  CampusCoordinates getDefaultCampusCoordinates() => CampusCoordinates(
        latitude: praditaLat,
        longitude: praditaLng,
        accuracy: 5.0,
        campusBuilding: 'Area Kampus Pradita University',
        timestamp: DateTime.now(),
      );

  /// Mencocokkan koordinat dengan gedung / area kampus terdekat
  String matchCampusBuilding(double lat, double lng) {
    final distanceMeters = Geolocator.distanceBetween(
      praditaLat,
      praditaLng,
      lat,
      lng,
    );

    if (distanceMeters <= 250) {
      return 'Kawasan Pradita University (Gedung 1 & 2)';
    } else if (distanceMeters <= 1000) {
      return 'Sekitar Kampus Pradita (${distanceMeters.toStringAsFixed(0)}m)';
    } else {
      return 'Di Luar Kampus (${(distanceMeters / 1000).toStringAsFixed(1)} km)';
    }
  }

  /// Membuka pengaturan aplikasi untuk kasus deniedForever
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// Membuka pengaturan layanan lokasi / GPS
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  LocationPermissionState _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionState.granted;
      case LocationPermission.denied:
        return LocationPermissionState.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionState.deniedForever;
      case LocationPermission.unableToDetermine:
        return LocationPermissionState.unavailable;
    }
  }
}
