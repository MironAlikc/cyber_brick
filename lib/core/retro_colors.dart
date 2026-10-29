// import 'dart:async';

// import 'package:flutter/material.dart';

// import 'haptics.dart';

// /// Размер «дизайн-холста» (эталонный скриншот).
// const double kDesignW = 589;
// const double kDesignH = 1280;

// /// Имя семейства «цифрового» LCD-шрифта (см. pubspec.yaml).
// /// Если шрифт не подключён — используется monospace.
// const String kLcdFontFamily = 'LcdFont';

// /// Пиксельный шрифт для заголовков (PressStart2P).
// const String kPixelFontFamily = 'PressStart2P';

// class RetroColors {
//   static const ink = Color(0xFF3F4642);
//   static const darkButton = Color(0xFF3E4240);
//   static const darkButtonText = Color(0xFFC3CCC6);

//   static const page = Color(0xFFEBEBEB);
//   static const title = Color(0xFF9BA39E);

//   // корпус
//   static const frame = Color(0xFFB4BBB6);
//   static const frameLight = Color(0xFFD3D7D4);
//   static const frameDark = Color(0xFF979E9A);

//   // LCD
//   static const lcd = Color(0xFFA8B4AC);
//   static const lcdBorder = Color(0xFF39413D);
//   static const divider = Color(0xFF39413D);
//   static const line = Color(0xFF8E9B93);
//   static const box = Color(0xFF9CA9A1);

//   // клетки
//   static const cellRing = Color(0xFFB1BCB4);
//   static const cellInner = Color(0xFFA0ACA4);
//   static const pixel = Color(0xFF161A17);
//   static const ghost = Color(0xFF8A968E);

//   // текст
//   static const label = Color(0xFF3F4A44);
//   static const value = Color(0xFF4A524E);
//   static const hint = Color(0xFF6B786F);
// }

// // ═════════════════════════ КНОПКИ ═════════════════════════

// enum ArcadeKind { yellow, blue }

// class ArcadeButton extends StatefulWidget {
//   final double size;
//   final ArcadeKind kind;
//   final Widget icon;
//   final VoidCallback onPressed;
//   final bool repeat;
//   final bool heavy;

//   const ArcadeButton({
//     super.key,
//     required this.size,
//     required this.kind,
//     required this.icon,
//     required this.onPressed,
//     this.repeat = false,
//     this.heavy = false,
//   });

//   @override
//   State<ArcadeButton> createState() => _ArcadeButtonState();
// }

// class _ArcadeButtonState extends State<ArcadeButton> {
//   Timer? _delay;
//   Timer? _repeater;
//   bool _pressed = false;

//   void _fire() {
//     widget.heavy ? Haptics.heavy() : Haptics.selection();
//     widget.onPressed();
//   }

//   void _down() {
//     setState(() => _pressed = true);
//     _fire();
//     if (widget.repeat) {
//       _delay = Timer(const Duration(milliseconds: 220), () {
//         _repeater = Timer.periodic(
//           const Duration(milliseconds: 70),
//           (_) => _fire(),
//         );
//       });
//     }
//   }

//   void _up() {
//     _delay?.cancel();
//     _repeater?.cancel();
//     if (mounted) setState(() => _pressed = false);
//   }

//   @override
//   void dispose() {
//     _delay?.cancel();
//     _repeater?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isYellow = widget.kind == ArcadeKind.yellow;
//     final colors = isYellow
//         ? const [Color(0xFFFFE45E), Color(0xFFFFC800), Color(0xFFEFA400)]
//         : const [Color(0xFF55BEF2), Color(0xFF1E92DA), Color(0xFF0F6DAE)];

