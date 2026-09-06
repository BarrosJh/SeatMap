import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/seat_model.dart';
import '../providers/auth_provider.dart';
import '../providers/seat_map_provider.dart';

class HomeDashboardScreen extends StatelessWidget {
  final VoidCallback onNavegarParaCheckin;
  final VoidCallback onNavegarParaMinhasReservas;
  final Function(String nomeEscritorio, DateTime? data) onNavegarParaMapa;

  const HomeDashboardScreen({
    super.key,
    required this.onNavegarParaCheckin,
    required this.onNavegarParaMinhasReservas,
    required this.onNavegarParaMapa,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final seatProvider = Provider.of<SeatMapProvider>(context);
    final token = auth.token;

    final primeiroNome = user?.nome.split(' ').first ?? 'Colaborador';
    final hoje = DateTime.now();
    final hojeFormatado = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(hoje);
    final hojeCapitalizado = hojeFormatado.substring(0, 1).toUpperCase() + hojeFormatado.substring(1);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          if (token != null) {
            await Future.wait([
              seatProvider.carregarOcupacaoSemanal(token),
              seatProvider.carregarMinhasReservas(token),
            ]);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Banner Corporativo Superior Estruturado
              _buildCorporateBanner(context, primeiroNome, hojeCapitalizado, seatProvider),

              const SizedBox(height: 24),

              // 2. Grid de Escritórios com Painéis Estruturados
              if (seatProvider.carregandoOcupacao && seatProvider.ocupacaoSemanal.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (seatProvider.ocupacaoSemanal.isEmpty)
                _buildEmptyState(context, token, seatProvider)
              else
                _buildOfficeCardsGrid(context, seatProvider),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. Banner Corporativo Superior
  Widget _buildCorporateBanner(
    BuildContext context,
    String primeiroNome,
    String dataHoje,
    SeatMapProvider seatProvider,
  ) {
    final reservaHoje = seatProvider.reservaHoje;
    final temReservaHoje = reservaHoje != null && reservaHoje.isAtiva;
    final checkinFeito = temReservaHoje && reservaHoje.checkinRealizado;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Deep Navy Corporativo
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá, $primeiroNome',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                if (temReservaHoje)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: checkinFeito
                              ? const Color(0xFF16A34A).withValues(alpha: 0.2)
                              : const Color(0xFF2563EB).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: checkinFeito ? const Color(0xFF22C55E) : const Color(0xFF60A5FA),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          checkinFeito ? 'Check-in Confirmado' : 'Reserva de Hoje',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: checkinFeito ? const Color(0xFF86EFAC) : const Color(0xFF93C5FD),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${reservaHoje.escritorioNome} • Baia ${reservaHoje.baiaNome} • Assento ${reservaHoje.cadeiraIdentificador}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    'Nenhuma reserva ativa para hoje.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          // Ações no Banner
          if (temReservaHoje && !checkinFeito)
            ElevatedButton(
              onPressed: onNavegarParaCheckin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Fazer Check-in', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            )
          else if (temReservaHoje && checkinFeito)
            OutlinedButton(
              onPressed: () => onNavegarParaMapa(reservaHoje.escritorioNome, DateTime.now()),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF86EFAC),
                side: const BorderSide(color: Color(0xFF22C55E)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Ver no Mapa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            )
          else
            OutlinedButton(
              onPressed: onNavegarParaMinhasReservas,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE2E8F0),
                side: const BorderSide(color: Color(0xFF334155)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Minhas Reservas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  /// 2. Grid de Escritórios
  Widget _buildOfficeCardsGrid(BuildContext context, SeatMapProvider seatProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;

        final cards = seatProvider.ocupacaoSemanal.map((escritorio) {
          return _buildOfficeCard(context, escritorio);
        }).toList();

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: cards
                .map((c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: c,
                      ),
                    ))
                .toList(),
          );
        }

        return Column(
          children: cards
              .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: c,
                  ))
              .toList(),
        );
      },
    );
  }

