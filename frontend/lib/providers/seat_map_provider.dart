import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/seat_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class SeatMapProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final WebSocketService _wsService = WebSocketService();

  List<EscritorioModel> _escritorios = [];
  EscritorioModel? _selectedEscritorio;
  DateTime _selectedDate = DateTime.now();
  MapaDataModel? _mapaData;
  List<ReservaModel> _minhasReservas = [];
  ReservaModel? _reservaHoje;
  ReservaFiltro _filtroReservas = ReservaFiltro.ativas;
  DateTime? _filtroData;
  List<OcupacaoEscritorioModel> _ocupacaoSemanal = [];
  String? _avisoGlobal;
  bool _carregandoOcupacao = false;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _wsSubscription;
  String? _lastToken;

  List<EscritorioModel> get escritorios => _escritorios;
  EscritorioModel? get selectedEscritorio => _selectedEscritorio;
  DateTime get selectedDate => _selectedDate;
  String get selectedDateIso => DateFormat('yyyy-MM-dd').format(_selectedDate);
  MapaDataModel? get mapaData => _mapaData;
  List<ReservaModel> get minhasReservas => _minhasReservas;
  ReservaModel? get reservaHoje => _reservaHoje;
  ReservaFiltro get filtroReservas => _filtroReservas;
  DateTime? get filtroData => _filtroData;
  String? get filtroDataIso => _filtroData != null ? DateFormat('yyyy-MM-dd').format(_filtroData!) : null;
  List<OcupacaoEscritorioModel> get ocupacaoSemanal => _ocupacaoSemanal;
  String? get avisoGlobal => _avisoGlobal;
  bool get agendaPermiteReserva => _mapaData?.agenda.permiteReserva ?? true;
  String? get agendaMotivoBloqueio => _mapaData?.agenda.motivoBloqueio;
  bool get agendaPermiteVisualizacao => _mapaData?.agenda.permiteVisualizacao ?? true;
  int get agendaDiffSemanas => _mapaData?.agenda.diffSemanas ?? 0;
  bool get carregandoOcupacao => _carregandoOcupacao;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setFiltroReservas(ReservaFiltro filtro) {
    _filtroReservas = filtro;
    notifyListeners();
  }

  void setFiltroData(DateTime? data) {
    _filtroData = data;
    notifyListeners();
  }

  void limparFiltroData() {
    _filtroData = null;
    notifyListeners();
  }

  List<ReservaModel> get minhasReservasFiltradas {
    List<ReservaModel> lista;
    switch (_filtroReservas) {
      case ReservaFiltro.ativas:
        lista = _minhasReservas.where((r) => r.isAtiva).toList();
        break;
      case ReservaFiltro.concluidas:
        lista = _minhasReservas.where((r) => r.isConcluida).toList();
        break;
      case ReservaFiltro.canceladas:
        lista = _minhasReservas.where((r) => r.isCancelada).toList();
        break;
      case ReservaFiltro.naoComparecidas:
        lista = _minhasReservas.where((r) => r.isExpirada).toList();
        break;
      case ReservaFiltro.todas:
        lista = _minhasReservas.toList();
        break;
    }

    if (_filtroData != null) {
      final dataIso = DateFormat('yyyy-MM-dd').format(_filtroData!);
      lista = lista.where((r) => r.dataReservaIso == dataIso).toList();
    }

    return lista;
  }

  Map<String, List<ReservaModel>> get minhasReservasAgrupadasPorData {
    final agrupadas = <String, List<ReservaModel>>{};
    for (final r in minhasReservasFiltradas) {
      final chave = r.dataReservaIso;
      if (!agrupadas.containsKey(chave)) {
        agrupadas[chave] = [];
      }
      agrupadas[chave]!.add(r);
    }
    return agrupadas;
  }

  int get totalAtivas => _minhasReservas.where((r) => r.isAtiva).length;
  int get totalConcluidas => _minhasReservas.where((r) => r.isConcluida).length;
  int get totalCanceladas => _minhasReservas.where((r) => r.isCancelada).length;
  int get totalNaoComparecidas => _minhasReservas.where((r) => r.isExpirada).length;

  bool get temCheckinPendenteHoje {
    final hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _reservaHoje != null &&
        _reservaHoje!.dataReserva == hojeStr &&
        _reservaHoje!.isAtiva &&
        !_reservaHoje!.checkinRealizado;
  }

  void prepararTrocaEscritorioPorNome(String termo) {
    if (_escritorios.isNotEmpty) {
      final match = _escritorios.firstWhere(
        (e) => e.nome.toLowerCase().contains(termo.toLowerCase()) || e.cidade.toLowerCase().contains(termo.toLowerCase()),
        orElse: () => _escritorios.first,
      );
      if (_selectedEscritorio?.id != match.id) {
        _selectedEscritorio = match;
        _mapaData = null;
        notifyListeners();
      }
    } else {
      _mapaData = null;
      notifyListeners();
    }
  }

  Future<void> selecionarEscritorioPorNome(String token, String termo) async {
    prepararTrocaEscritorioPorNome(termo);
    if (_escritorios.isEmpty) {
      final escRes = await _apiService.getEscritorios(token);
      if (escRes.success && escRes.data != null) {
        _escritorios = escRes.data!;
      }
    }
    final match = _escritorios.firstWhere(
      (e) => e.nome.toLowerCase().contains(termo.toLowerCase()) || e.cidade.toLowerCase().contains(termo.toLowerCase()),
      orElse: () => _escritorios.isNotEmpty ? _escritorios.first : EscritorioModel(id: 1, nome: termo, cidade: ''),
    );
    await selecionarEscritorio(token, match);
  }

  void initWebSocket(String token) {
    _lastToken = token;
    _wsSubscription?.cancel();
    _wsSubscription = _wsService.seatUpdates.listen((msg) {
      _handleRealtimeMessage(msg);
    });

    if (_selectedEscritorio != null) {
      _wsService.connect(token: token, escritorioId: _selectedEscritorio!.id);
    }
  }

  void _handleRealtimeMessage(Map<String, dynamic> msg) {
    if (msg['tipo'] == 'AVISO_GLOBAL_ATUALIZADO' || msg['evento'] == 'aviso_global_atualizado') {
      _avisoGlobal = msg['aviso']?.toString() ?? '';
      notifyListeners();
      return;
    }

    if (msg['tipo'] == 'STATUS_CADEIRA_ALTERADO') {
      final cadeiraId = msg['cadeiraId'];
      final statusOp = msg['statusOperacional'];
      if (_mapaData != null) {
        for (final baia in _mapaData!.baias) {
          for (final cadeira in baia.cadeiras) {
            if (cadeira.id == cadeiraId) {
              if (statusOp == 'EM_MANUTENCAO') {
                cadeira.status = 'manutencao';
              } else {
                cadeira.status = 'livre';
              }
            }
          }
        }
        notifyListeners();
      }
      return;
    }

    if (msg['evento'] == 'reserva_alterada') {
      if (_lastToken != null) {
        // Atualiza a ocupação semanal do Dashboard imediatamente
        carregarOcupacaoSemanal(_lastToken!);
        
        final msgEscritorioId = msg['escritorioId'];
        final msgData = msg['data'];
        if (_selectedEscritorio != null && _selectedEscritorio!.id == msgEscritorioId && selectedDateIso == msgData) {
          carregarMapaSilencioso(_lastToken!);
        }
      }
      return;
    }

    if (msg['evento'] == 'assento_atualizado') {
      _handleRealtimeSeatUpdate(msg);
    }
  }


  void _handleRealtimeSeatUpdate(Map<String, dynamic> update) {
    if (_mapaData == null) return;

    final escritorioId = update['escritorioId'];
    final cadeiraId = update['cadeiraId'];
    final data = update['data'];
    final novoStatus = update['status'];
    final ocupanteRaw = update['ocupante'];

    // Se o evento for para outro escritório ou data diferente da selecionada, ignora a renderização visual
    if (escritorioId != _selectedEscritorio?.id || data != selectedDateIso) {
      return;
    }

    bool assentoAlterado = false;

    for (final baia in _mapaData!.baias) {
      for (final cadeira in baia.cadeiras) {
        if (cadeira.id == cadeiraId) {
          cadeira.status = novoStatus;
          if (ocupanteRaw != null) {
            cadeira.ocupante = OcupanteModel.fromJson(ocupanteRaw);
          } else {
            cadeira.ocupante = null;
          }
          assentoAlterado = true;
          break;
        }
      }
      if (assentoAlterado) break;
    }

    if (assentoAlterado) {
      _recalcularResumosBaias();
      notifyListeners();
    }
  }

  void _recalcularResumosBaias() {
    if (_mapaData == null) return;
    for (final baia in _mapaData!.baias) {
      int livres = 0;
      final Map<String, int> deptos = {};

      for (final cad in baia.cadeiras) {
        if (cad.isOcupada || cad.isMinhaReserva) {
          final depto = cad.ocupante?.departamento ?? 'Geral';
          deptos[depto] = (deptos[depto] ?? 0) + 1;
        } else {
          livres++;
        }
      }

      final total = baia.totalCadeiras;
      final partes = <String>[];
      if (total > 0) {
        deptos.forEach((d, count) {
          final p = ((count / total) * 100).round();
          partes.add('$p% $d');
        });
        final pLivre = ((livres / total) * 100).round();
        partes.add('$pLivre% Livre');
      }
    }
  }

  Future<void> carregarInicial(String token, UserModel user) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _wsSubscription?.cancel();
    _wsSubscription = _wsService.seatUpdates.listen((msg) {
      _handleRealtimeMessage(msg);
    });

    final escRes = await _apiService.getEscritorios(token);
    if (escRes.success && escRes.data != null && escRes.data!.isNotEmpty) {
      _escritorios = escRes.data!;
      _selectedEscritorio = _escritorios.first;
      _wsService.connect(token: token, escritorioId: _selectedEscritorio!.id);
      await Future.wait([
        carregarMapa(token),
        carregarMinhasReservas(token),
        carregarOcupacaoSemanal(token),
        carregarAvisoGlobal(token),
      ]);
    } else {
      _errorMessage = escRes.error ?? 'Falha ao carregar lista de escritórios.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> carregarAvisoGlobal(String token) async {
    final res = await _apiService.getAvisoGlobal(token);
    if (res.success && res.data != null) {
      _avisoGlobal = res.data;
      notifyListeners();
    }
  }

  Future<void> carregarOcupacaoSemanal(String token) async {
    _carregandoOcupacao = true;
    notifyListeners();

    final res = await _apiService.getOcupacaoSemanal(token);
    _carregandoOcupacao = false;
    if (res.success && res.data != null) {
      _ocupacaoSemanal = res.data!;
    }
    notifyListeners();
  }

  Future<void> selecionarEscritorio(String token, EscritorioModel escritorio) async {
    if (_selectedEscritorio?.id == escritorio.id && _mapaData != null) return;
    _selectedEscritorio = escritorio;
    _mapaData = null; // Zera imediatamente para evitar flash de marcações de outro escritório
    notifyListeners(); // Invalida visualmente no mesmo frame
    _wsService.switchEscritorio(escritorio.id);
    await carregarMapa(token);
  }

  Future<void> selecionarData(String token, DateTime data) async {
    final novaDataIso = DateFormat('yyyy-MM-dd').format(data);
    if (selectedDateIso == novaDataIso && _mapaData != null) return;
    _selectedDate = data;
    _mapaData = null; // Zera imediatamente para evitar flash de reservas de outra data
    notifyListeners(); // Invalida visualmente no mesmo frame
    await carregarMapa(token);
  }

  Future<void> selecionarEscritorioEData(String token, EscritorioModel escritorio, DateTime data) async {
    _selectedEscritorio = escritorio;
    _selectedDate = data;
    _mapaData = null; // Zera imediatamente
    notifyListeners(); // Invalida visualmente no mesmo frame
    _wsService.switchEscritorio(escritorio.id);
    await carregarMapa(token);
  }

  int _mapaRequestId = 0;

  Future<void> carregarMapa(String token) async {
    if (_selectedEscritorio == null) return;
    final reqId = ++_mapaRequestId;
    _isLoading = true;
    notifyListeners();

    final res = await _apiService.getMapa(token, _selectedEscritorio!.id, selectedDateIso);

    // Se outra requisição foi feita nesse meio tempo, descarta esta resposta antiga
    if (reqId != _mapaRequestId) return;

    _isLoading = false;

    if (res.success && res.data != null) {
      // Valida se a resposta corresponde estritamente ao escritório e data atualmente selecionados
      if (res.data!.escritorio.id == _selectedEscritorio!.id && res.data!.data == selectedDateIso) {
        _mapaData = res.data;
      }
    } else {
      _errorMessage = res.error ?? 'Erro ao carregar mapa de assentos.';
    }
    notifyListeners();
  }

  /// Recarrega o mapa em background sem disparar spinners de carregamento na UI
  Future<void> carregarMapaSilencioso(String token) async {
    if (_selectedEscritorio == null) return;
    final reqId = ++_mapaRequestId;
    final res = await _apiService.getMapa(token, _selectedEscritorio!.id, selectedDateIso);
    if (reqId != _mapaRequestId) return;
    if (res.success && res.data != null) {
      if (res.data!.escritorio.id == _selectedEscritorio!.id && res.data!.data == selectedDateIso) {
        _mapaData = res.data;
        notifyListeners();
      }
    }
  }

  Future<void> carregarMinhasReservas(String token) async {
    final res = await _apiService.getMinhasReservas(token);
    if (res.success && res.data != null) {
      _minhasReservas = res.data!;
      final hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      try {
        _reservaHoje = _minhasReservas.firstWhere(
          (r) => r.dataReserva == hojeStr && r.isAtiva,
        );
      } catch (e) {
        _reservaHoje = null;
      }
      notifyListeners();
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> reservarOuTrocar(String token, int cadeiraId) async {
    _isLoading = true;
    notifyListeners();

    final res = await _apiService.criarReserva(token, cadeiraId, selectedDateIso);
    _isLoading = false;

    if (res.success) {
      await carregarMapa(token);
      await carregarMinhasReservas(token);
    } else {
      _errorMessage = res.error;
    }
    notifyListeners();
    return res;
  }

  static int? extrairCadeiraIdDoQr(String rawCode) {
    final trimmed = rawCode.trim();
    if (trimmed.isEmpty) return null;

    // 1. Formato SEATMAP:DESK:escritorioId:cadeiraId ou SEATMAP:DESK:cadeiraId
    if (trimmed.toUpperCase().startsWith('SEATMAP:DESK:')) {
      final parts = trimmed.split(':');
      if (parts.length >= 4) {
        return int.tryParse(parts[3]);
      } else if (parts.length >= 3) {
        return int.tryParse(parts[2]);
      }
    }

    // 2. Formato JSON
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final idVal = decoded['cadeiraId'] ?? decoded['cadeira_id'] ?? decoded['cadeira'] ?? decoded['mesa'] ?? decoded['id'];
          if (idVal != null) return int.tryParse(idVal.toString());
        }
      } catch (e) {
        debugPrint('[SeatMapProvider] Payload QR não é JSON estruturado: $e');
      }
    }

    // 3. Formato DESK_12 / Mesa 12 / 12
    final match = RegExp(r'(?:mesa|cadeira|desk|assento)?[_\s-]*(\d+)', caseSensitive: false).firstMatch(trimmed);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }

    return int.tryParse(trimmed);
  }

  Future<ApiResponse<Map<String, dynamic>>> validarEEfetuarCheckinPorQr(String token, String qrCode) async {
    if (_reservaHoje == null) {
      return ApiResponse(
        success: false,
        error: 'Você não possui nenhuma reserva ativa agendada para o dia de hoje.',
        statusCode: 400,
      );
    }

    final cadeiraLidaId = extrairCadeiraIdDoQr(qrCode);
    if (cadeiraLidaId == null) {
      return ApiResponse(
        success: false,
        error: 'QR Code inválido ou formato não reconhecido ($qrCode).',
        statusCode: 400,
      );
    }

    if (cadeiraLidaId != _reservaHoje!.cadeiraId) {
      return ApiResponse(
        success: false,
        error: 'QR Code lido pertence à Mesa $cadeiraLidaId, mas sua reserva de hoje é para a Mesa ${_reservaHoje!.cadeiraIdentificador}.',
        statusCode: 400,
      );
    }

    _isLoading = true;
    notifyListeners();

    final res = await _apiService.fazerCheckin(token, _reservaHoje!.id, cadeiraId: cadeiraLidaId);
    _isLoading = false;

    if (res.success) {
      await carregarMinhasReservas(token);
      await carregarMapa(token);
      notifyListeners();
    } else {
      _errorMessage = res.error;
      notifyListeners();
    }

    return res;
  }

  Future<bool> confirmarPresencaHoje(String token) async {
    if (_reservaHoje == null) return false;
    _isLoading = true;
    notifyListeners();

    final res = await _apiService.fazerCheckin(token, _reservaHoje!.id, cadeiraId: _reservaHoje!.cadeiraId);
    _isLoading = false;

    if (res.success) {
      await carregarMinhasReservas(token);
      await carregarMapa(token);
      notifyListeners();
      return true;
    } else {
      _errorMessage = res.error;
      notifyListeners();
      return false;
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> cancelarMinhaReserva(String token, int reservaId) async {
    _isLoading = true;
    notifyListeners();

    final res = await _apiService.cancelarReserva(token, reservaId);
    _isLoading = false;

    if (res.success) {
      await carregarMinhasReservas(token);
      await carregarMapa(token);
      notifyListeners();
    } else {
      _errorMessage = res.error;
      notifyListeners();
    }
    return res;
  }

  Future<ApiResponse<Map<String, dynamic>>> liberarMinhaReserva(String token, int reservaId) async {
    _isLoading = true;
    notifyListeners();

    final res = await _apiService.liberarMesa(token, reservaId);
    _isLoading = false;

    if (res.success) {
      await carregarMinhasReservas(token);
      await carregarMapa(token);
      notifyListeners();
    } else {
      _errorMessage = res.error;
      notifyListeners();
    }
    return res;
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsService.disconnect();
    super.dispose();
  }
}

