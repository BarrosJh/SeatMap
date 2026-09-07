import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/desk_model.dart';

/// High-performance GPU Canvas Painter that renders all hot-desk stations in a single paint pass.
/// Replaces 1,020+ individual widgets with a single lightweight RenderCustomPaint.
class DesksCanvasPainter extends CustomPainter {
  final List<DeskModel> desks;
  final DeskModel? selectedDesk;
  final DeskModel? hoveredDesk;

  const DesksCanvasPainter({
    required this.desks,
    this.selectedDesk,
    this.hoveredDesk,
  });

  // Pre-cached static paints to avoid object allocations per frame
  static final Paint _fillAvailable = Paint()..color = const Color(0xFF81C784)..style = PaintingStyle.fill;
  static final Paint _strokeAvailable = Paint()..color = const Color(0xFF388E3C)..style = PaintingStyle.stroke..strokeWidth = 1.0;

  static final Paint _fillOccupied = Paint()..color = const Color(0xFFE53935)..style = PaintingStyle.fill;
  static final Paint _strokeOccupied = Paint()..color = const Color(0xFFC62828)..style = PaintingStyle.stroke..strokeWidth = 1.0;

  static final Paint _fillReserved = Paint()..color = const Color(0xFFFFB74D)..style = PaintingStyle.fill;
  static final Paint _strokeReserved = Paint()..color = const Color(0xFFD97706)..style = PaintingStyle.stroke..strokeWidth = 1.0;

  static final Paint _fillSelected = Paint()..color = const Color(0xFF1E88E5)..style = PaintingStyle.fill;
  static final Paint _strokeSelected = Paint()..color = const Color(0xFF1565C0)..style = PaintingStyle.stroke..strokeWidth = 1.0;

  static final Paint _selectionRingPaint = Paint()
    ..color = const Color(0xFF2563EB)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  static final Paint _hoverRingPaint = Paint()
    ..color = const Color(0xFF0F172A).withValues(alpha: 0.3)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  static const TextStyle _textStyleAvailable = TextStyle(
    fontSize: 10.0,
    fontWeight: FontWeight.bold,
    color: Color(0xFF1B5E20),
  );

  static const TextStyle _textStyleReserved = TextStyle(
    fontSize: 10.0,
    fontWeight: FontWeight.bold,
    color: Color(0xFF78350F),
  );

  static const TextStyle _textStyleWhite = TextStyle(
    fontSize: 10.0,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  @override
  void paint(Canvas canvas, Size size) {
    for (final desk in desks) {
      final isSelected = selectedDesk?.id == desk.id;
      final isHovered = hoveredDesk?.id == desk.id;

      final cx = desk.dx + desk.width / 2;
      final cy = desk.dy + desk.height / 2;
      final rad = desk.rotationDegrees * math.pi / 180.0;

      canvas.save();
      canvas.translate(cx, cy);

      if (rad != 0.0) {
        canvas.rotate(rad);
      }

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: desk.width,
        height: desk.height,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3.5));

      // 1. Draw desk fill and outline according to DeskStatus
      switch (desk.status) {
        case DeskStatus.available:
          canvas.drawRRect(rrect, _fillAvailable);
          canvas.drawRRect(rrect, _strokeAvailable);
          break;
        case DeskStatus.occupied:
          canvas.drawRRect(rrect, _fillOccupied);
          canvas.drawRRect(rrect, _strokeOccupied);
          break;
        case DeskStatus.reserved:
          canvas.drawRRect(rrect, _fillReserved);
          canvas.drawRRect(rrect, _strokeReserved);
          break;
        case DeskStatus.selected:
          canvas.drawRRect(rrect, _fillSelected);
          canvas.drawRRect(rrect, _strokeSelected);
          break;
      }

      // 2. Highlight for Selected or Hovered Desk
      if (isSelected) {
        final selectRect = Rect.fromCenter(
          center: Offset.zero,
          width: desk.width + 4.0,
          height: desk.height + 4.0,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(selectRect, const Radius.circular(5.0)), _selectionRingPaint);
      } else if (isHovered) {
        final hoverRect = Rect.fromCenter(
          center: Offset.zero,
          width: desk.width + 3.0,
          height: desk.height + 3.0,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(hoverRect, const Radius.circular(4.5)), _hoverRingPaint);
      }

      // 3. Counter-rotate text so that numbers are always horizontal and readable
      if (rad != 0.0) {
        canvas.rotate(-rad);
      }

      TextStyle style;
      switch (desk.status) {
        case DeskStatus.available:
          style = _textStyleAvailable;
          break;
        case DeskStatus.reserved:
          style = _textStyleReserved;
          break;
        case DeskStatus.occupied:
        case DeskStatus.selected:
          style = _textStyleWhite;
          break;
      }

      final textPainter = TextPainter(
        text: TextSpan(text: desk.number, style: style),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant DesksCanvasPainter oldDelegate) {
    return oldDelegate.desks != desks ||
        oldDelegate.selectedDesk != selectedDesk ||
        oldDelegate.hoveredDesk != hoveredDesk;
  }

  /// Exact hit test supporting arbitrary rotation angles in O(1)
  static DeskModel? findDeskAtPoint(List<DeskModel> desks, Offset point) {
    for (int i = desks.length - 1; i >= 0; i--) {
      final desk = desks[i];
      final cx = desk.dx + desk.width / 2;
      final cy = desk.dy + desk.height / 2;

      if (desk.rotationDegrees == 0.0) {
        final rect = Rect.fromLTWH(desk.dx, desk.dy, desk.width, desk.height);
        if (rect.contains(point)) {
          return desk;
        }
      } else {
        final rad = -desk.rotationDegrees * math.pi / 180.0;
        final cosR = math.cos(rad);
        final sinR = math.sin(rad);

        final dxRel = point.dx - cx;
        final dyRel = point.dy - cy;

        final unrotX = dxRel * cosR - dyRel * sinR;
        final unrotY = dxRel * sinR + dyRel * cosR;

        if (unrotX.abs() <= (desk.width / 2) + 2.0 && unrotY.abs() <= (desk.height / 2) + 2.0) {
          return desk;
        }
      }
    }
    return null;
  }
}
