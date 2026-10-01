import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/profile_repository.dart';
import 'firebase_provider.dart';

final authStateProvider = StreamProvider<User?>(
    (ref) => ref.watch(firebaseAuthProvider).userChanges());
final profileRepositoryProvider = Provider<ProfileRepository>((ref) =>
    ProfileRepository(
        ref.watch(firebaseAuthProvider), ref.watch(localCampusStoreProvider)));
final profilePhotoProvider = FutureProvider<Uint8List?>(
    (ref) => ref.watch(profileRepositoryProvider).readCurrentPhoto());
