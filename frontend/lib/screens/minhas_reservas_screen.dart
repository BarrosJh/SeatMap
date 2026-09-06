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
    final agrupadas = seatProvider.minhasReservasAgrupadasPorData;
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
                        const SizedBox(width: 12),
                        Container(height: 18, width: 1, color: const Color(0xFFCBD5E1)),
                        const SizedBox(width: 12),

                        // FILTRO POR DATA
                        InkWell(
                          onTap: () async {
                            final selected = await showDatePicker(
                              context: context,
                              initialDate: seatProvider.filtroData ?? DateTime.now(),
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2030),
                              helpText: 'SELECIONE A DATA PARA FILTRAR',
                              cancelText: 'CANCELAR',
                              confirmText: 'FILTRAR',
                            );
                            if (selected != null) {
                              seatProvider.setFiltroData(selected);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: seatProvider.filtroData != null
                                  ? const Color(0xFFEFF6FF)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: seatProvider.filtroData != null
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFCBD5E1),
                                width: seatProvider.filtroData != null ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 13,
                                  color: seatProvider.filtroData != null
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  seatProvider.filtroData != null
                                      ? DateFormat('dd/MM/yyyy').format(seatProvider.filtroData!)
                                      : 'Filtrar por Data',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: seatProvider.filtroData != null
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: seatProvider.filtroData != null
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                                if (seatProvider.filtroData != null) ...[
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => seatProvider.limparFiltroData(),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
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

          // Conteúdo Principal Agrupado por Data
          Expanded(
            child: seatProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : agrupadas.isEmpty
                    ? _buildEmptyState(filtroAtual)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        itemCount: agrupadas.keys.length,
                        itemBuilder: (ctx, index) {
                          final dateIso = agrupadas.keys.elementAt(index);
                          final reservasDoDia = agrupadas[dateIso]!;
                          return _buildDateGroupSection(
                            context: ctx,
                            dateIso: dateIso,
                            reservas: reservasDoDia,
                            token: auth.token,
                          );
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

  Widget _buildDateGroupSection({
    required BuildContext context,
    required String dateIso,
    required List<ReservaModel> reservas,
    required String? token,
  }) {
    final first = reservas.first;
    final dataExtenso = first.dataFormatadaExtenso;
    final tagRelativa = first.tagRelativa;
    final isHoje = first.isHoje;
    final isAmanha = first.isAmanha;

    Color tagBgColor = const Color(0xFFF1F5F9);
    Color tagTextColor = const Color(0xFF475569);
    Color tagBorderColor = const Color(0xFFCBD5E1);

    if (isHoje) {
      tagBgColor = const Color(0xFFEFF6FF);
      tagTextColor = const Color(0xFF2563EB);
      tagBorderColor = const Color(0xFF93C5FD);
    } else if (isAmanha) {
      tagBgColor = const Color(0xFFF0FDF4);
      tagTextColor = const Color(0xFF16A34A);
      tagBorderColor = const Color(0xFF86EFAC);
    }

    final totalAtivasNoDia = reservas.where((r) => r.isAtiva).length;
    final totalNoDia = reservas.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CABEÇALHO SEPARADOR DA DATA
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isHoje ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      dataExtenso,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagBgColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: tagBorderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isHoje) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            tagRelativa,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: tagTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  totalNoDia == 1
                      ? '1 assento'
                      : totalAtivasNoDia > 0
                          ? '$totalNoDia assentos ($totalAtivasNoDia ativo)'
                          : '$totalNoDia assentos',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        const SizedBox(height: 12),

        // CARDS PERTENCENTES A ESTA DATA
        ...reservas.map((r) => _buildReservaCard(context, r, token)),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildReservaCard(BuildContext context, ReservaModel r, String? token) {
    Color statusBgColor;
    Color statusTextColor;
    Color statusBorderColor;
    IconData statusIcon;
    String statusLabel;

    if (r.isCancelada) {
      statusBgColor = const Color(0xFFF8FAFC);
      statusTextColor = const Color(0xFF64748B);
      statusBorderColor = const Color(0xFFE2E8F0);
      statusIcon = Icons.cancel_outlined;
      statusLabel = 'Cancelada';
    } else if (r.isExpirada) {
      statusBgColor = const Color(0xFFFEF2F2);
      statusTextColor = const Color(0xFFDC2626);
      statusBorderColor = const Color(0xFFFCA5A5);
      statusIcon = Icons.person_off_outlined;
      statusLabel = 'Não Comparecida';
    } else if (r.isConcluida) {
      statusBgColor = const Color(0xFFEFF6FF);
      statusTextColor = const Color(0xFF2563EB);
      statusBorderColor = const Color(0xFFBFDBFE);
      statusIcon = Icons.task_alt_rounded;
      statusLabel = 'Concluída';
    } else {
      statusBgColor = const Color(0xFFF0FDF4);
      statusTextColor = const Color(0xFF16A34A);
      statusBorderColor = const Color(0xFFBBF7D0);
      statusIcon = Icons.check_circle_outline;
      statusLabel = 'Ativa';
    }

    final horaCheckin = r.checkinEm != null
        ? DateFormat('HH:mm').format(DateTime.tryParse(r.checkinEm!)?.toLocal() ?? DateTime.now())
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: r.isAtiva ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
          width: r.isAtiva ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha Superior: Avatar da Mesa + Identificação + Status Badge
            Row(
              children: [
                // Avatar da Estação / Mesa
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: r.isAtiva ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: r.isAtiva ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chair_alt_rounded,
                          size: 16,
                          color: r.isAtiva ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                        ),
                        Text(
                          '#${r.cadeiraIdentificador}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: r.isAtiva ? const Color(0xFF1E40AF) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Dados do Espaço
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mesa ${r.cadeiraIdentificador} — ${r.baiaNome}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: r.isCancelada ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                          decoration: r.isCancelada ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.domain_rounded, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            '${r.escritorioNome} • ${r.escritorioCidade}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusBorderColor),
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

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            // Linha Inferior: Voucher Code + Checkin Info + Ações
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Chip do Código de Comprovante (Clicável)
                    if (r.codigoComprovante != null && r.codigoComprovante!.isNotEmpty)
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
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.confirmation_number_outlined, size: 12, color: Color(0xFF475569)),
                              const SizedBox(width: 5),
                              Text(
                                r.codigoComprovante!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(Icons.open_in_new_rounded, size: 11, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      ),

                    // Informação de Presença Confirmada
                    if (r.checkinRealizado)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF16A34A)),
                            const SizedBox(width: 4),
                            Text(
                              horaCheckin != null ? 'Presença às $horaCheckin' : 'Presença Confirmada',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // Botões de Ação Contextual
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (r.isAtiva) ...[
                      if (r.isHoje && !r.checkinRealizado)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 14),
                          label: const Text('Fazer Check-in', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            if (token != null) {
                              final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              final ok = await seatProvider.confirmarPresencaHoje(token);
                              if (context.mounted) {
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
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 14),
                        label: const Text('Cancelar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          if (token != null) {
                            _showCancelDialog(r, token);
                          }
                        },
                      ),
                    ] else ...[
                      // Para reservas canceladas ou concluídas: botão de abrir voucher
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.receipt_long_rounded, size: 14),
                        label: const Text('Ver Detalhes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          final auth = Provider.of<AuthProvider>(context, listen: false);
                          final tipo = r.checkinRealizado
                              ? TipoComprovante.checkin
                              : (r.isCancelada
                                  ? TipoComprovante.cancelamento
                                  : TipoComprovante.visualizacao);
                          ComprovanteDialog.show(
                            context,
                            tipo: tipo,
                            comprovante: r.codigoComprovante ?? 'RES-CONFIRMADO',
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
                      ),
                    ],
                  ],
                ),
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
