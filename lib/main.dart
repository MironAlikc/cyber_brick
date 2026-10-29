import 'dart:async';

import 'package:cyber_brick/core/app_settings.dart';
import 'package:cyber_brick/core/audio_service.dart';
import 'package:cyber_brick/features/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await AppSettings.load();
  await AudioService.instance.init();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const CyberBrickApp());
  unawaited(AudioService.instance.syncMusic());
}

class CyberBrickApp extends StatefulWidget {
  const CyberBrickApp({super.key});

  @override
  State<CyberBrickApp> createState() => _CyberBrickAppState();
}

class _CyberBrickAppState extends State<CyberBrickApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Музыка не должна играть, пока приложение свернуто.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AudioService.instance.syncMusic();
    } else {
      AudioService.instance.pauseMusic();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cyber_brick',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFEBEBEB),
      ),
      home: const SplashScreen(),
    );
  }
}
