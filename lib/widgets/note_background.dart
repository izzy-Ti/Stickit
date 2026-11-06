import 'package:flutter/material.dart';

import '../models/note.dart';

/// Paints a note's background. Mirrors BackgroundRenderer.kt so the app
/// preview matches the home-screen widget.
class NoteBackground extends StatelessWidget {
  const NoteBackground({
    super.key,
    required this.note,
    required this.child,
    this.radius = 22,
    this.spacing = 28,
  });

  final Note note;
  final Widget child;
  final double radius;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        painter: _BgPainter(note.bg, note.fg, note.style, note.opacity, spacing),
        child: child,
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  _BgPainter(this.bg, this.fg, this.style, this.opacity, this.spacing);

  final int bg;
  final int fg;
  final BgStyle style;
  final double opacity;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Color(bg).withValues(alpha: opacity.clamp(0.0, 1.0));
    final paint = Paint();
    if (style == BgStyle.gradient) {
      final end = Color.lerp(Color(bg), Colors.black, 0.28)!
          .withValues(alpha: opacity.clamp(0.0, 1.0));
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [base, end],
      ).createShader(rect);
    } else {
      paint.color = base;
    }
    canvas.drawRect(rect, paint);

    final line = Paint()
      ..color = Color(fg).withValues(alpha: 0.13)
      ..strokeWidth = 1;
    switch (style) {
      case BgStyle.lined:
        for (var y = spacing * 1.6; y < size.height; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
      case BgStyle.grid:
        final s = spacing * 0.8;
        for (var y = s; y < size.height; y += s) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
        for (var x = s; x < size.width; x += s) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
        }
      case BgStyle.dots:
        final s = spacing * 0.7;
        line.color = Color(fg).withValues(alpha: 0.2);
        for (var y = s / 2; y < size.height; y += s) {
          for (var x = s / 2; x < size.width; x += s) {
            canvas.drawCircle(Offset(x, y), 1.4, line);
          }
        }
      case BgStyle.solid:
      case BgStyle.gradient:
        break;
    }
  }

  @override
  bool shouldRepaint(_BgPainter o) =>
      o.bg != bg ||
      o.fg != fg ||
      o.style != style ||
      o.opacity != opacity ||
      o.spacing != spacing;
}
