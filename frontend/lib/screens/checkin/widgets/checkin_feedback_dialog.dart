import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../models/seat_model.dart';

enum TipoFeedbackModal { sucesso, erro, alerta }

class CheckinFeedbackDialog {
  static void show(
    BuildContext context, {
    required TipoFeedbackModal tipo,
    required String titulo,
    required String mensagem,
    String? acaoTexto,
    VoidCallback? onAcao,
  }) {
    Color corTema;
    IconData icone;

    switch (tipo) {
      case TipoFeedbackModal.sucesso:
        corTema = const Color(0xFF16A34A);
        icone = Icons.check_circle_rounded;
        break;
      case TipoFeedbackModal.erro:
        corTema = const Color(0xFFDC2626);
        icone = Icons.cancel_rounded;
        break;
      case TipoFeedbackModal.alerta:
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
}

class CheckinComprovanteModal {
  static void show(
    BuildContext context, {
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

  static Widget _buildComprovanteRow(String label, String value, {bool isDestacado = false}) {
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
}

class CheckinSimulacaoModal {
  static void show(
    BuildContext context, {
    ReservaModel? reservaHoje,
    required void Function(String code) onCodigoSubmetido,
  }) {
    final codigoController = TextEditingController();

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
                onCodigoSubmetido(code);
              }
            },
            child: const Text('Simular Leitura'),
          ),
        ],
      ),
    );
  }
}

