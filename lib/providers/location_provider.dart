import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location_model.dart';
import '../repositories/location_repository.dart';
import '../services/location_service.dart';

final locationRepositoryProvider =
    Provider<LocationRepository>((ref) => LocationRepository());
final locationsProvider = StreamProvider<List<LocationModel>>(
    (ref) => ref.watch(locationRepositoryProvider).watchAll());
final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());
