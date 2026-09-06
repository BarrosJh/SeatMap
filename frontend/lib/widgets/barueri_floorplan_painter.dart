import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Static background painter for Barueri office floor plan (820 x 637 px):
/// Structural walls, meeting room zone, corporate blue accents, planter biophilia, and architecture dividers.
class BarueriFloorPlanBackgroundPainter extends CustomPainter {
  const BarueriFloorPlanBackgroundPainter();

  static final List<Offset> _dotPoints = _buildDotPoints(820.0, 637.0);

  static List<Offset> _buildDotPoints(double width, double height) {
    final points = <Offset>[];
    for (double x = 20; x < width; x += 30) {
      for (double y = 20; y < height; y += 30) {
        points.add(Offset(x, y));
      }
    }
    return List.unmodifiable(points);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Floor grid dot pattern (Batch optimized)
    final dotPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    canvas.drawPoints(ui.PointMode.points, _dotPoints, dotPaint);

    // 2. Structural Meeting Room / Service Block (#D9D9D9 in SVG)
    final roomFillPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.fill;

    final roomStrokePaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final techBlock = Path()
      ..moveTo(18, 6)
      ..lineTo(322, 6)
      ..lineTo(322, 318.16)
      ..lineTo(231.01, 371)
      ..lineTo(18, 371)
      ..close();
    canvas.drawPath(techBlock, roomFillPaint);
    canvas.drawPath(techBlock, roomStrokePaint);

    // Cross lines inside room
    final crossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(27.38, 18.68), const Offset(289.38, 327.68), crossPaint);
    canvas.drawLine(const Offset(289.38, 19.32), const Offset(27.38, 328.32), crossPaint);

    // 3. Corporate Blue Architectural Elements (#184791 in SVG)
    final bluePaint = Paint()
      ..color = const Color(0xFF184791)
      ..style = PaintingStyle.fill;

    // Blue Feature 1: Lower Left Strip (x=28, y=371, w=109, h=21)
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(28, 371, 109, 21), const Radius.circular(2)),
      bluePaint,
    );

    // Blue Feature 2: Corner Anchor
    final blueCorner = Path()
      ..moveTo(18.5, 369.5)
      ..lineTo(33.5, 369.5)
      ..lineTo(42.0, 387.03)
      ..lineTo(31.5, 395.8)
      ..lineTo(18.5, 402.5)
      ..close();
    canvas.drawPath(blueCorner, bluePaint);

    // Blue Feature 3: Central South Divider (M397 590L468 576...)
    final blueSouth = Path()
      ..moveTo(397, 590)
      ..lineTo(468, 576)
      ..lineTo(515, 528)
      ..lineTo(545, 532)
      ..lineTo(528.5, 554.5)
      ..lineTo(514.5, 579)
      ..lineTo(509, 591.5)
      ..lineTo(505, 604)
      ..lineTo(502.5, 617)
      ..lineTo(501.5, 624)
      ..lineTo(501.5, 628)
      ..lineTo(502.5, 631)
      ..lineTo(400.5, 631)
      ..close();
    canvas.drawPath(blueSouth, bluePaint);

    // Blue Feature 4: East Wing Divider (M680.5 394.2...)
    final blueEast = Path()
      ..moveTo(680.5, 394.23)
      ..lineTo(744.5, 353.5)
      ..lineTo(763.15, 300.5)
      ..lineTo(813.0, 300.5)
      ..lineTo(811.5, 383.0)
      ..lineTo(788.5, 384.0)
      ..lineTo(766.5, 388.5)
      ..lineTo(745.0, 394.5)
      ..lineTo(716.0, 405.5)
      ..lineTo(688.5, 419.5)
      ..close();
    canvas.drawPath(blueEast, bluePaint);

    // 4. Green Planters / Biophilia (#82AF61 in SVG)
    final plantFillPaint = Paint()
      ..color = const Color(0xFF81C784)
      ..style = PaintingStyle.fill;
    final plantBorder = Paint()
      ..color = const Color(0xFF388E3C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(const Offset(148.5, 526.5), 6.5, plantFillPaint);
    canvas.drawCircle(const Offset(148.5, 526.5), 6.5, plantBorder);

    // 5. Architectural Walls & Outlines (Dark Slate / Black stroke)
    final wallPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Perimeter walls
    canvas.drawLine(const Offset(12, 6.5), const Offset(813, 6.5), wallPaint);
    canvas.drawLine(const Offset(812.5, 6), const Offset(812.5, 383), wallPaint);
    canvas.drawLine(const Offset(503.69, 631.61), const Offset(813.69, 382.61), wallPaint);
    canvas.drawLine(const Offset(18, 631.5), const Offset(504, 631.5), wallPaint);
    canvas.drawLine(const Offset(17.5, 632.0), const Offset(11.59, 6.0), wallPaint);

    // Interior dividing curves and accent lines
    final dividerPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final eastCurve = Path()
      ..moveTo(811.56, 303.42)
      ..cubicTo(784.05, 352.93, 761.83, 376.05, 710, 409);
    canvas.drawPath(eastCurve, dividerPaint);

    final southCurve = Path()
      ..moveTo(501.998, 630.5)
      ..cubicTo(498, 529, 704, 377, 812.998, 383.5);
    canvas.drawPath(southCurve, dividerPaint);

    canvas.drawLine(const Offset(575.32, 502.62), const Offset(619.32, 539.62), dividerPaint);
    canvas.drawLine(const Offset(651.32, 440.62), const Offset(697.32, 478.62), dividerPaint);

    final southEntranceCurve = Path()
      ..moveTo(401.72, 630.59)
      ..cubicTo(468.17, 609.10, 498.65, 586.33, 544.72, 532.59);
    canvas.drawPath(southEntranceCurve, dividerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
