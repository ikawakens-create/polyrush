// File generated manually from google-services.json (Android only).
// DO NOT modify manually — regenerate with `flutterfire configure` when adding iOS/Web.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web – '
        'reconfigure with `flutterfire configure`.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAl05LvJWNX--8oiXki3tTcyPXEQkM2g4s',
    appId: '1:193233647462:android:a4b0eaabaf9e75be807aa7',
    messagingSenderId: '193233647462',
    projectId: 'polyrush-bc19f',
    storageBucket: 'polyrush-bc19f.firebasestorage.app',
  );
}
