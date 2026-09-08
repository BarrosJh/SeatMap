import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/desk_model.dart';
import '../models/seat_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/seat_map_provider.dart';
import '../widgets/comprovante_dialog.dart';
import '../widgets/interactive_floor_plan.dart';
import 'mapa/widgets/baia_card_list_view.dart';
import 'mapa/widgets/confirm_booking_dialog.dart';
import 'mapa/widgets/map_control_header.dart';
import 'mapa/widgets/occupant_details_modal.dart';
import 'mapa/widgets/seat_maintenance_dialog.dart';


class MapaScreen extends StatefulWidget {
  final VoidCallback? onNavegarParaCheckin;

  const MapaScreen({super.key, this.onNavegarParaCheckin});

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
        if (seatProvider.mapaData == null) {
          seatProvider.carregarInicial(auth.token!, auth.user!);
        }
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
      locale: const Locale('pt', 'BR'),
      helpText: 'Selecione a Data de Reserva',
      cancelText: 'Cancelar',
      confirmText: 'Selecionar',
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
    if (cadeira.isManutencao) {
      SeatMaintenanceDialog.show(
        context: context,
        cadeira: cadeira,
        currentUser: currentUser,
        token: token,
      );
      return;
    }

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

      ConfirmBookingDialog.showBooking(
        context: context,
        cadeira: cadeira,
        token: token,
      );
    } else if (cadeira.isOcupada || cadeira.isMinhaReserva) {
      OccupantDetailsModal.show(
        context: context,
        cadeira: cadeira,
        currentUser: currentUser,
      );
    }
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

    final bool isMapaDataValido = seatProvider.mapaData != null &&
        seatProvider.selectedEscritorio != null &&
        seatProvider.mapaData!.escritorio.id == seatProvider.selectedEscritorio!.id &&
        seatProvider.mapaData!.data == seatProvider.selectedDateIso;

    if (isMapaDataValido) {
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

    final isRh = auth.user?.isAdmin == true;
    final isNextOpen = auth.user != null && _isDateOpenForBooking(_getBaseMonday(1), auth.user!);
    final canGoBack = isRh ? true : _weekOffset > 0;
    final canGoForward = isRh ? true : (_weekOffset < (isNextOpen ? 1 : 0));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // BARRA DE CONTROLE CORPORATIVA UNIFICADA (MODULAR)
            MapControlHeader(
              user: auth.user,
              token: auth.token,
              seatProvider: seatProvider,
              weekOffset: _weekOffset,
              isFloorPlanView: _isFloorPlanView,
              diasUteis: diasUteis,
              weekLabel: _getWeekLabel(),
              totalAssentos: totalAssentos,
              totalLivres: totalLivres,
              totalOcupadas: totalOcupadas,
              totalMinhas: totalMinhas,
              canGoBack: canGoBack,
              canGoForward: canGoForward,
              onChangeWeek: (delta) {
                if (auth.token != null) _changeWeek(delta, auth.token!);
              },
              onResetToCurrentWeek: () {
                if (auth.token != null) _resetToCurrentWeek(auth.token!);
              },
              onPickCustomDate: () {
                if (auth.token != null) _pickCustomDate(context, auth.token!);
              },
              onSelectDate: (dia) {
                if (auth.token != null) seatProvider.selecionarData(auth.token!, dia);
              },
              onToggleView: (isFloorPlan) {
                setState(() => _isFloorPlanView = isFloorPlan);
              },
            ),

            // CONTEÚDO PRINCIPAL (Planta Baixa Interativa vs Cards de Bancadas)
            Expanded(
              child: !isMapaDataValido
                  ? const Center(child: CircularProgressIndicator())
                  : (_isFloorPlanView
                      ? _buildInteractiveFloorPlanView(seatProvider, auth.user!, auth.token!)
                      : BaiaCardListView(
                          baias: seatProvider.mapaData!.baias,
                          currentUser: auth.user!,
                          token: auth.token!,
                          onCadeiraTapped: (cadeira) => _onCadeiraTapped(cadeira, auth.user!, auth.token!),
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
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                      label: const Text('Ler QR Code / Check-in', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        widget.onNavegarParaCheckin?.call();
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

  // Cache de Memoização de Alta Performance para evitar alocações de 102 desks por frame
  MapaDataModel? _cachedMapaDataRef;
  String? _cachedDateIso;
  String? _cachedOfficeName;
  UserModel? _cachedUserRef;
  List<DeskModel> _cachedDesks = const [];
  Map<String, CadeiraModel> _cachedChairMap = const {};

  Widget _buildInteractiveFloorPlanView(
    SeatMapProvider seatProvider,
    UserModel currentUser,
    String token,
  ) {
    final officeName = seatProvider.selectedEscritorio?.nome ?? 'Berrini';
    final dateIso = seatProvider.selectedDateIso;
    final currentMapaData = seatProvider.mapaData;

    // Se o escritório mudou, limpa a seleção de mesa ativa
    if (_cachedOfficeName != officeName) {
      _selectedFloorPlanDesk = null;
    }

    final isMatching = currentMapaData != null &&
        seatProvider.selectedEscritorio != null &&
        currentMapaData.escritorio.id == seatProvider.selectedEscritorio!.id &&
        currentMapaData.data == dateIso;

    // Se os dados não mudaram, reutiliza o mapa de cadeiras e a lista de desks em memória
    if (_cachedMapaDataRef != currentMapaData ||
        _cachedDateIso != dateIso ||
        _cachedOfficeName != officeName ||
        _cachedUserRef != currentUser) {
      
      final Map<String, CadeiraModel> cadeiraPorNumero = {};
      if (isMatching) {
        for (final baia in currentMapaData.baias) {
          for (final cad in baia.cadeiras) {
            final idStr = cad.identificador;
            cadeiraPorNumero[idStr] = cad;

            // Extração rápida de dígitos sem compilar RegExp por item
            final sb = StringBuffer();
            for (int i = 0; i < idStr.length; i++) {
              final code = idStr.codeUnitAt(i);
              if (code >= 48 && code <= 57) sb.writeCharCode(code);
            }
            final numClean = sb.toString();
            if (numClean.isNotEmpty) {
              cadeiraPorNumero[numClean] = cad;
              if (numClean.length == 1) {
                cadeiraPorNumero['0$numClean'] = cad;
              }
            }
          }
        }
      }

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
      }).toList(growable: false);

      _cachedMapaDataRef = currentMapaData;
      _cachedDateIso = dateIso;
      _cachedOfficeName = officeName;
      _cachedUserRef = currentUser;
      _cachedDesks = List.unmodifiable(desks);
      _cachedChairMap = Map.unmodifiable(cadeiraPorNumero);
    }

    final cadeiraPorNumero = _cachedChairMap;
    final desks = _cachedDesks;

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
                cadeiraIdentificador: cad.identificador,
                usuarioNome: currentUser.nome,
                usuarioMatricula: currentUser.matricula,
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
        }
      },
      onCancelBooking: (desk) async {
        final cad = cadeiraPorNumero[desk.number];
        final reserva = seatProvider.minhasReservas.where(
          (r) => r.isAtiva && (r.cadeiraId == cad?.id || r.dataReserva == seatProvider.selectedDateIso)
        ).firstOrNull;

        if (reserva != null) {
          if (reserva.checkinRealizado) {
            ConfirmBookingDialog.showLiberar(
              context: context,
              reserva: reserva,
              token: token,
            );
          } else {
            ConfirmBookingDialog.showCancel(
              context: context,
              reserva: reserva,
              token: token,
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhuma reserva ativa encontrada para este assento.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }
}