//     return GestureDetector(
//       behavior: HitTestBehavior.opaque,
//       onTapDown: (_) => _down(),
//       onTapUp: (_) => _up(),
//       onTapCancel: _up,
//       child: AnimatedScale(
//         scale: _pressed ? 0.94 : 1.0,
//         duration: const Duration(milliseconds: 60),
//         child: Container(
//           width: widget.size,
//           height: widget.size,
//           padding: const EdgeInsets.all(3.5),
//           decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             gradient: const LinearGradient(
//               begin: Alignment.topCenter,
//               end: Alignment.bottomCenter,
//               colors: [Color(0xFFB9B9B9), Color(0xFF8C8C8C)],
//             ),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withValues(alpha: 0.25),
//                 offset: const Offset(0, 3),
//                 blurRadius: 4,
//               ),
//             ],
//           ),
//           child: Container(
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               gradient: RadialGradient(
//                 center: const Alignment(-0.25, -0.45),
//                 radius: 1.0,
//                 colors: colors,
//                 stops: const [0.0, 0.55, 1.0],
//               ),
//             ),
//             alignment: Alignment.center,
//             child: widget.icon,
//           ),
//         ),
//       ),
//     );
//   }
// }

// enum ArcadeDir { left, right, down }

// class ArcadeTriangle extends StatelessWidget {
//   final ArcadeDir dir;

//   const ArcadeTriangle(this.dir, {super.key});

//   @override
//   Widget build(BuildContext context) {
//     return CustomPaint(
//       size: const Size(34, 34),
//       painter: _TrianglePainter(dir),
//     );
//   }
// }

// class _TrianglePainter extends CustomPainter {
//   final ArcadeDir dir;

//   _TrianglePainter(this.dir);

//   @override
//   void paint(Canvas canvas, Size size) {
//     final w = size.width, h = size.height;
//     final path = Path();

//     switch (dir) {
//       case ArcadeDir.left:
//         path
//           ..moveTo(w * 0.85, h * 0.08)
//           ..lineTo(w * 0.85, h * 0.92)
//           ..lineTo(w * 0.1, h * 0.5);
//         break;
//       case ArcadeDir.right:
//         path
//           ..moveTo(w * 0.15, h * 0.08)
//           ..lineTo(w * 0.15, h * 0.92)
//           ..lineTo(w * 0.9, h * 0.5);
//         break;
//       case ArcadeDir.down:
//         path
//           ..moveTo(w * 0.05, h * 0.2)
//           ..lineTo(w * 0.95, h * 0.2)
//           ..lineTo(w * 0.5, h * 0.88);
//         break;
//     }
//     path.close();

//     final shader = const LinearGradient(
//       begin: Alignment.topCenter,
//       end: Alignment.bottomCenter,
//       colors: [Color(0xFFF5921F), Color(0xFFDD6A0C)],
//     ).createShader(Offset.zero & size);

//     canvas.drawPath(
//       path,
//       Paint()
//         ..shader = shader
//         ..style = PaintingStyle.fill,
//     );
//     canvas.drawPath(
//       path,
//       Paint()
//         ..shader = shader
//         ..style = PaintingStyle.stroke
//         ..strokeWidth = 4
//         ..strokeJoin = StrokeJoin.round,
//     );
//   }

//   @override
//   bool shouldRepaint(covariant _TrianglePainter old) => old.dir != dir;
// }

// // ═════════════════════════ ОБЩАЯ ОБОЛОЧКА ═════════════════════════

// /// Светлый фон + заголовок BRICK CLASSIC + корпус с LCD.
// /// [children] располагаются поверх, в координатах дизайна 589×1280.
// class RetroShell extends StatelessWidget {
//   final List<Widget> children;
//   final Widget? lcdChild;

//   const RetroShell({super.key, required this.children, this.lcdChild});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: RetroColors.page,
//       body: Center(
//         child: FittedBox(
//           fit: BoxFit.contain,
//           child: SizedBox(
//             width: kDesignW,
//             height: kDesignH,
//             child: Stack(
//               children: [
//                 const Positioned(
//                   left: 0,
//                   right: 0,
//                   top: 80,
//                   child: Text(
//                     'BRICK CLASSIC',
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       fontSize: 23,
//                       fontWeight: FontWeight.w700,
//                       letterSpacing: 0.4,
//                       color: RetroColors.title,
//                       height: 1.1,
//                     ),
//                   ),
//                 ),
//                 Positioned(
//                   left: 27,
//                   top: 110,
//                   width: 535,
//                   height: 776,
//                   child: Container(
//                     padding: const EdgeInsets.all(14),
//                     decoration: const BoxDecoration(
//                       color: RetroColors.frame,
//                       border: Border(
//                         top: BorderSide(
//                           color: RetroColors.frameLight,
//                           width: 3,
//                         ),
//                         left: BorderSide(
//                           color: RetroColors.frameLight,
//                           width: 3,
//                         ),
//                         right: BorderSide(
//                           color: RetroColors.frameDark,
//                           width: 3,
//                         ),
//                         bottom: BorderSide(
//                           color: RetroColors.frameDark,
//                           width: 3,
//                         ),
//                       ),
//                     ),
//                     child: SizedBox.expand(
//                       child: DecoratedBox(
//                         decoration: BoxDecoration(
//                           color: RetroColors.lcd,
//                           border: Border.all(
//                             color: RetroColors.lcdBorder,
//                             width: 2,
//                           ),
//                         ),
//                         child: lcdChild,
//                       ),
//                     ),
//                   ),
//                 ),
//                 ...children,
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// /// Текст «цифровым» шрифтом, вписанный ровно в заданный прямоугольник.
// class LcdText extends StatelessWidget {
//   final String text;
//   final double width;
//   final double height;
//   final Color color;

//   const LcdText(
//     this.text, {
//     super.key,
//     required this.width,
//     required this.height,
//     this.color = RetroColors.ink,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: width,
//       height: height,
//       child: FittedBox(
//         fit: BoxFit.contain,
//         child: Text(
//           text,
//           maxLines: 1,
//           style: TextStyle(
//             fontFamily: kLcdFontFamily,
//             fontFamilyFallback: const ['monospace'],
//             fontSize: 40,
//             fontWeight: FontWeight.w600,
//             letterSpacing: 1,
//             color: color,
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ═════════════════════════ ИКОНКИ КНОПОК ═════════════════════════

// const Color kOrangeIcon = Color(0xFFE8730C);
// const Color kBlueIcon = Color(0xFF12628F);

// class CrownIcon extends StatelessWidget {
//   const CrownIcon({super.key});

//   @override
//   Widget build(BuildContext context) =>
//       const CustomPaint(size: Size(50, 38), painter: _CrownPainter());
// }

// class _CrownPainter extends CustomPainter {
//   const _CrownPainter();

//   @override
//   void paint(Canvas canvas, Size size) {
//     final w = size.width, h = size.height;
//     final shader = const LinearGradient(
//       begin: Alignment.topCenter,
//       end: Alignment.bottomCenter,
//       colors: [Color(0xFFF5921F), Color(0xFFDD6A0C)],
//     ).createShader(Offset.zero & size);
//     final fill = Paint()..shader = shader;

//     final path = Path()
//       ..moveTo(w * 0.08, h * 0.78)
//       ..lineTo(w * 0.03, h * 0.24)
//       ..lineTo(w * 0.28, h * 0.52)
//       ..lineTo(w * 0.5, h * 0.1)
//       ..lineTo(w * 0.72, h * 0.52)
//       ..lineTo(w * 0.97, h * 0.24)
//       ..lineTo(w * 0.92, h * 0.78)
//       ..close();
//     canvas.drawPath(path, fill);
//     canvas.drawRRect(
//       RRect.fromRectAndRadius(
//         Rect.fromLTWH(w * 0.08, h * 0.84, w * 0.84, h * 0.14),
//         const Radius.circular(2),
//       ),
//       fill,
//     );
//     for (final c in [
//       Offset(w * 0.03, h * 0.2),
//       Offset(w * 0.5, h * 0.07),
//       Offset(w * 0.97, h * 0.2),
//     ]) {
//       canvas.drawCircle(c, w * 0.065, fill);
//     }
//   }

//   @override
//   bool shouldRepaint(covariant _CrownPainter old) => false;
// }

// /// Квадратная кнопка закрытия «X» с рамкой.
// class RetroCloseButton extends StatelessWidget {
//   final VoidCallback onTap;

//   const RetroCloseButton({super.key, required this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       behavior: HitTestBehavior.opaque,
//       onTap: () {
//         Haptics.selection();
//         onTap();
//       },
//       child: Container(
//         width: 48,
//         height: 48,
//         decoration: BoxDecoration(
//           border: Border.all(color: RetroColors.ink, width: 4),
//         ),
//         child: const CustomPaint(painter: _CrossPainter()),
//       ),
//     );
//   }
// }

// class _CrossPainter extends CustomPainter {
//   const _CrossPainter();

//   @override
//   void paint(Canvas canvas, Size size) {
//     final p = Paint()
//       ..color = RetroColors.ink
//       ..strokeWidth = 4.5
//       ..strokeCap = StrokeCap.butt;
//     const m = 9.0;
//     canvas.drawLine(
//       const Offset(m, m),
//       Offset(size.width - m, size.height - m),
//       p,
//     );
//     canvas.drawLine(Offset(size.width - m, m), Offset(m, size.height - m), p);
//   }

//   @override
//   bool shouldRepaint(covariant _CrossPainter old) => false;
// }

// // ═════════════════════════ LCD-КЛЕТКА ═════════════════════════

// enum LcdCell { empty, filled, ghost }

// /// Рисует одну LCD-клетку. Все размеры — доли от стороны клетки,
// /// поэтому подходит и для поля, и для мини-превью, и для заставки.
// /// [alpha] < 1 — полупрозрачная «послесвечение»-клетка.
// void paintLcdCell(Canvas canvas, Rect rect, LcdCell style, {double alpha = 1}) {
//   final s = rect.width;

//   // «Выключенный» пиксель всегда виден под любым состоянием.
//   canvas.drawRect(
//     rect.deflate(s * 0.05),
//     Paint()..color = RetroColors.cellRing,
//   );
//   canvas.drawRect(
//     rect.deflate(s * 0.25),
//     Paint()..color = RetroColors.cellInner,
//   );

//   if (style == LcdCell.empty) return;

//   final color =
//       (style == LcdCell.filled ? RetroColors.pixel : RetroColors.ghost)
//           .withValues(alpha: alpha);
//   canvas.drawRect(
//     rect.deflate(s * 0.05 + s * 0.04),
//     Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = s * 0.08
//       ..color = color,
//   );
//   canvas.drawRect(rect.deflate(s * 0.27), Paint()..color = color);
// }