  /// Card do Escritório com painéis organizados para cada semana
  Widget _buildOfficeCard(BuildContext context, OcupacaoEscritorioModel escritorio) {
    final isBarueri = escritorio.nome.toLowerCase().contains('barueri');
    final buttonColor = isBarueri ? const Color(0xFF1E40AF) : const Color(0xFF6D28D9);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topo do Card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      escritorio.nome,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${escritorio.cidade} • ${escritorio.totalCadeiras} assentos',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'Média ${escritorio.mediaOcupacaoAtual}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Painéis das Duas Semanas
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Painel 1: Esta Semana
                Expanded(
                  child: _buildWeekSection('Esta Semana', escritorio.semanaAtual, escritorio),
                ),

                const SizedBox(width: 14),

                // Painel 2: Próxima Semana
                Expanded(
                  child: _buildWeekSection('Próxima Semana', escritorio.proximaSemana, escritorio, isProximaSemana: true),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Botão CTA para entrar no mapa
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  onNavegarParaMapa(escritorio.nome, null);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text(
                  'Acessar Planta de ${escritorio.nome.replaceAll("Escritório ", "")}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Painel de uma Semana
  Widget _buildWeekSection(
    String titulo,
    List<OcupacaoDiaModel> dias,
    OcupacaoEscritorioModel escritorio, {
    bool isProximaSemana = false,
  }) {
    final bool isBloqueada = isProximaSemana && !escritorio.proximaSemanaAberta;
    final String rangeStr = dias.isNotEmpty
        ? ' (${dias.first.dataFormatada} - ${dias.last.dataFormatada})'
        : '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$titulo$rangeStr',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                if (isBloqueada)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, size: 11, color: Color(0xFFB45309)),
                        SizedBox(width: 3),
                        Text(
                          'Abre na Sexta',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (isBloqueada)
            Container(
              height: 180,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_clock_outlined, size: 30, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 10),
                  Text(
                    escritorio.mensagemBloqueioProximaSemana ?? 'A agenda da próxima semana abre na Sexta-feira.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Período: ${dias.isNotEmpty ? "${dias.first.dataFormatada} a ${dias.last.dataFormatada}" : "Em breve"}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Column(
                children: dias.map((dia) => _buildVerticalDayRow(dia, escritorio)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  /// Linha de um dia útil
  Widget _buildVerticalDayRow(OcupacaoDiaModel dia, OcupacaoEscritorioModel escritorio) {
    final perc = dia.percentual;

    Color barColor;
    Color textColor;
    if (perc < 50) {
      barColor = const Color(0xFF16A34A); // Verde
      textColor = const Color(0xFF15803D);
    } else if (perc < 80) {
      barColor = const Color(0xFFD97706); // Âmbar
      textColor = const Color(0xFFB45309);
    } else {
      barColor = const Color(0xFFDC2626); // Vermelho
      textColor = const Color(0xFFB91C1C);
    }

    final hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isHoje = dia.data == hojeStr;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () {
          final dataParsed = DateTime.tryParse(dia.data);
          onNavegarParaMapa(escritorio.nome, dataParsed);
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: isHoje ? const Color(0xFFECFDF5) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isHoje ? Border.all(color: const Color(0xFF6EE7B7), width: 1.0) : null,
          ),
          child: Row(
            children: [
              // Dia Curto & Data
              SizedBox(
                width: 62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dia.diaCurto,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isHoje ? FontWeight.bold : FontWeight.w600,
                        color: isHoje ? const Color(0xFF047857) : const Color(0xFF334155),
                      ),
                    ),
                    Text(
                      dia.dataFormatada,
                      style: TextStyle(
                        fontSize: 10,
                        color: isHoje ? textColor : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 4),

              // Barra de progresso horizontal
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (perc / 100.0).clamp(0.02, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Percentual e vagas livres
              SizedBox(
                width: 54,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$perc%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      '${dia.livres} liv.',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String? token, SeatMapProvider seatProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            const Text(
              'Nenhum dado de ocupação carregado',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                if (token != null) {
                  seatProvider.carregarOcupacaoSemanal(token);
                }
              },
              child: const Text('Recarregar'),
            ),
          ],
        ),
      ),
    );
  }
}