import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web no soportado');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS no configurado aún');
      default:
        throw UnsupportedError('Plataforma no soportada');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB8W5uiOuyF2Cb3b7serZxGoXrJV-0cAgA',
    appId: '1:623118659563:android:7bb6638d470065778ab3ae',
    messagingSenderId: '623118659563',
    projectId: 'sentry-notificacion',
    storageBucket: 'sentry-notificacion.firebasestorage.app',
  );
}
