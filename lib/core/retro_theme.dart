import 'package:flutter/material.dart';

import 'app_settings.dart';

/// Цветовая тема LCD. Реализована как «дуотон»: светлота исходной палитры
/// (серо-зелёной) переводится в градиент от [from] (темнее) к [to] (светлее).
/// У темы CLASSIC фильтра нет — палитра остаётся исходной.
class RetroTheme {
  final String id;
  final String name;
  final int price;
  final Color? from;
  final Color? to;

  const RetroTheme(this.id, this.name, this.price, this.from, this.to);

  Color get swatchDark => from ?? const Color(0xFF161A17);
  Color get swatchLight => to ?? const Color(0xFFA8B4AC);

  ColorFilter? get filter {
    final f = from;
    final t = to;
    if (f == null || t == null) return null;

    List<double> row(double a, double b) {
      final k = (b - a) / 255;
      return [k * 0.299, k * 0.587, k * 0.114, 0, a];
    }

    return ColorFilter.matrix([
      ...row(f.r * 255, t.r * 255),
      ...row(f.g * 255, t.g * 255),
      ...row(f.b * 255, t.b * 255),
      0,
      0,
      0,
      1,
      0,
    ]);
  }
}

const List<RetroTheme> kThemes = [
  RetroTheme('classic', 'CLASSIC', 0, null, null),
  RetroTheme('amber', 'AMBER', 20, Color(0xFF2B1800), Color(0xFFFFD98A)),
  RetroTheme('ice', 'ICE', 20, Color(0xFF0B2233), Color(0xFFBFE6F5)),
  RetroTheme('rose', 'ROSE', 30, Color(0xFF3A1020), Color(0xFFF7C9D6)),
  RetroTheme('night', 'NIGHT', 40, Color(0xFFC8F7E4), Color(0xFF0B1A17)),
];

RetroTheme themeById(String id) =>
    kThemes.firstWhere((t) => t.id == id, orElse: () => kThemes.first);

/// Применяет выбранную тему к корпусу и LCD (кнопки и фон остаются прежними).
class ThemedLcd extends StatelessWidget {
  final Widget child;

  const ThemedLcd({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final filter = themeById(AppSettings.themeId).filter;
    if (filter == null) return child;
    return ColorFiltered(colorFilter: filter, child: child);
  }
}
