import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/seat_model.dart';
import '../providers/auth_provider.dart';
import '../providers/seat_map_provider.dart';
import '../widgets/comprovante_dialog.dart';

class MinhasReservasScreen extends StatefulWidget {
  const MinhasReservasScreen({super.key});

  @override
  State<MinhasReservasScreen> createState() => _MinhasReservasScreenState();
}

class _MinhasReservasScreenState extends State<MinhasReservasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
      if (auth.token != null) {
        seatProvider.carregarMinhasReservas(auth.token!);
      }
    });
  }

  void _showCancelDialog(ReservaModel reserva, String token) {
    final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
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
                if (mounted) {
                  if (res.success) {
                    final comprovante = res.data?['codigoComprovante'] as String? ?? reserva.codigoComprovante ?? 'RES-CANCELADO';
                    ComprovanteDialog.show(
                      context,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final seatProvider = Provider.of<SeatMapProvider>(context);
    final reservas = seatProvider.minhasReservasFiltradas;
    final filtroAtual = seatProvider.filtroReservas;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Barra de Filtros Corporativa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Filtrar por:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'Ativas',
                          count: seatProvider.totalAtivas,
                          isSelected: filtroAtual == ReservaFiltro.ativas,
                          accentColor: const Color(0xFF16A34A),
                          onTap: () => seatProvider.setFiltroReservas(ReservaFiltro.ativas),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Concluídas',
                          count: seatProvider.totalConcluidas,
                          isSelected: filtroAtual == ReservaFiltro.concluidas,
                          accentColor: const Color(0xFF2563EB),
                          onTap: () => seatProvider.setFiltroReservas(ReservaFiltro.concluidas),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Canceladas',
                          count: seatProvider.totalCanceladas,
                          isSelected: filtroAtual == ReservaFiltro.canceladas,
                          accentColor: const Color(0xFF64748B),
                          onTap: () => seatProvider.setFiltroReservas(ReservaFiltro.canceladas),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Não Comparecidas',
                          count: seatProvider.totalNaoComparecidas,
                          isSelected: filtroAtual == ReservaFiltro.naoComparecidas,
                          accentColor: const Color(0xFFDC2626),
                          onTap: () => seatProvider.setFiltroReservas(ReservaFiltro.naoComparecidas),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Todas',
                          count: seatProvider.minhasReservas.length,
                          isSelected: filtroAtual == ReservaFiltro.todas,
                          accentColor: const Color(0xFF0F172A),
                          onTap: () => seatProvider.setFiltroReservas(ReservaFiltro.todas),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 20),
                  tooltip: 'Atualizar reservas',
                  onPressed: () {
                    if (auth.token != null) {
                      seatProvider.carregarMinhasReservas(auth.token!);
                    }
                  },
                ),
              ],
            ),
          ),

          // Conteúdo Principal
          Expanded(
            child: seatProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : reservas.isEmpty
                    ? _buildEmptyState(filtroAtual)
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: reservas.length,
                        itemBuilder: (ctx, index) {
                          final r = reservas[index];
                          return _buildReservaCard(r, auth.token);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? accentColor : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? accentColor : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservaCard(ReservaModel r, String? token) {
    final isHoje = r.isHoje;

    Color statusBgColor;
    Color statusTextColor;
    IconData statusIcon;
    String statusLabel;

    if (r.isCancelada) {
      statusBgColor = const Color(0xFFF1F5F9);
      statusTextColor = const Color(0xFF64748B);
      statusIcon = Icons.cancel_outlined;
      statusLabel = 'Cancelada';
    } else if (r.isExpirada) {
      statusBgColor = const Color(0xFFFEF2F2);
      statusTextColor = const Color(0xFFDC2626);
      statusIcon = Icons.person_off_outlined;
      statusLabel = 'Não Comparecida (No-Show)';
    } else if (r.isConcluida) {
      statusBgColor = const Color(0xFFEFF6FF);
      statusTextColor = const Color(0xFF2563EB);
      statusIcon = Icons.task_alt_rounded;
      statusLabel = 'Concluída';
    } else {
      statusBgColor = const Color(0xFFF0FDF4);
      statusTextColor = const Color(0xFF16A34A);
      statusIcon = Icons.check_circle_outline;
      statusLabel = 'Ativa';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.dataReserva,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (isHoje)
                      const Text(
                        'Agendado para Hoje',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusTextColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusTextColor),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF1F5F9)),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.domain_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text(
                            '${r.escritorioNome} • ${r.escritorioCidade}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.chair_alt_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text(
                            '${r.baiaNome} — Assento #${r.cadeiraIdentificador}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      if (r.codigoComprovante != null && r.codigoComprovante!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () {
                            final auth = Provider.of<AuthProvider>(context, listen: false);
                            final tipo = r.checkinRealizado
                                ? TipoComprovante.checkin
                                : (r.isCancelada
                                    ? TipoComprovante.cancelamento
                                    : TipoComprovante.visualizacao);
                            ComprovanteDialog.show(
                              context,
                              tipo: tipo,
                              comprovante: r.codigoComprovante!,
                              dataReserva: r.dataReserva,
                              escritorioNome: r.escritorioNome,
                              escritorioCidade: r.escritorioCidade,
                              cadeiraIdentificador: r.cadeiraIdentificador,
                              baiaNome: r.baiaNome,
                              usuarioNome: auth.user?.nome,
                              usuarioMatricula: auth.user?.matricula,
                              dataHoraAcao: r.checkinEm != null
                                  ? DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.tryParse(r.checkinEm!)?.toLocal() ?? DateTime.now())
                                  : null,
                            );
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.confirmation_number_outlined, size: 11, color: Color(0xFF475569)),
                                const SizedBox(width: 4),
                                Text(
                                  r.codigoComprovante!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.open_in_new_rounded, size: 10, color: Color(0xFF94A3B8)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (r.checkinRealizado)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
                        SizedBox(width: 4),
                        Text(
                          'Presença Confirmada',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (r.isAtiva) ...[
                  const SizedBox(width: 12),
                  if (isHoje && !r.checkinRealizado)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 15),
                      label: const Text('Check-in', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        if (token != null) {
                          final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
                          final auth = Provider.of<AuthProvider>(context, listen: false);
                          final ok = await seatProvider.confirmarPresencaHoje(token);
                          if (mounted) {
                            if (ok) {
                              ComprovanteDialog.show(
                                context,
                                tipo: TipoComprovante.checkin,
                                comprovante: r.codigoComprovante ?? 'RES-CHECKIN',
                                dataReserva: r.dataReserva,
                                escritorioNome: r.escritorioNome,
                                escritorioCidade: r.escritorioCidade,
                                cadeiraIdentificador: r.cadeiraIdentificador,
                                baiaNome: r.baiaNome,
                                usuarioNome: auth.user?.nome,
                                usuarioMatricula: auth.user?.matricula,
                                dataHoraAcao: DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(seatProvider.errorMessage ?? 'Falha ao confirmar presença.'),
                                  backgroundColor: const Color(0xFFDC2626),
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 15),
                    label: const Text('Cancelar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      if (token != null) {
                        _showCancelDialog(r, token);
                      }
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ReservaFiltro filtro) {
    String msg;
    switch (filtro) {
      case ReservaFiltro.ativas:
        msg = 'Nenhuma reserva ativa encontrada no momento.';
        break;
      case ReservaFiltro.concluidas:
        msg = 'Nenhuma reserva concluída registrada.';
        break;
      case ReservaFiltro.canceladas:
        msg = 'Nenhuma reserva cancelada.';
        break;
      case ReservaFiltro.naoComparecidas:
        msg = 'Nenhum registro de Não Comparecimento (No-Show).';
        break;
      case ReservaFiltro.todas:
        msg = 'Você ainda não possui reservas cadastradas.';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_seat_outlined, size: 32, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          Text(
            msg,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Selecione uma mesa no Mapa de Assentos para agendar um novo espaço de trabalho.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
