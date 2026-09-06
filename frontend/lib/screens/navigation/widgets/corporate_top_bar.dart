import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/seat_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/seat_map_provider.dart';

class CorporateTopBar extends StatelessWidget {
  final UserModel? user;
  final int activeIndex;
  final SeatMapProvider seatProvider;

  const CorporateTopBar({
    super.key,
    required this.user,
    required this.activeIndex,
    required this.seatProvider,
  });

  @override
  Widget build(BuildContext context) {
    String sectionTitle;
    String sectionSubtitle;

    if (activeIndex == 0) {
      sectionTitle = '';
      sectionSubtitle = '';
    } else if (activeIndex == 1) {
      final escNome = seatProvider.selectedEscritorio?.nome ?? 'Berrini';
      final isBerrini = escNome.toLowerCase().contains('berrini');
      sectionTitle = 'Mapa de Assentos — Escritório $escNome';
      sectionSubtitle = isBerrini
          ? 'Planta Baixa Interativa 2D • 102 Estações de Trabalho'
          : 'Planta Baixa Interativa 2D • 66 Assentos Disponíveis';
    } else if (activeIndex == 2) {
      sectionTitle = 'Check-in por QR Code — Validação de Presença';
      sectionSubtitle = 'Escaneie o código fixado na sua estação de trabalho até as 11h30';
    } else if (activeIndex == 3) {
      String filtroNome;
      switch (seatProvider.filtroReservas) {
        case ReservaFiltro.ativas:
          filtroNome = 'Reservas Ativas';
          break;
        case ReservaFiltro.concluidas:
          filtroNome = 'Reservas Concluídas';
          break;
        case ReservaFiltro.canceladas:
          filtroNome = 'Reservas Canceladas';
          break;
        case ReservaFiltro.naoComparecidas:
          filtroNome = 'Reservas Não Comparecidas (No-Show)';
          break;
        case ReservaFiltro.todas:
          filtroNome = 'Todas as Reservas';
          break;
      }
      sectionTitle = 'Minhas Reservas — $filtroNome';
      sectionSubtitle = 'Histórico e confirmações de presença do usuário';
    } else {
      sectionTitle = 'Painel Administrativo RH & Gestão';
      sectionSubtitle = 'Gestão de assentos, relatórios de ocupação e políticas de presença';
    }

    final todayFormatted = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now());

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          if (sectionTitle.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  sectionTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  sectionSubtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          const Spacer(),

          // Badge de Data no Canto Direito
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.today_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  todayFormatted,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

