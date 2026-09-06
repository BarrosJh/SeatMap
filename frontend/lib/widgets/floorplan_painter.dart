import 'package:flutter/material.dart';

class FloorPlanPainter extends CustomPainter {
  final String escritorioNome;

  FloorPlanPainter({required this.escritorioNome});

  @override
  void paint(Canvas canvas, Size size) {
    if (escritorioNome.toLowerCase().contains('barueri')) {
      _drawBarueriConnectors(canvas);
    }
  }

  void _drawBarueriConnectors(Canvas canvas) {
    final woodPaint = Paint()
      ..color = const Color(0xFF7A3E1D) // Marrom madeira quente da imagem
      ..style = PaintingStyle.fill;

    final woodBorder = Paint()
      ..color = const Color(0xFF532810)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 1. Conector trapezoidal à direita do Pod 1 (mesas 2 e 4)
    final p1 = Path()
      ..moveTo(165, 41)
      ..lineTo(208, 52)
      ..quadraticBezierTo(214, 69, 208, 86)
      ..lineTo(165, 97)
      ..close();
    canvas.drawPath(p1, woodPaint);
    canvas.drawPath(p1, woodBorder);
    _drawPlantCircle(canvas, const Offset(186, 69), 13.5);

    // 2. Conector em cunha entre Pod 2 (mesas 6/10) e o primeiro Pod Diagonal
    final p2 = Path()
      ..moveTo(125, 221)
      ..lineTo(152, 178)
      ..lineTo(195, 222)
      ..lineTo(125, 277)
      ..close();
    canvas.drawPath(p2, woodPaint);
    canvas.drawPath(p2, woodBorder);
    _drawPlantCircle(canvas, const Offset(154, 225), 14.5);

    // 3. Cotovelo curvo na base da Coluna 1 (mesas 29/34) ligando a (28/33)
    _drawElbowConnector(
      canvas,
      startX: 485,
      startY: 258,
      woodPaint: woodPaint,
      woodBorder: woodBorder,
      plantOffset: const Offset(512, 335),
    );

    // 4. Cotovelo curvo na base da Coluna 2 (mesas 40/47) ligando a (39/46)
    _drawElbowConnector(
      canvas,
      startX: 610,
      startY: 288,
      woodPaint: woodPaint,
      woodBorder: woodBorder,
      plantOffset: const Offset(637, 365),
    );

    // 5. Cotovelo curvo na base da Coluna 3 (mesas 54/62) ligando a (53/61)
    _drawElbowConnector(
      canvas,
      startX: 735,
      startY: 318,
      woodPaint: woodPaint,
      woodBorder: woodBorder,
      plantOffset: const Offset(762, 395),
    );
  }

  void _drawElbowConnector(
    Canvas canvas, {
    required double startX,
    required double startY,
    required Paint woodPaint,
    required Paint woodBorder,
    required Offset plantOffset,
  }) {
    // Desenha o cotovelo amadeirado elegante que desce da coluna vertical e vira para a bancada diagonal
    final path = Path()
      ..moveTo(startX, startY)
      ..cubicTo(
        startX - 5,
        startY + 40,
        startX - 35,
        startY + 85,
        startX - 65,
        startY + 125,
      )
      ..lineTo(startX - 20, startY + 140)
      ..cubicTo(
        startX + 5,
        startY + 95,
        startX + 45,
        startY + 45,
        startX + 70,
        startY,
      )
      ..close();

    canvas.drawPath(path, woodPaint);
    canvas.drawPath(path, woodBorder);

    _drawPlantCircle(canvas, plantOffset, 15.0);
  }

  void _drawPlantCircle(Canvas canvas, Offset center, double radius) {
    final plantBg = Paint()
      ..color = const Color(0xFFC8E6C9) // Verde claro suave da imagem
      ..style = PaintingStyle.fill;

    final plantBorder = Paint()
      ..color = const Color(0xFF4CAF50) // Verde de contorno suave
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, plantBg);
    canvas.drawCircle(center, radius, plantBorder);
  }

  @override
  bool shouldRepaint(covariant FloorPlanPainter oldDelegate) {
    return oldDelegate.escritorioNome != escritorioNome;
  }
}
