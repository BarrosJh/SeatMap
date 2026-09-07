import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/desk_model.dart';
import 'barueri_floorplan_painter.dart';
import 'berrini_floorplan_painter.dart';

import 'desks_canvas_painter.dart';

/// Interactive Floor Plan Widget with InteractiveViewer, Auto-Centering and Material 3 desks.
class InteractiveFloorPlan extends StatefulWidget {
  final List<DeskModel> desks;
  final DeskModel? selectedDesk;
  final ValueChanged<DeskModel>? onDeskSelected;
  final Function(DeskModel desk)? onConfirmBooking;
  final Function(DeskModel desk)? onCancelBooking;
  final String? officeName;
  final double? floorWidth;
  final double? floorHeight;

  const InteractiveFloorPlan({
    super.key,
    required this.desks,
    this.selectedDesk,
    this.onDeskSelected,
    this.onConfirmBooking,
    this.onCancelBooking,
    this.officeName,
    this.floorWidth,
    this.floorHeight,
  });

  @override
  State<InteractiveFloorPlan> createState() => _InteractiveFloorPlanState();
}

class _InteractiveFloorPlanState extends State<InteractiveFloorPlan>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  Size? _lastViewportSize;
  Matrix4 _defaultMatrix = Matrix4.identity();
  double _minScale = 0.3;
  double _maxScale = 3.5;
  bool _hasInitialFit = false;
  DeskModel? _hoveredDesk;

  bool get _isBarueri => widget.officeName?.toLowerCase().contains('barueri') == true;
  double get _effectiveFloorWidth => widget.floorWidth ?? (_isBarueri ? 820.0 : 1184.0);
  double get _effectiveFloorHeight => widget.floorHeight ?? (_isBarueri ? 637.0 : 516.0);


  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });
  }


  @override
  void didUpdateWidget(covariant InteractiveFloorPlan oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.officeName != widget.officeName ||
        oldWidget.floorWidth != widget.floorWidth ||
        oldWidget.floorHeight != widget.floorHeight) {
      if (_lastViewportSize != null) {
        _calculateFitMatrix(_lastViewportSize!);
        _transformationController.value = _defaultMatrix;
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _calculateFitMatrix(Size viewportSize) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return;
    const padding = 28.0;
    final availableWidth = math.max(100.0, viewportSize.width - padding * 2);
    final availableHeight = math.max(100.0, viewportSize.height - padding * 2);

    final scaleX = availableWidth / _effectiveFloorWidth;
    final scaleY = availableHeight / _effectiveFloorHeight;
    final fitScale = math.min(scaleX, scaleY).clamp(0.15, 2.0);

    final scaledWidth = _effectiveFloorWidth * fitScale;
    final scaledHeight = _effectiveFloorHeight * fitScale;
    final dx = (viewportSize.width - scaledWidth) / 2;
    final dy = (viewportSize.height - scaledHeight) / 2;

    _defaultMatrix = Matrix4.identity()
      ..setEntry(0, 0, fitScale)
      ..setEntry(1, 1, fitScale)
      ..setEntry(2, 2, 1.0)
      ..setEntry(0, 3, dx)
      ..setEntry(1, 3, dy)
      ..setEntry(3, 3, 1.0);

    _minScale = math.max(0.1, fitScale * 0.5); // Permite zoom out flexível
    _maxScale = math.max(4.0, fitScale * 4.0);
  }

  void _animateToMatrix(Matrix4 targetMatrix) {
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward(from: 0);
  }

  void _resetZoom() {
    if (_lastViewportSize != null) {
      _calculateFitMatrix(_lastViewportSize!);
    }
    _animateToMatrix(_defaultMatrix);
  }

  void _zoomIn() {
    _zoomBy(1.3);
  }

  void _zoomOut() {
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final fitScale = _defaultMatrix.getMaxScaleOnAxis();
    if (currentScale <= fitScale * 1.05) {
      _resetZoom();
      return;
    }
    _zoomBy(0.77);
  }

  void _zoomBy(double factor) {
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    if (currentScale <= 0) return;

    final fitScale = _defaultMatrix.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(_minScale, _maxScale);

    if (factor < 1.0 && targetScale <= fitScale * 1.05) {
      _resetZoom();
      return;
    }

    if ((targetScale - currentScale).abs() < 0.001) {
      if (factor < 1.0) {
        _resetZoom();
      }
      return;
    }
    final scaleRatio = targetScale / currentScale;

    final viewport = _lastViewportSize ?? Size(_effectiveFloorWidth, _effectiveFloorHeight);
    final center = Offset(viewport.width / 2, viewport.height / 2);

    final currentTx = currentMatrix.storage[12];
    final currentTy = currentMatrix.storage[13];

    final newTx = center.dx - (center.dx - currentTx) * scaleRatio;
    final newTy = center.dy - (center.dy - currentTy) * scaleRatio;

    final newMatrix = Matrix4.identity()
      ..setEntry(0, 0, targetScale)
      ..setEntry(1, 1, targetScale)
      ..setEntry(2, 2, 1.0)
      ..setEntry(0, 3, newTx)
      ..setEntry(1, 3, newTy)
      ..setEntry(3, 3, 1.0);

    _animateToMatrix(newMatrix);
  }

  void _handleDeskTap(DeskModel desk) {
    widget.onDeskSelected?.call(desk);
    _showDeskModal(context, desk);
  }

  void _showDeskModal(BuildContext context, DeskModel desk) {
    final nomeEscritorio = _isBarueri ? 'Escritório Barueri' : 'Escritório Berrini';
    showDialog(
      context: context,
      builder: (ctx) => _DeskDetailsDialog(
        desk: desk,
        escritorioNome: nomeEscritorio,
        onConfirm: () {
          Navigator.pop(ctx);
          widget.onConfirmBooking?.call(desk);
        },
        onCancel: () {
          Navigator.pop(ctx);
          widget.onCancelBooking?.call(desk);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        if (_lastViewportSize != viewportSize) {
          final isFirst = !_hasInitialFit;
          _lastViewportSize = viewportSize;
          _calculateFitMatrix(viewportSize);

          if (isFirst) {
            _hasInitialFit = true;
            _transformationController.value = _defaultMatrix;
          }
        }

        return Container(
          color: const Color(0xFFF1F5F9), // Slate 100 canvas
          child: Stack(
            children: [
              // Interactive Canvas with Double-Tap to Reset
              GestureDetector(
                onDoubleTap: _resetZoom,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: _minScale,
                  maxScale: _maxScale,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  constrained: false,
                  child: Container(
                    width: _effectiveFloorWidth,
                    height: _effectiveFloorHeight,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MouseRegion(
                        cursor: _hoveredDesk != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                        onHover: (event) {
                          final hit = DesksCanvasPainter.findDeskAtPoint(widget.desks, event.localPosition);
                          if (hit != _hoveredDesk) {
                            setState(() => _hoveredDesk = hit);
                          }
                        },
                        onExit: (_) {
                          if (_hoveredDesk != null) {
                            setState(() => _hoveredDesk = null);
                          }
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (details) {
                            final hit = DesksCanvasPainter.findDeskAtPoint(widget.desks, details.localPosition);
                            if (hit != null) {
                              _handleDeskTap(hit);
                            }
                          },
                          child: Stack(
                            children: [
                              // 1. Static Structural Background Layer (Paint Isolated)
                              RepaintBoundary(
                                child: CustomPaint(
                                  size: Size(_effectiveFloorWidth, _effectiveFloorHeight),
                                  painter: _isBarueri
                                      ? const BarueriFloorPlanBackgroundPainter()
                                      : const BerriniFloorPlanBackgroundPainter(),
                                ),
                              ),

                              // 2. Interactive Desks Layer (Single RenderObject Native GPU Canvas Painter)
                              RepaintBoundary(
                                child: CustomPaint(
                                  size: Size(_effectiveFloorWidth, _effectiveFloorHeight),
                                  painter: DesksCanvasPainter(
                                    desks: widget.desks,
                                    selectedDesk: widget.selectedDesk,
                                    hoveredDesk: _hoveredDesk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Floating Controls for Zoom and Centering (Bottom Right)
              Positioned(
                right: 20,
                bottom: 20,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Aproximar Zoom (+)',
                          icon: const Icon(Icons.add_rounded, size: 20, color: Color(0xFF334155)),
                          onPressed: _zoomIn,
                          visualDensity: VisualDensity.compact,
                        ),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        IconButton(
                          tooltip: 'Afastar Zoom (-)',
                          icon: const Icon(Icons.remove_rounded, size: 20, color: Color(0xFF334155)),
                          onPressed: _zoomOut,
                          visualDensity: VisualDensity.compact,
                        ),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        IconButton(
                          tooltip: 'Centralizar e Ajustar à Tela (Duplo clique)',
                          icon: const Icon(Icons.center_focus_strong_rounded, size: 20),
                          color: const Color(0xFF2563EB),
                          onPressed: _resetZoom,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Material 3 Bottom Sheet displaying desk details & booking confirmation
class _DeskDetailsDialog extends StatelessWidget {
  final DeskModel desk;
  final String escritorioNome;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const _DeskDetailsDialog({
    required this.desk,
    required this.escritorioNome,
    required this.onConfirm,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = desk.status;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Desk Number & Status Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: status.containerColor,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Icon(
                      Icons.desk_rounded,
                      color: status.onContainerColor,
                      size: 28.0,
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estação de Trabalho ${desk.number}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          escritorioNome,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: status.containerColor,
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(color: status.color.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(status.icon, size: 14.0, color: status.onContainerColor),
                        const SizedBox(width: 6.0),
                        Text(
                          status.label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: status.onContainerColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24.0),

              // Desk Occupant Details (if occupied or reserved or selected)
              if (desk.isOccupied || desk.isReserved || desk.isSelected) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          (desk.occupantName ?? 'U')[0].toUpperCase(),
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              desk.occupantName ?? 'Colaborador',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              desk.occupantDepartment ?? 'Departamento',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20.0),
              ],

              const SizedBox(height: 8.0),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: const Text('Fechar'),
                    ),
                  ),
                  if (desk.isAvailable) ...[
                    const SizedBox(width: 12.0),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: onConfirm,
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Confirmar Reserva'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                      ),
                    ),
                  ] else if (desk.isSelected && onCancel != null) ...[
                    const SizedBox(width: 12.0),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancelar Reserva'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
