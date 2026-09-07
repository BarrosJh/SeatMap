import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/seat_model.dart';

class CheckinTodayReservationCard extends StatelessWidget {
  final ReservaModel? reservaHoje;
  final String hojeStr;
  final VoidCallback? onNavegarParaMapa;

  const CheckinTodayReservationCard({
    super.key,
    required this.reservaHoje,
    required this.hojeStr,
    this.onNavegarParaMapa,
  });

  @override
  Widget build(BuildContext context) {
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
                onPressed: onNavegarParaMapa,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Ir para o Mapa de Assentos', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }

    final isConfirmado = reservaHoje!.checkinRealizado;

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
                  value: 'Mesa ${reservaHoje!.cadeiraIdentificador}',
                  icon: Icons.desk_rounded,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Expanded(
                child: _buildInfoBlock(
                  label: 'ESCRITÓRIO',
                  value: reservaHoje!.escritorioNome,
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
                  value: reservaHoje!.baiaNome,
                  icon: Icons.grid_view_rounded,
                  color: const Color(0xFF475569),
                ),
              ),
              Expanded(
                child: _buildInfoBlock(
                  label: isConfirmado ? 'CONFIRMADO EM' : 'HORÁRIO LIMITE',
                  value: isConfirmado
                      ? (reservaHoje!.checkinEm != null
                          ? DateFormat('HH:mm').format(DateTime.parse(reservaHoje!.checkinEm!).toLocal())
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
}

class CheckinHowItWorksCard extends StatelessWidget {
  const CheckinHowItWorksCard({super.key});

  @override
  Widget build(BuildContext context) {
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

