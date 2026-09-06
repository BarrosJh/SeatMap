import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Static background painter for Berrini office floor plan (1184 x 516 px):
/// Structural walls, conference rooms, wooden cabinetry, columns, and exterior glass facade.
class BerriniFloorPlanBackgroundPainter extends CustomPainter {
  const BerriniFloorPlanBackgroundPainter();

  static final List<Offset> _dotPoints = _buildDotPoints(1184.0, 516.0);

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
    // 1. Subtle floor architectural grid / dot pattern (Batch optimized)
    final dotPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    canvas.drawPoints(ui.PointMode.points, _dotPoints, dotPaint);

    // 2. Structural Meeting Rooms & Technical Areas
    final roomFillPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.fill;

    final roomStrokePaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final diagonalCrossPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Room 1: Large conference room (bottom center)
    const r1 = Rect.fromLTWH(278, 363, 229, 135);
    canvas.drawRRect(RRect.fromRectAndRadius(r1, const Radius.circular(4)), roomFillPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(r1, const Radius.circular(4)), roomStrokePaint);
    canvas.drawLine(const Offset(278, 363), const Offset(507, 498), diagonalCrossPaint);
    canvas.drawLine(const Offset(507, 363), const Offset(278, 498), diagonalCrossPaint);

    // Room 2: Meeting room (top center)
    const r2 = Rect.fromLTWH(278, 17, 114, 159);
    canvas.drawRRect(RRect.fromRectAndRadius(r2, const Radius.circular(4)), roomFillPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(r2, const Radius.circular(4)), roomStrokePaint);
    canvas.drawLine(const Offset(278, 17), const Offset(392, 176), diagonalCrossPaint);
    canvas.drawLine(const Offset(392, 17), const Offset(278, 176), diagonalCrossPaint);

    // Room 3: Copa / Refeitório (top left)
    const r3 = Rect.fromLTWH(5, 64, 181, 95);
    canvas.drawRRect(RRect.fromRectAndRadius(r3, const Radius.circular(4)), roomFillPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(r3, const Radius.circular(4)), roomStrokePaint);
    canvas.drawLine(const Offset(5, 64), const Offset(186, 159), diagonalCrossPaint);
    canvas.drawLine(const Offset(186, 64), const Offset(5, 159), diagonalCrossPaint);

    // Room 4: Serviço / TI (bottom left)
    const r4 = Rect.fromLTWH(5, 453, 174, 57);
    canvas.drawRRect(RRect.fromRectAndRadius(r4, const Radius.circular(4)), roomFillPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(r4, const Radius.circular(4)), roomStrokePaint);
    canvas.drawLine(const Offset(5, 453), const Offset(179, 510), diagonalCrossPaint);
    canvas.drawLine(const Offset(179, 453), const Offset(5, 510), diagonalCrossPaint);

    // 3. Wood Fixtures / Credenzas (#522504 in SVG)
    final woodPaint = Paint()
      ..color = const Color(0xFF8D6E63)
      ..style = PaintingStyle.fill;
    final woodBorder = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final woodRects = [
      const Rect.fromLTWH(507, 370, 19, 124),
      const Rect.fromLTWH(391, 17, 26, 159),
      const Rect.fromLTWH(922, 25, 133, 34),
      const Rect.fromLTWH(1013, 25, 42, 122),
      const Rect.fromLTWH(5, 159, 181, 5),
    ];
    for (final wr in woodRects) {
      canvas.drawRRect(RRect.fromRectAndRadius(wr, const Radius.circular(2)), woodPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(wr, const Radius.circular(2)), woodBorder);
    }

    // 4. Green Planters / Biophilia (#90B543 in SVG)
    final plantPaint = Paint()
      ..color = const Color(0xFF81C784)
      ..style = PaintingStyle.fill;
    const planter = Rect.fromLTWH(5, 442, 174, 11);
    canvas.drawRRect(RRect.fromRectAndRadius(planter, const Radius.circular(3)), plantPaint);

    // 5. Pillars & Structural Columns
    final columnPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.fill;

    final colRects = [
      const Rect.fromLTWH(957, 190, 5, 137),
      const Rect.fromLTWH(957, 190, 22, 4),
      const Rect.fromLTWH(957, 323, 22, 4),
      const Rect.fromLTWH(962, 194, 17, 129),
    ];
    for (final cr in colRects) {
      canvas.drawRect(cr, columnPaint);
    }

    // 6. Exterior Walls & Perimeter Boundaries
    final wallPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.square;

    // Top wall
    canvas.drawLine(const Offset(0, 1), const Offset(1081, 1), wallPaint);
    // Top right corner
    canvas.drawLine(const Offset(1081, 1), const Offset(1081, 132), wallPaint);
    // Bottom right corner
    canvas.drawLine(const Offset(1081, 385), const Offset(1081, 515), wallPaint);
    // Bottom wall
    canvas.drawLine(const Offset(0, 515), const Offset(1081, 515), wallPaint);
    // Left wall
    canvas.drawLine(const Offset(1, 0), const Offset(1, 516), wallPaint);

    // 7. Iconic Curved Glass Facade
    final glassCurtainPath = Path()
      ..moveTo(1080.5, 384)
      ..cubicTo(1222.5, 324, 1212.0, 184.5, 1080.5, 131);

    final glassFillPath = Path.from(glassCurtainPath)
      ..lineTo(1080.5, 384)
      ..close();
    final glassFillPaint = Paint()
      ..color = const Color(0x1A0284C7)
      ..style = PaintingStyle.fill;
    canvas.drawPath(glassFillPath, glassFillPaint);

    final glassStrokePaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(glassCurtainPath, glassStrokePaint);
  }

  @override
  bool shouldRepaint(covariant BerriniFloorPlanBackgroundPainter oldDelegate) => false;
}

/// Alias para manter compatibilidade
typedef FloorPlanBackgroundPainter = BerriniFloorPlanBackgroundPainter;
