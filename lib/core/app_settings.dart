import 'package:hive_flutter/hive_flutter.dart';

import 'haptics.dart';

/// Глобальные настройки приложения (хранятся в Hive).
/// Вызови `await AppSettings.load()` в main() после Hive.initFlutter().
class AppSettings {
  static const String _boxName = 'cyber_brick_box';
  static const String _musicKey = 'music_on';
  static const String _soundKey = 'sound_on';
  static const String _vibrationKey = 'vibration_on';
  static const String _gesturesKey = 'gestures_on';
  static const String _themeKey = 'theme_id';
  static const String _ownedThemesKey = 'owned_themes';

  static bool musicOn = true;
  static bool soundOn = true;
  static bool vibrationOn = true;
  static bool gesturesOn = true;
  static String themeId = 'classic';
  static Set<String> ownedThemes = {'classic'};

  static Future<void> load() async {
    final box = await Hive.openBox(_boxName);
    musicOn = box.get(_musicKey, defaultValue: true) as bool;
    soundOn = box.get(_soundKey, defaultValue: true) as bool;
    vibrationOn = box.get(_vibrationKey, defaultValue: true) as bool;
    gesturesOn = box.get(_gesturesKey, defaultValue: true) as bool;
    themeId = box.get(_themeKey, defaultValue: 'classic') as String;
    ownedThemes = {
      'classic',
      ...(box.get(_ownedThemesKey, defaultValue: <dynamic>[]) as List)
          .cast<String>(),
    };
    Haptics.enabled = vibrationOn;
  }

  static Future<void> _put(String key, bool value) async {
    final box = await Hive.openBox(_boxName);
    await box.put(key, value);
  }

  static Future<void> setMusic(bool v) {
    musicOn = v;
    return _put(_musicKey, v);
  }

  static Future<void> setSound(bool v) {
    soundOn = v;
    return _put(_soundKey, v);
  }

  static Future<void> setVibration(bool v) {
    vibrationOn = v;
    Haptics.enabled = v;
    return _put(_vibrationKey, v);
  }

  static Future<void> setGestures(bool v) {
    gesturesOn = v;
    return _put(_gesturesKey, v);
  }

  static Future<void> setTheme(String id) async {
    themeId = id;
    final box = await Hive.openBox(_boxName);
    await box.put(_themeKey, id);
  }

  static Future<void> unlockTheme(String id) async {
    ownedThemes = {...ownedThemes, id};
    final box = await Hive.openBox(_boxName);
    await box.put(_ownedThemesKey, ownedThemes.toList());
  }
}
