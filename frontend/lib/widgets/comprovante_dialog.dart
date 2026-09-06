import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

enum TipoComprovante {
  reserva,
  troca,
  checkin,
  cancelamento,
  visualizacao,
}

class ComprovanteDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    String dataFormatada = dataReserva;
    try {
      final dt = DateTime.parse(dataReserva);
      dataFormatada = DateFormat("dd/MM/yyyy (EEEE)", 'pt_BR').format(dt);
    } catch (_) {}

    Color headerIconColor;
    Color headerBgColor;
    Color headerBorderColor;
    IconData headerIcon;
    String tituloDefault;
    String subtitulo;
    String statusLabel;
    Color statusColor;

    switch (tipo) {
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
        statusLabel = 'TROCA ATÔMICA REALIZADA';
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

    final titulo = tituloCustomizado ?? tituloDefault;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(24),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ícone e Título
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: headerBgColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: headerBorderColor, width: 2),
                  ),
                  child: Icon(headerIcon, color: headerIconColor, size: 36),
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
              Text(
                subtitulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

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
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CÓDIGO DE AUTENTICIDADE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.6,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                SelectableText(
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
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF2563EB)),
                            tooltip: 'Copiar Comprovante',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: comprovante));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Código copiado com sucesso!'),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Detalhes da Reserva
                    if (usuarioNome != null) ...[
                      _buildLinha(
                        'Colaborador',
                        '${usuarioNome!} ${usuarioMatricula != null ? "($usuarioMatricula)" : ""}',
                      ),
                      const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    ],
                    _buildLinha('Data da Reserva', dataFormatada),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildLinha('Escritório', '$escritorioNome ($escritorioCidade)'),
                    if (baiaNome != null) ...[
                      const Divider(height: 14, color: Color(0xFFE2E8F0)),
                      _buildLinha('Baia / Setor', baiaNome!),
                    ],
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildLinha(
                      tipo == TipoComprovante.cancelamento ? 'Estação Liberada' : 'Estação / Mesa',
                      'Mesa $cadeiraIdentificador',
                      isDestacado: true,
                    ),
                    if (dataHoraAcao != null) ...[
                      const Divider(height: 14, color: Color(0xFFE2E8F0)),
                      _buildLinha(
                        tipo == TipoComprovante.checkin
                            ? 'Horário do Check-in'
                            : tipo == TipoComprovante.cancelamento
                                ? 'Cancelado em'
                                : 'Registrado em',
                        dataHoraAcao!,
                      ),
                    ],
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
                          const SnackBar(
                            content: Text('Código copiado para a área de transferência!'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: headerIconColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
