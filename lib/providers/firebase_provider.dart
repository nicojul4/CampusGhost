import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_campus_store.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final localCampusStoreProvider = Provider<LocalCampusStore>(
    (ref) => throw StateError('Penyimpanan lokal belum disiapkan.'));
