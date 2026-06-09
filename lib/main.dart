import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'ui/screens/play/board_preview_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (_) {
    // Firebase 未接続でも盤プレビューは表示する（外出先の手動確認用）
  }

  runApp(const PolyRushApp());
}

class PolyRushApp extends StatelessWidget {
  const PolyRushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PolyRush',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD8D2C0)),
        scaffoldBackgroundColor: const Color(0xFFFBF7EC),
      ),
      home: const BoardPreviewScreen(),
    );
  }
}
