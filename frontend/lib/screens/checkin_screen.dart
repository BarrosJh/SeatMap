import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../models/seat_model.dart';
import '../providers/auth_provider.dart';
import '../providers/seat_map_provider.dart';
import '../widgets/comprovante_dialog.dart';

enum _TipoModal { sucesso, erro, alerta }

class CheckinScreen extends StatefulWidget {
  final VoidCallback? onNavegarParaMapa;
  final bool isActive;

  const CheckinScreen({super.key, this.onNavegarParaMapa, this.isActive = true});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late MobileScannerController _scannerController;
  bool _isProcessing = false;
  bool _isTorchOn = false;
  final bool _cameraInitialized = true;
  late AnimationController _scanLineAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScanner();
    _scanLineAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.isActive) {
      _scanLineAnim.repeat(reverse: true);
    }
  }

  void _initScanner() {
    _scannerController = MobileScannerController(
      autoStart: widget.isActive,
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: false,
    );
  }

  @override
  void didUpdateWidget(CheckinScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _scannerController.start();
      _scanLineAnim.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _scannerController.stop();
      _scanLineAnim.stop();
      _scanLineAnim.reset();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _scannerController.stop();
      _scanLineAnim.stop();
    } else if (state == AppLifecycleState.resumed && widget.isActive) {
      _scannerController.start();
      _scanLineAnim.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanLineAnim.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleQrDetected(String rawCode) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
    final reservaHoje = seatProvider.reservaHoje;

    if (auth.token == null) {
      setState(() => _isProcessing = false);
      return;
    }

    // Se não há reserva ativa hoje
    if (reservaHoje == null) {
      if (mounted) {
        _mostrarModalResultado(
          tipo: _TipoModal.alerta,
          titulo: 'Sem Reserva Ativa Hoje',
          mensagem: 'Você leu o QR Code "$rawCode", mas não possui nenhuma reserva ativa para hoje.',
          acaoTexto: 'Ir para o Mapa',
          onAcao: () {
            Navigator.of(context).pop();
            widget.onNavegarParaMapa?.call();
          },
        );
      }
      setState(() => _isProcessing = false);
      return;
    }

    // Se a reserva já foi confirmada
    if (reservaHoje.checkinRealizado) {
      if (mounted) {
        _mostrarModalComprovantePresenca(
          titulo: 'Presença Já Confirmada',
          comprovante: reservaHoje.codigoComprovante ?? 'RES-CONFIRMADO',
          dataReserva: reservaHoje.dataReserva,
          escritorioNome: reservaHoje.escritorioNome,
          escritorioCidade: reservaHoje.escritorioCidade,
          baiaNome: reservaHoje.baiaNome,
          cadeiraIdentificador: reservaHoje.cadeiraIdentificador,
          usuarioNome: auth.user?.nome,
          usuarioMatricula: auth.user?.matricula,
          checkinEm: reservaHoje.checkinEm,
        );
      }
      setState(() => _isProcessing = false);
      return;
    }

    // Validar e efetuar check-in
    final res = await seatProvider.validarEEfetuarCheckinPorQr(auth.token!, rawCode);

    if (!mounted) return;

    if (res.success) {
      final reservaAtualizada = seatProvider.reservaHoje ?? reservaHoje;
      ComprovanteDialog.show(
        context,
        reservaId: reservaAtualizada.id,
        tipo: TipoComprovante.checkin,
        comprovante: reservaAtualizada.codigoComprovante ?? reservaHoje.codigoComprovante ?? 'RES-CONFIRMADO',
        dataReserva: reservaAtualizada.dataReserva,
        escritorioNome: reservaAtualizada.escritorioNome,
        escritorioCidade: reservaAtualizada.escritorioCidade,
        baiaNome: reservaAtualizada.baiaNome,
        cadeiraIdentificador: reservaAtualizada.cadeiraIdentificador,
        usuarioNome: auth.user?.nome,
        usuarioMatricula: auth.user?.matricula,
        dataHoraAcao: DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
      );
    } else {
      _mostrarModalResultado(
        tipo: _TipoModal.erro,
        titulo: 'Falha no Check-in',
        mensagem: res.error ?? 'Não foi possível validar o check-in.',
      );
    }

    // Intervalo para evitar leituras repetidas imediatas
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  void _mostrarModalComprovantePresenca({
    required String titulo,
    required String comprovante,
    required String dataReserva,
    required String escritorioNome,
    required String escritorioCidade,
    required String baiaNome,
    required String cadeiraIdentificador,
    String? usuarioNome,
    String? usuarioMatricula,
    String? checkinEm,
  }) {
    final horaCheckin = checkinEm != null
        ? DateFormat('HH:mm:ss').format(DateTime.tryParse(checkinEm)?.toLocal() ?? DateTime.now())
        : DateFormat('HH:mm:ss').format(DateTime.now());

    String dataFormatada = dataReserva;
    try {
      final dt = DateTime.parse(dataReserva);
      dataFormatada = DateFormat("dd/MM/yyyy (EEEE)", 'pt_BR').format(dt);
    } catch (_) {}

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ícone e Título de Sucesso
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF86EFAC), width: 2),
                  ),
                  child: const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 36),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Comprovante Digital de Presença Emitido',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),

              // CARD ESTILIZADO DO COMPROVANTE (VOUCHER)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // Linha do Hash / Voucher com Botão de Copiar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CÓDIGO DO COMPROVANTE',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                comprovante,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF2563EB)),
                            tooltip: 'Copiar Comprovante',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: comprovante));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Código copiado com sucesso!'), duration: Duration(seconds: 2)),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Detalhes da Reserva em Tabela
                    _buildComprovanteRow('Colaborador', '${usuarioNome ?? "Usuário"} ${usuarioMatricula != null ? "($usuarioMatricula)" : ""}'),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildComprovanteRow('Data da Reserva', dataFormatada),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildComprovanteRow('Horário Check-in', horaCheckin),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildComprovanteRow('Escritório', '$escritorioNome ($escritorioCidade)'),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildComprovanteRow('Estação / Mesa', 'Mesa $cadeiraIdentificador ($baiaNome)', isDestacado: true),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Botões de Ação
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copiar Código'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: comprovante));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Código copiado!'), duration: Duration(seconds: 2)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK, Concluir', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComprovanteRow(String label, String value, {bool isDestacado = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDestacado ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  void _mostrarModalResultado({
    required _TipoModal tipo,
    required String titulo,
    required String mensagem,
    String? acaoTexto,
    VoidCallback? onAcao,
  }) {
    Color corTema;
    IconData icone;

    switch (tipo) {
      case _TipoModal.sucesso:
        corTema = const Color(0xFF16A34A);
        icone = Icons.check_circle_rounded;
        break;
      case _TipoModal.erro:
        corTema = const Color(0xFFDC2626);
        icone = Icons.cancel_rounded;
        break;
      case _TipoModal.alerta:
        corTema = const Color(0xFFD97706);
        icone = Icons.warning_amber_rounded;
        break;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: corTema.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icone, color: corTema, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (acaoTexto != null) ...[
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Fechar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: corTema,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: onAcao ?? () => Navigator.pop(ctx),
                    child: Text(acaoTexto),
                  ),
                ] else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: corTema,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(140, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK, Entendido'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _abrirModalSimulacaoQr() {
    final codigoController = TextEditingController();
    final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
    final reservaHoje = seatProvider.reservaHoje;

    if (reservaHoje != null) {
      codigoController.text = 'SEATMAP:DESK:${reservaHoje.escritorioId}:${reservaHoje.cadeiraId}';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Entrada Manual / Teste de QR'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Caso sua câmera esteja desativada ou deseje testar manualmente, digite o código da mesa ou o identificador do QR Code:',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codigoController,
              decoration: InputDecoration(
                labelText: 'Código / Conteúdo do QR Code',
                hintText: 'Ex: SEATMAP:DESK:1:15 ou 15',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
            const SizedBox(height: 12),
            if (reservaHoje != null)
              Text(
                'Sua mesa reservada para hoje é: Mesa ${reservaHoje.cadeiraIdentificador} (ID: ${reservaHoje.cadeiraId})',
                style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final code = codigoController.text.trim();
              Navigator.pop(ctx);
              if (code.isNotEmpty) {
                _handleQrDetected(code);
              }
            },
            child: const Text('Simular Leitura'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seatProvider = Provider.of<SeatMapProvider>(context);
    final reservaHoje = seatProvider.reservaHoje;
    final hojeStr = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now());

    return Container(
      color: const Color(0xFFF8FAFC),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 850;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coluna Esquerda: Scanner da Câmera
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildCameraScannerCard(),
                  ),
                ),

                // Coluna Direita: Detalhes da Reserva do Dia & Instruções
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 24, right: 24, bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTodayReservationCard(reservaHoje, hojeStr),
                        const SizedBox(height: 20),
                        _buildHowItWorksCard(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTodayReservationCard(reservaHoje, hojeStr),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 380,
                    child: _buildCameraScannerCard(),
                  ),
                  const SizedBox(height: 16),
                  _buildHowItWorksCard(),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  /// Card da Câmera e Scanner de QR Code
  Widget _buildCameraScannerCard() {
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
          if (widget.isActive && _cameraInitialized)
            MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final raw = barcode.rawValue;
                  if (raw != null && raw.isNotEmpty) {
                    _handleQrDetected(raw);
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
                          'Câmera não disponível: ${error.errorCode}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _abrirModalSimulacaoQr,
                          icon: const Icon(Icons.keyboard_outlined),
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
                        backgroundColor: _isTorchOn ? const Color(0xFFFBBF24) : Colors.black.withValues(alpha: 0.6),
                        foregroundColor: _isTorchOn ? Colors.black : Colors.white,
                      ),
                      onPressed: () async {
                        await _scannerController.toggleTorch();
                        setState(() => _isTorchOn = !_isTorchOn);
                      },
                      icon: Icon(_isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, size: 20),
                    ),
                    const SizedBox(width: 8),
                    // Botão Alternar Câmera
                    IconButton.filledTonal(
                      tooltip: 'Alternar Câmera',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _scannerController.switchCamera(),
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
                  onPressed: _abrirModalSimulacaoQr,
                  icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                  label: const Text('Entrada Manual / Teste', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),

          // Indicador de Carregamento ao Processar
          if (_isProcessing)
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

  /// Visor estilizado do Scanner
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
                // Linha de Varredura Animada (apenas quando a aba está ativa)
                if (widget.isActive)
                  AnimatedBuilder(
                    animation: _scanLineAnim,
                    builder: (context, child) {
                      return Positioned(
                        top: _scanLineAnim.value * (clampedBoxSize - 20),
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

  /// Card da Reserva Ativa do Dia
  Widget _buildTodayReservationCard(ReservaModel? reservaHoje, String hojeStr) {
    if (reservaHoje == null) {
      // Sem reserva hoje
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event_busy_rounded, color: Color(0xFF64748B), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nenhuma Reserva Hoje',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        hojeStr[0].toUpperCase() + hojeStr.substring(1),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Você não possui nenhuma reserva de mesa ativa agendada para o dia de hoje. Escolha uma mesa no mapa interativo para realizar o check-in.',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: widget.onNavegarParaMapa,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Ir para o Mapa de Assentos', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }

    final isConfirmado = reservaHoje.checkinRealizado;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConfirmado ? const Color(0xFF86EFAC) : const Color(0xFF93C5FD),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isConfirmado ? const Color(0xFF16A34A) : const Color(0xFF2563EB)).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do Card
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isConfirmado ? const Color(0xFF16A34A) : const Color(0xFF2563EB)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isConfirmado ? Icons.verified_rounded : Icons.place_rounded,
                  color: isConfirmado ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConfirmado ? 'Presença Confirmada' : 'Sua Reserva de Hoje',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isConfirmado ? const Color(0xFF15803D) : const Color(0xFF1E40AF),
                      ),
                    ),
                    Text(
                      hojeStr[0].toUpperCase() + hojeStr.substring(1),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isConfirmado ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isConfirmado ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 3.5,
                      backgroundColor: isConfirmado ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConfirmado ? 'Check-in Realizado' : 'Check-in Pendente',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isConfirmado ? const Color(0xFF15803D) : const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 18),

          // Informações da Mesa
          Row(
            children: [
              Expanded(
                child: _buildInfoBlock(
                  label: 'ESTAÇÃO / MESA',
                  value: 'Mesa ${reservaHoje.cadeiraIdentificador}',
                  icon: Icons.desk_rounded,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Expanded(
                child: _buildInfoBlock(
                  label: 'ESCRITÓRIO',
                  value: reservaHoje.escritorioNome,
                  icon: Icons.business_rounded,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _buildInfoBlock(
                  label: 'BAIA / SETOR',
                  value: reservaHoje.baiaNome,
                  icon: Icons.grid_view_rounded,
                  color: const Color(0xFF475569),
                ),
              ),
              Expanded(
                child: _buildInfoBlock(
                  label: isConfirmado ? 'CONFIRMADO EM' : 'HORÁRIO LIMITE',
                  value: isConfirmado
                      ? (reservaHoje.checkinEm != null
                          ? DateFormat('HH:mm').format(DateTime.parse(reservaHoje.checkinEm!).toLocal())
                          : 'Hoje')
                      : 'Até as 11h00',
                  icon: Icons.schedule_rounded,
                  color: isConfirmado ? const Color(0xFF15803D) : const Color(0xFFD97706),
                ),
              ),
            ],
          ),

          if (!isConfirmado) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Aponte a câmera para o QR Code colado no topo desta mesa para validar sua presença.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBlock({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Card Como Funciona
  Widget _buildHowItWorksCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Color(0xFFF59E0B), size: 20),
              SizedBox(width: 8),
              Text(
                'Como funciona o Check-in?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildStepItem(
            number: '1',
            title: 'Chegue na sua estação',
            description: 'Dirija-se à mesa que você reservou para a jornada de hoje.',
          ),
          const SizedBox(height: 10),
          _buildStepItem(
            number: '2',
            title: 'Escaneie o QR Code',
            description: 'Aponte a câmera para o QR Code físico fixado na mesa.',
          ),
          const SizedBox(height: 10),
          _buildStepItem(
            number: '3',
            title: 'Presença Confirmada',
            description: 'O sistema valida a estação e confirma sua presença em tempo real até as 11h00.',
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({required String number, required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              Text(
                description,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
