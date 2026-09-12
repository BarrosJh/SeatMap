import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/seat_map_provider.dart';
import '../services/camera/camera_permission_service.dart';
import '../widgets/comprovante_dialog.dart';
import 'checkin/widgets/checkin_feedback_dialog.dart';
import 'checkin/widgets/checkin_scanner_view.dart';
import 'checkin/widgets/checkin_status_card.dart';

class CheckinScreen extends StatefulWidget {
  final VoidCallback? onNavegarParaMapa;
  final bool isActive;

  const CheckinScreen({super.key, this.onNavegarParaMapa, this.isActive = true});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  MobileScannerController? _scannerController;
  Key _scannerKey = UniqueKey();
  bool _isProcessing = false;
  bool _isTorchOn = false;
  late AnimationController _scanLineAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) {
      _initScanner();
    }
    _scanLineAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.isActive) {
      _scanLineAnim.repeat(reverse: true);
    }
  }

  void _initScanner() {
    try {
      _scannerController?.dispose();
    } catch (_) {}
    _scannerController = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: false,
    );
    _scannerKey = UniqueKey();
  }

  Future<void> _restartCamera() async {
    // 1. Tentar solicitar permissão explicitamente via bridge nativo no Web
    try {
      await CameraPermissionService.requestCameraPermission();
    } catch (_) {}

    // 2. Recriar o scanner controller com novo Key para remontagem limpa
    if (mounted) {
      setState(() {
        _isTorchOn = false;
        _initScanner();
      });
    }
  }

  @override
  void didUpdateWidget(CheckinScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      // Ao ativar a aba, recriar o scanner de forma limpa para evitar controllerAlreadyInitialized
      _initScanner();
      _scanLineAnim.repeat(reverse: true);
      setState(() {});
    } else if (!widget.isActive && oldWidget.isActive) {
      try {
        _scannerController?.stop();
        _scannerController?.dispose();
        _scannerController = null;
      } catch (_) {}
      _scanLineAnim.stop();
      _scanLineAnim.reset();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      try {
        _scannerController?.stop();
      } catch (_) {}
      _scanLineAnim.stop();
    } else if (state == AppLifecycleState.resumed && widget.isActive) {
      _initScanner();
      _scanLineAnim.repeat(reverse: true);
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanLineAnim.dispose();
    try {
      _scannerController?.dispose();
    } catch (_) {}
    _scannerController = null;
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
        CheckinFeedbackDialog.show(
          context,
          tipo: TipoFeedbackModal.alerta,
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
        CheckinComprovanteModal.show(
          context,
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
      CheckinFeedbackDialog.show(
        context,
        tipo: TipoFeedbackModal.erro,
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

  void _abrirModalSimulacaoQr() {
    final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
    CheckinSimulacaoModal.show(
      context,
      reservaHoje: seatProvider.reservaHoje,
      onCodigoSubmetido: (code) => _handleQrDetected(code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seatProvider = Provider.of<SeatMapProvider>(context);
    final reservaHoje = seatProvider.reservaHoje;
    final hojeStr = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now());

    final scannerWidget = _scannerController != null && widget.isActive
        ? CheckinScannerView(
            key: _scannerKey,
            scannerController: _scannerController!,
            isActive: widget.isActive,
            isProcessing: _isProcessing,
            isTorchOn: _isTorchOn,
            scanLineAnim: _scanLineAnim,
            onQrDetected: _handleQrDetected,
            onToggleTorch: () async {
              if (_scannerController != null) {
                try {
                  await _scannerController!.toggleTorch();
                  setState(() => _isTorchOn = !_isTorchOn);
                } catch (_) {}
              }
            },
            onSwitchCamera: () {
              if (_scannerController != null) {
                try {
                  _scannerController!.switchCamera();
                } catch (_) {}
              }
            },
            onManualInput: _abrirModalSimulacaoQr,
            onRestartCamera: _restartCamera,
          )
        : Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
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
          );

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
                    child: scannerWidget,
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
                        CheckinTodayReservationCard(
                          reservaHoje: reservaHoje,
                          hojeStr: hojeStr,
                          onNavegarParaMapa: widget.onNavegarParaMapa,
                        ),
                        const SizedBox(height: 20),
                        const CheckinHowItWorksCard(),
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
                  CheckinTodayReservationCard(
                    reservaHoje: reservaHoje,
                    hojeStr: hojeStr,
                    onNavegarParaMapa: widget.onNavegarParaMapa,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 380,
                    child: scannerWidget,
                  ),
                  const SizedBox(height: 16),
                  const CheckinHowItWorksCard(),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

