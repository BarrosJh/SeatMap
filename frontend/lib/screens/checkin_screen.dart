import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/seat_map_provider.dart';
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
  late MobileScannerController _scannerController;
  bool _isProcessing = false;
  bool _isTorchOn = false;
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
      autoStart: true,
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
      try {
        _scannerController.start();
      } catch (_) {}
      _scanLineAnim.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      try {
        _scannerController.stop();
      } catch (_) {}
      _scanLineAnim.stop();
      _scanLineAnim.reset();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      try {
        _scannerController.stop();
      } catch (_) {}
      _scanLineAnim.stop();
    } else if (state == AppLifecycleState.resumed && widget.isActive) {
      try {
        _scannerController.start();
      } catch (_) {}
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

    final scannerWidget = CheckinScannerView(
      scannerController: _scannerController,
      isActive: widget.isActive,
      isProcessing: _isProcessing,
      isTorchOn: _isTorchOn,
      scanLineAnim: _scanLineAnim,
      onQrDetected: _handleQrDetected,
      onToggleTorch: () async {
        await _scannerController.toggleTorch();
        setState(() => _isTorchOn = !_isTorchOn);
      },
      onSwitchCamera: () => _scannerController.switchCamera(),
      onManualInput: _abrirModalSimulacaoQr,
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
