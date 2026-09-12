import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CheckinScannerView extends StatelessWidget {
  final MobileScannerController scannerController;
  final bool isActive;
  final bool isProcessing;
  final bool isTorchOn;
  final AnimationController scanLineAnim;
  final void Function(String rawCode) onQrDetected;
  final VoidCallback onToggleTorch;
  final VoidCallback onSwitchCamera;
  final VoidCallback onManualInput;

  const CheckinScannerView({
    super.key,
    required this.scannerController,
    required this.isActive,
    required this.isProcessing,
    required this.isTorchOn,
    required this.scanLineAnim,
    required this.onQrDetected,
    required this.onToggleTorch,
    required this.onSwitchCamera,
    required this.onManualInput,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Feed da Câmera
          if (isActive)
            MobileScanner(
              controller: scannerController,
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final raw = barcode.rawValue;
                  if (raw != null && raw.isNotEmpty) {
                    onQrDetected(raw);
                    break;
                  }
                }
              },
              errorBuilder: (context, error, child) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Acesso à Câmera: ${error.errorCode}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Certifique-se de permitir o uso da câmera no navegador do celular.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            try {
                              await scannerController.start();
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Permitir / Iniciar Câmera'),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: Colors.white70),
                          onPressed: onManualInput,
                          icon: const Icon(Icons.keyboard_outlined, size: 18),
                          label: const Text('Digitar Código Manualmente'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          else
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_outlined, color: Colors.white38, size: 44),
                  SizedBox(height: 10),
                  Text(
                    'Câmera em pausa',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),

          // Overlay do Visor de Escaneamento
          _buildScannerOverlay(),

          // Barra Superior com Controles da Câmera
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 4, backgroundColor: Color(0xFF22C55E)),
                      SizedBox(width: 6),
                      Text(
                        'Leitor Ativo',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    // Botão Lanterna
                    IconButton.filledTonal(
                      tooltip: 'Alternar Lanterna',
                      style: IconButton.styleFrom(
                        backgroundColor: isTorchOn ? const Color(0xFFFBBF24) : Colors.black.withValues(alpha: 0.6),
                        foregroundColor: isTorchOn ? Colors.black : Colors.white,
                      ),
                      onPressed: onToggleTorch,
                      icon: Icon(isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, size: 20),
                    ),
                    const SizedBox(width: 8),
                    // Botão Alternar Câmera
                    IconButton.filledTonal(
                      tooltip: 'Alternar Câmera',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onSwitchCamera,
                      icon: const Icon(Icons.cameraswitch_rounded, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Barra Inferior com Entrada Manual / Teste
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.75),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onManualInput,
                  icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                  label: const Text('Entrada Manual / Teste', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),

          // Indicador de Carregamento ao Processar
          if (isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF38BDF8)),
                    SizedBox(height: 16),
                    Text(
                      'Validando QR Code da Mesa...',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = (constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth : constraints.maxHeight) * 0.65;
        final clampedBoxSize = boxSize.clamp(180.0, 300.0);

        return Center(
          child: SizedBox(
            width: clampedBoxSize,
            height: clampedBoxSize,
            child: Stack(
              children: [
                // Moldura com cantos
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.8), width: 2.5),
                  ),
                ),
                // Linha de Varredura Animada
                if (isActive)
                  AnimatedBuilder(
                    animation: scanLineAnim,
                    builder: (context, child) {
                      return Positioned(
                        top: scanLineAnim.value * (clampedBoxSize - 20),
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.transparent, Color(0xFF38BDF8), Colors.transparent],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

