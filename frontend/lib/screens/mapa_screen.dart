import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/desk_model.dart';
import '../models/seat_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/seat_map_provider.dart';
import '../widgets/interactive_floor_plan.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  bool _isFloorPlanView = true;
  DeskModel? _selectedFloorPlanDesk;
  int _weekOffset = 0;

  @override
  void initState() {
    super.initState();
    _weekOffset = 0; // Sempre inicia na semana de trabalho vigente

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
      if (auth.token != null && auth.user != null) {
        seatProvider.initWebSocket(auth.token!);
        seatProvider.carregarInicial(auth.token!, auth.user!);
        final now = DateTime.now();
        if (now.weekday >= 6) {
          final dias = _getDiasUteisSemana();
          seatProvider.selecionarData(auth.token!, dias.first);
        }
      }
    });
  }

  DateTime _getBaseMonday([int offset = 0]) {
    final now = DateTime.now();
    DateTime monday;
    if (now.weekday == 6) {
      // Sábado -> Segunda que vem (+2 dias)
      monday = DateTime(now.year, now.month, now.day).add(const Duration(days: 2));
    } else if (now.weekday == 7) {
      // Domingo -> Segunda que vem (+1 dia)
      monday = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    } else {
      // Segunda a Sexta -> Segunda desta semana
      monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    }
    return monday.add(Duration(days: offset * 7));
  }

  bool _isDateOpenForBooking(DateTime date, UserModel user) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    if (target.isBefore(today)) return false;

    // Calcular diferença em semanas úteis
    final baseMonday = _getBaseMonday(0);
    final targetMonday = target.subtract(Duration(days: target.weekday - 1));
    final diffWeeks = (targetMonday.difference(baseMonday).inDays / 7).round();

    if (diffWeeks <= 0) return true; // Semana vigente sempre aberta
    if (diffWeeks == 1) {
      final diaSemanaHoje = now.weekday; // 1=Seg, 5=Sex
      final horaAtual = DateFormat('HH:mm').format(now);
      if (user.isGestao) {
        // Gestão abre Quinta/Sexta 08h
        return diaSemanaHoje >= 5 || (diaSemanaHoje == 4 && horaAtual.compareTo('08:00') >= 0);
      } else {
        // Colaborador abre Sexta 12h
        return diaSemanaHoje == 5 && horaAtual.compareTo('12:00') >= 0;
      }
    }
    return false;
  }

  List<DateTime> _getDiasUteisSemana() {
    final monday = _getBaseMonday(_weekOffset);
    return List.generate(5, (index) => monday.add(Duration(days: index)));
  }

  void _changeWeek(int delta, String token) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final isRh = user?.isAdmin == true;
    final isNextOpen = user != null && _isDateOpenForBooking(_getBaseMonday(1), user);

    if (!isRh && delta > 0 && !isNextOpen) {
      // Bloqueio silencioso sem alertas desnecessários
      return;
    }

    final minOffset = isRh ? -52 : 0;
    final maxOffset = isRh ? 52 : (isNextOpen ? 1 : 0);

    final nextOffset = (_weekOffset + delta).clamp(minOffset, maxOffset);
    if (nextOffset == _weekOffset) return;

    setState(() {
      _weekOffset = nextOffset;
    });
    final dias = _getDiasUteisSemana();
    final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
    final currentSelected = seatProvider.selectedDate;
    final currentWeekdayIndex = (currentSelected.weekday - 1).clamp(0, 4);
    final targetDate = dias[currentWeekdayIndex];
    seatProvider.selecionarData(token, targetDate);
  }

  void _resetToCurrentWeek(String token) {
    setState(() {
      _weekOffset = 0;
    });
    final dias = _getDiasUteisSemana();
    final now = DateTime.now();
    final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
    final target = (now.weekday >= 6) ? dias.first : now;
    seatProvider.selecionarData(token, target);
  }

  Future<void> _pickCustomDate(BuildContext context, String token) async {
    final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final isRh = user?.isAdmin == true;
    final isNextOpen = user != null && _isDateOpenForBooking(_getBaseMonday(1), user);

    final thisMonday = _getBaseMonday(0);
    DateTime firstDate;
    DateTime lastDate;

    if (isRh) {
      firstDate = DateTime.now().subtract(const Duration(days: 365));
      lastDate = DateTime.now().add(const Duration(days: 365));
    } else {
      final maxWeeks = isNextOpen ? 1 : 0;
      final lastFriday = _getBaseMonday(maxWeeks).add(const Duration(days: 4));
      firstDate = DateTime(thisMonday.year, thisMonday.month, thisMonday.day);
      lastDate = DateTime(lastFriday.year, lastFriday.month, lastFriday.day);
    }

    final initial = seatProvider.selectedDate.isBefore(firstDate)
        ? firstDate
        : (seatProvider.selectedDate.isAfter(lastDate) ? lastDate : seatProvider.selectedDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (d) => d.weekday <= 5,
    );
    if (picked != null) {
      final pickedMonday = DateTime(picked.year, picked.month, picked.day).subtract(Duration(days: picked.weekday - 1));
      final diffWeeks = (pickedMonday.difference(thisMonday).inDays / 7).round();
      setState(() {
        _weekOffset = diffWeeks;
      });
      seatProvider.selecionarData(token, picked);
    }
  }

  String _getWeekLabel() {
    final dias = _getDiasUteisSemana();
    final first = dias.first;
    final last = dias.last;
    final firstStr = DateFormat('dd/MM').format(first);
    final lastStr = DateFormat('dd/MM').format(last);

    if (_weekOffset == 0) {
      return 'Esta Semana ($firstStr - $lastStr)';
    } else if (_weekOffset == 1) {
      return 'Próxima Semana ($firstStr - $lastStr)';
    } else if (_weekOffset > 1) {
      return 'Semana ($firstStr - $lastStr)';
    } else {
      return 'Semana Passada ($firstStr - $lastStr)';
    }
  }

  void _onCadeiraTapped(CadeiraModel cadeira, UserModel currentUser, String token) {
    if (cadeira.isLivre) {
      final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
      final isOpen = _isDateOpenForBooking(seatProvider.selectedDate, currentUser);

      if (!isOpen) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lock_clock_outlined, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Text('Agenda Fechada'),
              ],
            ),
            content: const Text(
              'A agenda para esta data ainda não está aberta para agendamento de reservas. A visualização no mapa é exclusiva para planejamento e consulta.',
              style: TextStyle(fontSize: 13),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
            ],
          ),
        );
        return;
      }

      _showConfirmacaoReservaDialog(cadeira, token);
    } else if (cadeira.isOcupada || cadeira.isMinhaReserva) {
      _showDetalhesOcupanteModal(cadeira, currentUser);
    }
  }

  void _showDetalhesOcupanteModal(CadeiraModel cadeira, UserModel currentUser) {
    final ocupante = cadeira.ocupante;
    final isMinha = cadeira.isMinhaReserva;
    final isSameDept = ocupante != null &&
        ocupante.departamentoId != null &&
        ocupante.departamentoId == currentUser.departamentoId;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isMinha
                            ? const Color(0xFF2563EB)
                            : (isSameDept ? Colors.amber.shade700 : const Color(0xFFDC2626)),
                        radius: 24,
                        child: Icon(
                          isMinha ? Icons.person : (isSameDept ? Icons.group : Icons.person_outline),
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMinha ? '${currentUser.nome} (Você)' : (ocupante?.nome ?? 'Colega'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              isMinha
                                  ? (currentUser.departamentoNome ?? 'Geral')
                                  : (ocupante?.departamento ?? 'Sem departamento'),
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        backgroundColor: Colors.grey.shade100,
                        label: Text(
                          'Mesa ${cadeira.identificador}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),
                  if (ocupante != null) ...[
                    if (isSameDept && !isMinha)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Colega do seu mesmo departamento!',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_outline, color: Colors.blueGrey),
                      title: const Text('Status do Check-in:'),
                      subtitle: Text(
                        ocupante.checkinRealizado ? 'Presença Confirmada' : 'Aguardando confirmação diária',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: ocupante.checkinRealizado ? Colors.green : Colors.orange.shade800,
                        ),
                      ),
                    ),
                    if (ocupante.matricula != null && (currentUser.isAdmin || currentUser.isGestao))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.badge_outlined, color: Colors.blueGrey),
                        title: const Text('Matrícula:'),
                        subtitle: Text(ocupante.matricula!),
                      ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fechar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showConfirmacaoReservaDialog(CadeiraModel cadeira, String token) {
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
                'Nota: Se você já tiver um assento marcado no mesmo dia, a troca será realizada de forma atômica.',
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
                if (mounted) {
                  if (res.success && res.data != null) {
                    final comprovante = res.data!['comprovante'] as String? ?? 'RES-CONFIRMADO';
                    _mostrarModalComprovanteReserva(
                      titulo: res.data!['trocaRealizada'] == true ? 'Troca de Mesa Confirmada!' : 'Reserva Confirmada com Sucesso!',
                      comprovante: comprovante,
                      dataReserva: seatProvider.selectedDateIso,
                      escritorioNome: seatProvider.selectedEscritorio?.nome ?? 'Escritório',
                      escritorioCidade: seatProvider.selectedEscritorio?.cidade ?? 'SP',
                      cadeiraIdentificador: cadeira.identificador,
                      usuarioNome: auth.user?.nome,
                      usuarioMatricula: auth.user?.matricula,
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

  void _mostrarModalComprovanteReserva({
    required String titulo,
    required String comprovante,
    required String dataReserva,
    required String escritorioNome,
    required String escritorioCidade,
    required String cadeiraIdentificador,
    String? usuarioNome,
    String? usuarioMatricula,
  }) {
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
                'Comprovante Digital de Reserva Emitido',
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

                    // Detalhes da Reserva
                    _buildComprovanteLinha('Colaborador', '${usuarioNome ?? "Usuário"} ${usuarioMatricula != null ? "($usuarioMatricula)" : ""}'),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildComprovanteLinha('Data da Reserva', dataFormatada),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildComprovanteLinha('Escritório', '$escritorioNome ($escritorioCidade)'),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildComprovanteLinha('Estação / Mesa', 'Mesa $cadeiraIdentificador', isDestacado: true),
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

  Widget _buildComprovanteLinha(String label, String value, {bool isDestacado = false}) {
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final seatProvider = Provider.of<SeatMapProvider>(context);
    final diasUteis = _getDiasUteisSemana();

    // Contadores Rápidos (KPIs)
    int totalAssentos = 0;
    int totalLivres = 0;
    int totalOcupadas = 0;
    int totalMinhas = 0;

    if (seatProvider.mapaData != null) {
      for (final baia in seatProvider.mapaData!.baias) {
        for (final cad in baia.cadeiras) {
          totalAssentos++;
          if (cad.isMinhaReserva) {
            totalMinhas++;
          } else if (cad.isOcupada) {
            totalOcupadas++;
          } else if (cad.isLivre) {
            totalLivres++;
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // BARRA DE CONTROLE CORPORATIVA UNIFICADA
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                ),
              ),
              child: Column(
                children: [
                  // Linha Superior: Navegação de Semanas, Dias da Semana e Alternador de Visão
                  Row(
                    children: [
                      // Controles de Navegação de Semana
                      Builder(
                        builder: (ctx) {
                          final isRh = auth.user?.isAdmin == true;
                          final isNextOpen = auth.user != null && _isDateOpenForBooking(_getBaseMonday(1), auth.user!);
                          final canGoBack = isRh ? true : _weekOffset > 0;
                          final canGoForward = isRh ? true : (_weekOffset < (isNextOpen ? 1 : 0));

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                                  tooltip: canGoBack ? 'Semana Anterior' : null,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  color: canGoBack ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                                  onPressed: (canGoBack && auth.token != null) ? () => _changeWeek(-1, auth.token!) : null,
                                ),
                                InkWell(
                                  onTap: auth.token != null ? () => _resetToCurrentWeek(auth.token!) : null,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.date_range_rounded, size: 15, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 6),
                                        Text(
                                          _getWeekLabel(),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                                  tooltip: canGoForward ? 'Próxima Semana' : null,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  color: canGoForward ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                                  onPressed: (canGoForward && auth.token != null) ? () => _changeWeek(1, auth.token!) : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF64748B)),
                                  tooltip: 'Escolher Data no Calendário',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: auth.token != null ? () => _pickCustomDate(context, auth.token!) : null,
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(width: 14),

                      // Abas de Dias da Semana (Seg a Sex)
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: diasUteis.map((dia) {
                              final isSelected = DateFormat('yyyy-MM-dd').format(dia) == seatProvider.selectedDateIso;
                              final isToday = DateFormat('yyyy-MM-dd').format(dia) == DateFormat('yyyy-MM-dd').format(DateTime.now());
                              final diaSemanaNome = DateFormat('EEE', 'pt_BR').format(dia).toUpperCase();
                              final diaNumero = DateFormat('dd/MM').format(dia);

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: InkWell(
                                  onTap: () {
                                    if (auth.token != null) {
                                      seatProvider.selecionarData(auth.token!, dia);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              diaSemanaNome,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? Colors.white70 : const Color(0xFF64748B),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            Text(
                                              diaNumero,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? Colors.white : const Color(0xFF1E293B),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (isToday) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFDBEAFE),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'HOJE',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? Colors.white : const Color(0xFF1D4ED8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                      if (seatProvider.isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),

                      // Botão Alternador de Modo (Planta 2D / Lista)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildViewToggleButton(
                              icon: Icons.map_rounded,
                              label: 'Planta 2D',
                              isSelected: _isFloorPlanView,
                              onTap: () => setState(() => _isFloorPlanView = true),
                            ),
                            _buildViewToggleButton(
                              icon: Icons.view_agenda_rounded,
                              label: 'Lista',
                              isSelected: !_isFloorPlanView,
                              onTap: () => setState(() => _isFloorPlanView = false),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 8),

                  // Linha Inferior: KPIs Executivos e Legendas Integradas
                  Row(
                    children: [
                      // KPIs Executivos
                      Row(
                        children: [
                          _buildModernKpi(label: 'Total', value: totalAssentos, color: const Color(0xFF334155)),
                          const SizedBox(width: 8),
                          _buildModernKpi(label: 'Livres', value: totalLivres, color: const Color(0xFF16A34A)),
                          const SizedBox(width: 8),
                          _buildModernKpi(label: 'Ocupadas', value: totalOcupadas, color: const Color(0xFFDC2626)),
                          const SizedBox(width: 8),
                          _buildModernKpi(label: 'Minhas', value: totalMinhas, color: const Color(0xFF2563EB)),
                        ],
                      ),

                      const Spacer(),

                      // Legenda Executiva Compacta
                      Row(
                        children: [
                          _buildLegendDot(const Color(0xFF22C55E), 'Livre'),
                          const SizedBox(width: 14),
                          _buildLegendDot(const Color(0xFF2563EB), 'Sua Reserva'),
                          const SizedBox(width: 14),
                          _buildLegendDot(const Color(0xFFDC2626), 'Ocupada'),
                          const SizedBox(width: 14),
                          _buildLegendDot(const Color(0xFFD97706), 'Colega Depto'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // CONTEÚDO PRINCIPAL (Planta Baixa Interativa vs Cards de Bancadas)
            Expanded(
              child: seatProvider.mapaData == null
                  ? const Center(child: CircularProgressIndicator())
                  : (_isFloorPlanView
                      ? _buildInteractiveFloorPlanView(seatProvider, auth.user!, auth.token!)
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: seatProvider.mapaData!.baias.length,
                          itemBuilder: (context, index) {
                            final baia = seatProvider.mapaData!.baias[index];
                            return _buildBaiaCard(baia, index, auth.user!, auth.token!);
                          },
                        )),
            ),

            // Alerta Inferior de Check-in (se houver reserva ativa hoje pendente)
            if (seatProvider.temCheckinPendenteHoje)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  border: Border(top: BorderSide(color: Colors.amber.shade300, width: 1.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.alarm_on_rounded, color: Color(0xFFD97706), size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Presença Pendente Hoje!',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF78350F)),
                          ),
                          Text(
                            'Confirme sua presença para evitar o cancelamento automático por No-Show.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Confirmar Check-in', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        if (auth.token != null) {
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await seatProvider.confirmarPresencaHoje(auth.token!);
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(ok ? 'Presença confirmada com sucesso!' : 'Falha ao confirmar presença.'),
                                backgroundColor: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernKpi({
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
          ),
          Text(
            '$value',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Card de Cada Bancada / Bloco de Mesas
  Widget _buildBaiaCard(BaiaModel baia, int index, UserModel user, String token) {
    final rangeInicio = baia.cadeiras.isNotEmpty ? baia.cadeiras.first.identificador : '';
    final rangeFim = baia.cadeiras.isNotEmpty ? baia.cadeiras.last.identificador : '';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho da Bancada
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.table_restaurant_rounded, color: Color(0xFF2563EB), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bancada ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '${baia.cadeiras.length} assentos (Mesas $rangeInicio a $rangeFim)',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: baia.totalLivres > 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: baia.totalLivres > 0 ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                    ),
                  ),
                  child: Text(
                    '${baia.totalLivres} livres',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: baia.totalLivres > 0 ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Grade de Botões de Assentos
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: baia.cadeiras.map((cadeira) {
                return _buildCleanSeatButton(cadeira, user, token);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Botão Interativo do Assento (Versão Clean)
  Widget _buildCleanSeatButton(CadeiraModel cadeira, UserModel currentUser, String token) {
    Color bgColor = const Color(0xFFF8FAFC);
    Color borderColor = const Color(0xFFCBD5E1);
    Color textColor = const Color(0xFF0F172A);
    Color statusColor = const Color(0xFF16A34A);
    String statusLabel = 'Livre';
    IconData statusIcon = Icons.event_seat;

    final isSameDept = cadeira.ocupante != null &&
        cadeira.ocupante!.departamentoId != null &&
        cadeira.ocupante!.departamentoId == currentUser.departamentoId;

    if (cadeira.isMinhaReserva) {
      bgColor = const Color(0xFFEFF6FF);
      borderColor = const Color(0xFF2563EB);
      textColor = const Color(0xFF1E3A8A);
      statusColor = const Color(0xFF2563EB);
      statusLabel = 'Você';
      statusIcon = Icons.person;
    } else if (cadeira.isOcupada) {
      if (isSameDept) {
        bgColor = const Color(0xFFFFFBEB);
        borderColor = const Color(0xFFF59E0B);
        textColor = const Color(0xFF78350F);
        statusColor = const Color(0xFFD97706);
        statusLabel = cadeira.ocupante?.nome.split(' ').first ?? 'Colega';
        statusIcon = Icons.group;
      } else {
        bgColor = const Color(0xFFFEF2F2);
        borderColor = const Color(0xFFEF4444);
        textColor = const Color(0xFF991B1B);
        statusColor = const Color(0xFFDC2626);
        statusLabel = 'Ocupada';
        statusIcon = Icons.person_outline;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onCadeiraTapped(cadeira, currentUser, token),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 82,
          height: 72,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: (cadeira.isMinhaReserva || isSameDept) ? 2.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      cadeira.identificador,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveFloorPlanView(
    SeatMapProvider seatProvider,
    UserModel currentUser,
    String token,
  ) {
    // Mapa auxiliar identificador -> CadeiraModel para sincronização em tempo real
    final Map<String, CadeiraModel> cadeiraPorNumero = {};
    if (seatProvider.mapaData != null) {
      for (final baia in seatProvider.mapaData!.baias) {
        for (final cad in baia.cadeiras) {
          cadeiraPorNumero[cad.identificador] = cad;
          final numClean = cad.identificador.replaceAll(RegExp(r'[^0-9]'), '');
          if (numClean.isNotEmpty) {
            cadeiraPorNumero[numClean] = cad;
            cadeiraPorNumero[numClean.padLeft(2, '0')] = cad;
          }
        }
      }
    }

    final officeName = seatProvider.selectedEscritorio?.nome ?? 'Berrini';
    final canonicalDesks = getDesksForOffice(officeName);

    // Sincroniza as mesas do escritório selecionado estritamente com os dados reais do banco de dados
    final desks = canonicalDesks.map((d) {
      final cad = cadeiraPorNumero[d.number];
      DeskStatus status = DeskStatus.available;
      String? occupantName;
      String? occupantDept;

      if (cad != null) {
        if (cad.isMinhaReserva) {
          status = DeskStatus.selected;
          occupantName = '${currentUser.nome} (Você)';
          occupantDept = currentUser.departamentoNome ?? 'Geral';
        } else if (cad.isOcupada) {
          final isSameDept = cad.ocupante != null &&
              cad.ocupante!.departamentoId != null &&
              cad.ocupante!.departamentoId == currentUser.departamentoId;
          status = isSameDept ? DeskStatus.reserved : DeskStatus.occupied;
          occupantName = cad.ocupante?.nome ?? 'Colega';
          occupantDept = cad.ocupante?.departamento ?? 'Geral';
        } else {
          status = DeskStatus.available;
          occupantName = null;
          occupantDept = null;
        }
      }

      return d.copyWith(
        status: status,
        occupantName: occupantName,
        occupantDepartment: occupantDept,
      );
    }).toList();

    return InteractiveFloorPlan(
      key: ValueKey(officeName),
      officeName: officeName,
      desks: desks,
      selectedDesk: _selectedFloorPlanDesk,
      onDeskSelected: (desk) {
        setState(() => _selectedFloorPlanDesk = desk);
      },
      onConfirmBooking: (desk) async {
        final cad = cadeiraPorNumero[desk.number];
        if (cad != null) {
          final res = await seatProvider.reservarOuTrocar(token, cad.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res.message ?? res.error ?? 'Operação concluída.'),
                backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reserva solicitada para a Mesa ${desk.number}!'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      },
    );
  }
}
