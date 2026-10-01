import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location_model.dart';
import '../repositories/location_repository.dart';

final locationRepositoryProvider =
    Provider<LocationRepository>((ref) => LocationRepository());
final locationsProvider = StreamProvider<List<LocationModel>>(
    (ref) => ref.watch(locationRepositoryProvider).watchAll());
