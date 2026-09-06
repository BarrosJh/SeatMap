import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/seat_model.dart';
import '../models/user_model.dart';

enum PodOrientation { horizontal, vertical }

class BenchPodWidget extends StatelessWidget {
  final List<CadeiraModel> leftOrTopSeats;
  final List<CadeiraModel> rightOrBottomSeats;
  final PodOrientation orientation;
  final double angle;
  final UserModel currentUser;
  final Function(CadeiraModel) onSeatTap;

  const BenchPodWidget({
    super.key,
    required this.leftOrTopSeats,
    required this.rightOrBottomSeats,
    this.orientation = PodOrientation.vertical,
    this.angle = 0.0,
    required this.currentUser,
    required this.onSeatTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (orientation == PodOrientation.vertical) {
      content = _buildVerticalPod();
    } else {
      content = _buildHorizontalPod();
    }

    if (angle != 0.0) {
      return Transform.rotate(
        angle: angle,
        alignment: Alignment.center,
        child: content,
      );
    }
    return content;
  }

  // Bancada Vertical (Duas colunas: esquerda e direita com cadeiras pretas nas laterais)
  Widget _buildVerticalPod() {
    final rowsCount = math.max(leftOrTopSeats.length, rightOrBottomSeats.length);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
      child: IntrinsicWidth(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Coluna Esquerda
            Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(rowsCount, (i) {
                if (i < leftOrTopSeats.length) {
                  return _buildDeskCell(
                    leftOrTopSeats[i],
                    chairSide: _ChairSide.left,
                  );
                }
                return const SizedBox(width: 41, height: 30);
              }),
            ),

            const SizedBox(width: 2), // Pequeno vão entre as bancadas igual ao desenho

            // Coluna Direita
            Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(rowsCount, (i) {
                if (i < rightOrBottomSeats.length) {
                  return _buildDeskCell(
                    rightOrBottomSeats[i],
                    chairSide: _ChairSide.right,
                  );
                }
                return const SizedBox(width: 41, height: 30);
              }),
            ),
          ],
        ),
      ),
    );
  }

  // Bancada Horizontal (Duas linhas: topo e base com cadeiras pretas em cima e embaixo)
  Widget _buildHorizontalPod() {
    final colsCount = math.max(leftOrTopSeats.length, rightOrBottomSeats.length);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
      child: IntrinsicHeight(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Linha Topo
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(colsCount, (i) {
                if (i < leftOrTopSeats.length) {
                  return _buildDeskCell(
                    leftOrTopSeats[i],
                    chairSide: _ChairSide.top,
                  );
                }
                return const SizedBox(width: 36, height: 35);
              }),
            ),

            const SizedBox(height: 2), // Pequeno vão entre as bancadas

            // Linha Base
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(colsCount, (i) {
                if (i < rightOrBottomSeats.length) {
                  return _buildDeskCell(
                    rightOrBottomSeats[i],
                    chairSide: _ChairSide.bottom,
                  );
                }
                return const SizedBox(width: 36, height: 35);
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeskCell(
    CadeiraModel cadeira, {
    required _ChairSide chairSide,
  }) {
    // Cores fiéis à imagem: Mesa cinza claro suave com borda cinza nítida
    Color corTampo = const Color(0xFFF1F5F9); // Cinza suave do tampo
    Color corBorda = const Color(0xFF94A3B8); // Borda cinza clássica
    Color corCadeira = const Color(0xFF000000); // Cadeira preta da referência
    Color corTexto = const Color(0xFF0F172A);
    double espessuraBorda = 1.0;

    final isSameDept = cadeira.ocupante != null &&
        cadeira.ocupante!.departamentoId != null &&
        cadeira.ocupante!.departamentoId == currentUser.departamentoId;

    if (cadeira.isMinhaReserva) {
      corTampo = const Color(0xFFDBEAFE);
      corBorda = const Color(0xFF2563EB);
      corCadeira = const Color(0xFF2563EB);
      corTexto = const Color(0xFF1E3A8A);
      espessuraBorda = 2.0;
    } else if (cadeira.isOcupada) {
      if (isSameDept) {
        corTampo = const Color(0xFFFEF3C7);
        corBorda = const Color(0xFFD97706);
        corCadeira = const Color(0xFFD97706);
        corTexto = const Color(0xFF78350F);
        espessuraBorda = 2.0;
      } else {
        corTampo = const Color(0xFFFEE2E2);
        corBorda = const Color(0xFFDC2626);
        corCadeira = const Color(0xFFDC2626);
        corTexto = const Color(0xFF991B1B);
      }
    } else if (cadeira.isLivre) {
      // Estado livre: borda cinza limpa idêntica ao desenho
      corBorda = const Color(0xFF94A3B8);
      corCadeira = const Color(0xFF000000);
    }

    final isVertical = chairSide == _ChairSide.left || chairSide == _ChairSide.right;
    const cellWidth = 34.0;
    const cellHeight = 28.0;

    return Padding(
      padding: const EdgeInsets.all(1.0),
      child: InkWell(
        onTap: () => onSeatTap(cadeira),
        child: Tooltip(
          message: cadeira.isLivre
              ? 'Mesa ${cadeira.identificador}: Livre (Clique para reservar)'
              : 'Mesa ${cadeira.identificador}: ${cadeira.ocupante?.nome ?? "Ocupada"} (${cadeira.ocupante?.departamento ?? ""})',
          child: SizedBox(
            width: cellWidth + (isVertical ? 7.0 : 0),
            height: cellHeight + (isVertical ? 0 : 7.0),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 1. Cadeira Preta Anexada (idêntica às imagens)
                _buildChairTab(chairSide, corCadeira),

                // 2. Bloco da Mesa Retangular Cinza com Número
                Container(
                  width: cellWidth,
                  height: cellHeight,
                  decoration: BoxDecoration(
                    color: corTampo,
                    borderRadius: BorderRadius.circular(2.5),
                    border: Border.all(color: corBorda, width: espessuraBorda),
                  ),
                  child: Center(
                    child: Text(
                      cadeira.identificador,
                      style: TextStyle(
                        fontSize: cadeira.identificador.length > 2 ? 10 : 11,
                        fontWeight: FontWeight.bold,
                        color: corTexto,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChairTab(_ChairSide side, Color color) {
    const chairThickness = 6.0;
    const chairLength = 13.0;

    switch (side) {
      case _ChairSide.left:
        return Positioned(
          left: 0,
          child: Container(
            width: chairThickness,
            height: chairLength,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(2)),
            ),
          ),
        );
      case _ChairSide.right:
        return Positioned(
          right: 0,
          child: Container(
            width: chairThickness,
            height: chairLength,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
            ),
          ),
        );
      case _ChairSide.top:
        return Positioned(
          top: 0,
          child: Container(
            width: chairLength,
            height: chairThickness,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ),
        );
      case _ChairSide.bottom:
        return Positioned(
          bottom: 0,
          child: Container(
            width: chairLength,
            height: chairThickness,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
            ),
          ),
        );
    }
  }
}

enum _ChairSide { left, right, top, bottom }
