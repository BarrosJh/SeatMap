import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

enum TipoComprovante {
  reserva,
  troca,
  checkin,
  cancelamento,
  visualizacao,
}

class ComprovanteDialog extends StatefulWidget {
  final int? reservaId;
  final TipoComprovante tipo;
  final String comprovante;
  final String dataReserva;
  final String escritorioNome;
  final String escritorioCidade;
  final String cadeiraIdentificador;
  final String? baiaNome;
  final String? usuarioNome;
  final String? usuarioMatricula;
  final String? dataHoraAcao;
  final String? tituloCustomizado;

  const ComprovanteDialog({
    super.key,
    this.reservaId,
    required this.tipo,
    required this.comprovante,
    required this.dataReserva,
    required this.escritorioNome,
    required this.escritorioCidade,
    required this.cadeiraIdentificador,
    this.baiaNome,
    this.usuarioNome,
    this.usuarioMatricula,
    this.dataHoraAcao,
    this.tituloCustomizado,
  });

  static Future<void> show(
    BuildContext context, {
    int? reservaId,
    required TipoComprovante tipo,
    required String comprovante,
    required String dataReserva,
    required String escritorioNome,
    required String escritorioCidade,
    required String cadeiraIdentificador,
    String? baiaNome,
    String? usuarioNome,
    String? usuarioMatricula,
    String? dataHoraAcao,
    String? tituloCustomizado,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ComprovanteDialog(
        reservaId: reservaId,
        tipo: tipo,
        comprovante: comprovante,
        dataReserva: dataReserva,
        escritorioNome: escritorioNome,
        escritorioCidade: escritorioCidade,
        cadeiraIdentificador: cadeiraIdentificador,
        baiaNome: baiaNome,
        usuarioNome: usuarioNome,
        usuarioMatricula: usuarioMatricula,
        dataHoraAcao: dataHoraAcao,
        tituloCustomizado: tituloCustomizado,
      ),
    );
  }

  @override
  State<ComprovanteDialog> createState() => _ComprovanteDialogState();
}

class _ComprovanteDialogState extends State<ComprovanteDialog> {
  final ApiService _apiService = ApiService();
  bool _enviandoEmail = false;

