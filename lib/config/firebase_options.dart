import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseOptionsConfig {
  static const _apiKey = 'AIzaSyB8aza9MV_PhGJ7-_atWA_1_Dv9WBy9pDk';
  static const _appId = '1:140322333839:web:4c9e9778005b2cfbecbcfa';
  static const _projectId = 'campusghost-adita';
  static const _senderId = '140322333839';
  static const _authDomain = 'campusghost-adita.firebaseapp.com';
  static const _storageBucket = 'campusghost-adita.firebasestorage.app';

  static bool get isConfigured =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _projectId.isNotEmpty &&
      _senderId.isNotEmpty;

  static FirebaseOptions get current => FirebaseOptions(
        apiKey: _apiKey,
        appId: _appId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        authDomain: kIsWeb ? _authDomain : null,
        storageBucket: _storageBucket,
      );
}
