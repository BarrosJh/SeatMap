import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../models/seat_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/seat_map_provider.dart';
import '../../../widgets/comprovante_dialog.dart';

class ConfirmBookingDialog {
  static void showBooking({
    required BuildContext context,
    required CadeiraModel cadeira,
    required String token,
  }) {
    final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dataStr = DateFormat('dd/MM/yyyy (EEEE)', 'pt_BR').format(seatProvider.selectedDate);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.event_seat, color: AppConstants.primaryColor),
              const SizedBox(width: 8),
              Text('Reservar Mesa ${cadeira.identificador}'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Deseja confirmar a reserva para este assento?'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Data: $dataStr', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Escritório: ${seatProvider.selectedEscritorio?.nome ?? ''}'),
                    Text('Mesa: ${cadeira.identificador}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nota: Se você já tiver um assento marcado no mesmo dia, a troca de assento será realizada automaticamente.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await seatProvider.reservarOuTrocar(token, cadeira.id);
                if (context.mounted) {
                  if (res.success && res.data != null) {
                    final comprovante = res.data!['comprovante'] as String? ?? 'RES-CONFIRMADO';
                    final troca = res.data!['trocaRealizada'] == true;
                    final reservaId = (res.data!['reserva'] is Map ? res.data!['reserva']['id'] as int? : null) ??
                        res.data!['reservaId'] as int? ??
                        res.data!['id'] as int?;
                    ComprovanteDialog.show(
                      context,
                      reservaId: reservaId,
                      tipo: troca ? TipoComprovante.troca : TipoComprovante.reserva,
                      comprovante: comprovante,
                      dataReserva: seatProvider.selectedDateIso,
                      escritorioNome: seatProvider.selectedEscritorio?.nome ?? 'Escritório',
                      escritorioCidade: seatProvider.selectedEscritorio?.cidade ?? 'SP',
                      cadeiraIdentificador: cadeira.identificador,
                      usuarioNome: auth.user?.nome,
                      usuarioMatricula: auth.user?.matricula,
                      dataHoraAcao: DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res.error ?? 'Falha ao processar reserva.'),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  }
                }
              },
              child: const Text('Confirmar Reserva'),
            ),
          ],
        );
      },
    );
  }

  static void showCancel({
    required BuildContext context,
    required ReservaModel reserva,
    required String token,
  }) {
    final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Cancelar Reserva'),
          ],
        ),
        content: Text(
          'Deseja realmente cancelar sua reserva para o dia ${reserva.dataReserva} no assento ${reserva.cadeiraIdentificador} (${reserva.escritorioNome})?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await seatProvider.cancelarMinhaReserva(token, reserva.id);
              if (context.mounted) {
                if (res.success) {
                  final comprovante = res.data?['codigoComprovante'] as String? ?? reserva.codigoComprovante ?? 'RES-CANCELADO';
                  ComprovanteDialog.show(
                    context,
                    reservaId: reserva.id,
                    tipo: TipoComprovante.cancelamento,
                    comprovante: comprovante,
                    dataReserva: reserva.dataReserva,
                    escritorioNome: reserva.escritorioNome,
                    escritorioCidade: reserva.escritorioCidade,
                    cadeiraIdentificador: reserva.cadeiraIdentificador,
                    baiaNome: reserva.baiaNome,
                    usuarioNome: auth.user?.nome,
                    usuarioMatricula: auth.user?.matricula,
                    dataHoraAcao: DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res.error ?? 'Falha ao cancelar reserva.'),
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                  );
                }
              }
            },
            child: const Text('Sim, Cancelar'),
          ),
        ],
      ),
    );
  }
}