  Future<void> _enviarEmail(BuildContext context) async {
    if (widget.reservaId == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _enviandoEmail = true);

    final res = await _apiService.enviarComprovanteEmail(auth.token!, widget.reservaId!);

    if (mounted) {
      setState(() => _enviandoEmail = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(res.message ?? (res.success ? 'Comprovante enviado por e-mail!' : 'Erro ao enviar e-mail.')),
          backgroundColor: res.success ? const Color(0xFF16A34A) : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String dataFormatada = widget.dataReserva;
    try {
      final dt = DateTime.parse(widget.dataReserva);
      dataFormatada = DateFormat("dd/MM/yyyy (EEEE)", 'pt_BR').format(dt);
    } catch (e) {
      debugPrint('[ComprovanteDialog] Erro ao formatar data: $e');
    }

    Color headerIconColor;
    Color headerBgColor;
    Color headerBorderColor;
    IconData headerIcon;
    String tituloDefault;
    String subtitulo;
    String statusLabel;
    Color statusColor;

    switch (widget.tipo) {
      case TipoComprovante.reserva:
        headerIconColor = const Color(0xFF16A34A);
        headerBgColor = const Color(0xFFDCFCE7);
        headerBorderColor = const Color(0xFF86EFAC);
        headerIcon = Icons.verified_rounded;
        tituloDefault = 'Reserva Confirmada!';
        subtitulo = 'Comprovante Digital de Reserva Emitido';
        statusLabel = 'RESERVA ATIVA';
        statusColor = const Color(0xFF16A34A);
        break;
      case TipoComprovante.troca:
        headerIconColor = const Color(0xFF2563EB);
        headerBgColor = const Color(0xFFEFF6FF);
        headerBorderColor = const Color(0xFF93C5FD);
        headerIcon = Icons.swap_horiz_rounded;
        tituloDefault = 'Troca de Mesa Confirmada!';
        subtitulo = 'Comprovante Digital Atualizado';
        statusLabel = 'TROCA REALIZADA';
        statusColor = const Color(0xFF2563EB);
        break;
      case TipoComprovante.checkin:
        headerIconColor = const Color(0xFF16A34A);
        headerBgColor = const Color(0xFFDCFCE7);
        headerBorderColor = const Color(0xFF86EFAC);
        headerIcon = Icons.check_circle_rounded;
        tituloDefault = 'Presença Confirmada!';
        subtitulo = 'Comprovante Digital de Check-in Emitido';
        statusLabel = 'CHECK-IN REALIZADO';
        statusColor = const Color(0xFF16A34A);
        break;
      case TipoComprovante.cancelamento:
        headerIconColor = const Color(0xFFDC2626);
        headerBgColor = const Color(0xFFFEF2F2);
        headerBorderColor = const Color(0xFFFCA5A5);
        headerIcon = Icons.cancel_outlined;
        tituloDefault = 'Reserva Cancelada';
        subtitulo = 'Comprovante de Cancelamento Emitido';
        statusLabel = 'CANCELADA';
        statusColor = const Color(0xFFDC2626);
        break;
      case TipoComprovante.visualizacao:
        headerIconColor = const Color(0xFF0F172A);
        headerBgColor = const Color(0xFFF1F5F9);
        headerBorderColor = const Color(0xFFCBD5E1);
        headerIcon = Icons.confirmation_number_outlined;
        tituloDefault = 'Comprovante Digital';
        subtitulo = 'Detalhes da Reserva e Integridade do Assento';
        statusLabel = 'VOUCHER DA RESERVA';
        statusColor = const Color(0xFF475569);
        break;
    }

    final titulo = widget.tituloCustomizado ?? tituloDefault;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(24),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header com Ícone e Título
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: headerBgColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: headerBorderColor, width: 2),
                ),
                child: Icon(headerIcon, color: headerIconColor, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                subtitulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),

              // Card do Código do Comprovante
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      widget.comprovante,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        color: Color(0xFF0F172A),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Código Único de Integridade & Auditoria',
                      style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Detalhes da Reserva em Tabela Elegante
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    if (widget.usuarioNome != null) ...[
                      _buildLinha('Colaborador', widget.usuarioNome!),
                      if (widget.usuarioMatricula != null) ...[
                        const Divider(height: 14, color: Color(0xFFE2E8F0)),
                        _buildLinha('Matrícula', widget.usuarioMatricula!),
                      ],
                      const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    ],
                    _buildLinha('Data do Assento', dataFormatada),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildLinha('Escritório', '${widget.escritorioNome} (${widget.escritorioCidade})'),
                    if (widget.baiaNome != null) ...[
                      const Divider(height: 14, color: Color(0xFFE2E8F0)),
                      _buildLinha('Baia / Setor', widget.baiaNome!),
                    ],
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildLinha(
                      widget.tipo == TipoComprovante.cancelamento ? 'Estação Liberada' : 'Estação / Mesa',
                      'Mesa ${widget.cadeiraIdentificador}',
                      isDestacado: true,
                    ),
                    if (widget.dataHoraAcao != null) ...[
                      const Divider(height: 14, color: Color(0xFFE2E8F0)),
                      _buildLinha(
                        widget.tipo == TipoComprovante.checkin
                            ? 'Horário do Check-in'
                            : widget.tipo == TipoComprovante.cancelamento
                                ? 'Cancelado em'
                                : 'Registrado em',
                        widget.dataHoraAcao!,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Botões de Ação
              Column(
                children: [
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
                            Clipboard.setData(ClipboardData(text: widget.comprovante));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Código copiado para a área de transferência!'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ),
                      if (widget.reservaId != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: _enviandoEmail
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.email_outlined, size: 16, color: Color(0xFF2563EB)),
                            label: Text(
                              _enviandoEmail ? 'Enviando...' : 'Por E-mail',
                              style: const TextStyle(color: Color(0xFF2563EB)),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF93C5FD)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _enviandoEmail ? null : () => _enviarEmail(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: headerIconColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK, Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
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

  static Widget _buildLinha(String label, String valor, {bool isDestacado = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            valor,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: isDestacado ? 13 : 12,
              fontWeight: isDestacado ? FontWeight.bold : FontWeight.w600,
              color: isDestacado ? const Color(0xFF16A34A) : const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}
