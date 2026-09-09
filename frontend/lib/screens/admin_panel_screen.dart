import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/admin_models.dart';
import '../models/seat_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'admin/tabs/tab_departamentos.dart';
import 'admin/tabs/tab_importacao_lote.dart';
import 'admin/tabs/tab_manutencao.dart';
import 'admin/tabs/tab_politicas.dart';
import 'admin/tabs/tab_relatorios.dart';
import 'admin/tabs/tab_reservas_global.dart';
import 'admin/tabs/tab_usuarios.dart';
import 'admin/modals/modal_cancelar_reserva.dart';
import 'admin/modals/modal_departamento_form.dart';
import 'admin/modals/modal_reset_senha.dart';
import 'admin/modals/modal_usuario_form.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  bool _isLoading = false;
  List<DepartamentoModel> _departamentos = [];
  List<EscritorioModel> _escritorios = [];

  // TAB 1: Usuários
  List<AdminUsuarioModel> _usuarios = [];
  final _searchUsuarioController = TextEditingController();
  String _filtroDepUsuario = 'todos';
  String _filtroPerfilUsuario = 'todos';
  String _filtroStatusUsuario = 'todos';
  int _totalUsuarios = 0;

  // TAB 2: Importação em Lote
  final _loteTextController = TextEditingController();
  final _loteDefaultSenhaController = TextEditingController(text: 'Mudar@123');
  List<Map<String, dynamic>> _lotePreview = [];
  Map<String, dynamic>? _loteResultado;

  // TAB 3: Gestão de Reservas
  List<AdminReservaModel> _reservas = [];
  final _searchReservaController = TextEditingController();
  DateTime _filtroDataInicio = DateTime.now().subtract(const Duration(days: 7));
  DateTime _filtroDataFim = DateTime.now().add(const Duration(days: 14));
  String _filtroEscritorioReserva = 'todos';
  final String _filtroDepReserva = 'todos';
  String _filtroStatusReserva = 'todos';
  int _totalReservas = 0;

  // TAB 4: Departamentos
  final _novoDepController = TextEditingController();

  // TAB 5: Políticas de Agendamento
  final _limiteSemanalController = TextEditingController();
  final _horarioGestaoController = TextEditingController();
  final _horarioColabController = TextEditingController();
  final _horarioInicioCheckinController = TextEditingController();
  final _horarioCheckinController = TextEditingController();
  final _horarioInicioReservaTardiaController = TextEditingController();
  final _toleranciaCheckinTardiaController = TextEditingController();
  final _avisoGlobalController = TextEditingController();
  String _diaGestao = '5';
  String _diaColab = '5';
  bool _permitirTroca = true;
  bool _checkinAutoGestao = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _carregarDadosIniciais();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchUsuarioController.dispose();
    _loteTextController.dispose();
    _loteDefaultSenhaController.dispose();
    _searchReservaController.dispose();
    _novoDepController.dispose();
    _limiteSemanalController.dispose();
    _horarioGestaoController.dispose();
    _horarioColabController.dispose();
    _horarioInicioCheckinController.dispose();
    _horarioCheckinController.dispose();
    _horarioInicioReservaTardiaController.dispose();
    _toleranciaCheckinTardiaController.dispose();
    _avisoGlobalController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosIniciais() async {
    if (mounted) setState(() => _isLoading = true);
    await Future.wait([
      _carregarDepartamentos(setLoading: false),
      _carregarEscritorios(setLoading: false),
      _carregarUsuarios(setLoading: false),
      _carregarReservas(setLoading: false),
      _carregarParametros(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  // ==========================================
  // CARREGAMENTO DE DADOS
  // ==========================================
  Future<void> _carregarEscritorios({bool setLoading = true}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    if (setLoading && mounted) setState(() => _isLoading = true);
    final res = await _apiService.getEscritorios(auth.token!);
    if (mounted) {
      if (setLoading) _isLoading = false;
      if (res.success && res.data != null) {
        setState(() => _escritorios = res.data!);
      }
    }
  }
  Future<void> _carregarDepartamentos({bool setLoading = true}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    if (setLoading && mounted) setState(() => _isLoading = true);
    final res = await _apiService.getDepartamentosAdmin(auth.token!, auth.adminToken ?? auth.token!);
    if (mounted) {
      if (setLoading) _isLoading = false;
      if (res.success && res.data != null) {
        setState(() => _departamentos = res.data!);
      } else if (setLoading) {
        setState(() {});
      }
    }
  }

  Future<void> _carregarUsuarios({bool setLoading = true}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    if (setLoading && mounted) setState(() => _isLoading = true);
    final res = await _apiService.getUsuariosAdmin(
      auth.token!,
      auth.adminToken ?? auth.token!,
      busca: _searchUsuarioController.text.trim(),
      departamentoId: _filtroDepUsuario,
      perfil: _filtroPerfilUsuario,
      ativo: _filtroStatusUsuario,
    );

    if (mounted) {
      setState(() {
        if (setLoading) _isLoading = false;
        if (res.success && res.data != null) {
          _usuarios = res.data!['usuarios'] as List<AdminUsuarioModel>;
          _totalUsuarios = res.data!['total'] as int;
        } else if (!res.success && res.error != null && setLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.error ?? 'Erro ao listar colaboradores.'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      });
    }
  }

  Future<void> _carregarReservas({bool setLoading = true}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    if (setLoading && mounted) setState(() => _isLoading = true);
    final res = await _apiService.getReservasAdmin(
      auth.token!,
      auth.adminToken ?? auth.token!,
      dataInicio: DateFormat('yyyy-MM-dd').format(_filtroDataInicio),
      dataFim: DateFormat('yyyy-MM-dd').format(_filtroDataFim),
      escritorioId: _filtroEscritorioReserva,
      departamentoId: _filtroDepReserva,
      status: _filtroStatusReserva,
      busca: _searchReservaController.text.trim(),
    );

    if (mounted) {
      setState(() {
        if (setLoading) _isLoading = false;
        if (res.success && res.data != null) {
          _reservas = res.data!['reservas'] as List<AdminReservaModel>;
          _totalReservas = res.data!['total'] as int;
        }
      });
    }
  }

  Future<void> _carregarParametros() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    final res = await _apiService.getParametros(auth.token!, auth.adminToken ?? auth.token!);
    if (res.success && res.data != null && mounted) {
      final list = res.data as List;
      for (final item in list) {
        final chave = item['chave'];
        final valor = item['valor']?.toString() ?? '';
        if (chave == 'LIMITE_SEMANAL_RESERVAS') _limiteSemanalController.text = valor;
        if (chave == 'HORARIO_ABERTURA_GESTAO') _horarioGestaoController.text = valor;
        if (chave == 'HORARIO_ABERTURA_COLABORADOR') _horarioColabController.text = valor;
        if (chave == 'HORARIO_INICIO_CHECKIN') _horarioInicioCheckinController.text = valor;
        if (chave == 'HORARIO_LIMITE_CHECKIN') _horarioCheckinController.text = valor;
        if (chave == 'HORARIO_INICIO_RESERVA_TARDIA') _horarioInicioReservaTardiaController.text = valor;
        if (chave == 'TOLERANCIA_CHECKIN_RESERVA_TARDIA_MINUTOS') _toleranciaCheckinTardiaController.text = valor;
        if (chave == 'DIA_ABERTURA_GESTAO') _diaGestao = valor;
        if (chave == 'DIA_ABERTURA_COLABORADOR') _diaColab = valor;
        if (chave == 'PERMITIR_TROCA_MESMO_DIA') _permitirTroca = (valor == 'true');
        if (chave == 'CHECKIN_AUTOMATICO_GESTAO') _checkinAutoGestao = (valor == 'true');
        if (chave == 'AVISO_GLOBAL_SISTEMA') _avisoGlobalController.text = valor;
      }
      setState(() {});
    }
  }

  // ==========================================
  // AÇÕES: USUÁRIOS
  // ==========================================
  void _abrirModalUsuario({AdminUsuarioModel? usuario}) {
    ModalUsuarioForm.show(
      context,
      usuario: usuario,
      departamentos: _departamentos,
      onSalvo: () async {
        await _carregarUsuarios();
        await _carregarDepartamentos();
      },
    );
  }

  void _abrirModalResetSenha(AdminUsuarioModel usuario) {
    ModalResetSenha.show(
      context,
      usuario: usuario,
      onSucesso: () => _carregarUsuarios(),
    );
  }

  Future<void> _toggleStatusUsuario(AdminUsuarioModel usuario) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    if (auth.token == null || auth.adminToken == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(usuario.ativo ? 'Desativar Usuário' : 'Reativar Usuário'),
        content: Text('Deseja realmente ${usuario.ativo ? "desativar" : "reativar"} o acesso de ${usuario.nome}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: usuario.ativo ? Colors.red.shade700 : Colors.green.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(usuario.ativo ? 'Desativar' : 'Reativar', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);
    final res = await _apiService.toggleStatusUsuarioAdmin(auth.token!, auth.adminToken!, usuario.id, ativo: !usuario.ativo);
    setState(() => _isLoading = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(res.message ?? res.error ?? 'Status alterado.'),
        backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
    await _carregarUsuarios();
  }

  // ==========================================
  // AÇÕES: IMPORTAÇÃO EM LOTE
  // ==========================================
  void _processarPreviaLote() {
    final raw = _loteTextController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _lotePreview = [];
        _loteResultado = null;
      });
      return;
    }

    final lines = raw.split(RegExp(r'\r?\n'));
    final List<Map<String, dynamic>> parsed = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (i == 0 && (line.toLowerCase().contains('nome') || line.toLowerCase().contains('email'))) {
        continue;
      }

      final delimiter = line.contains(';') ? ';' : (line.contains('\t') ? '\t' : ',');
      final parts = line.split(delimiter).map((p) => p.replaceAll('"', '').trim()).toList();

      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        parsed.add({
          'nome': parts.isNotEmpty ? parts[0] : '',
          'email': parts.length > 1 ? parts[1] : '',
          'matricula': parts.length > 2 ? parts[2] : '',
          'departamento': parts.length > 3 ? parts[3] : '',
          'perfil': parts.length > 4 && parts[4].isNotEmpty ? parts[4].toUpperCase() : 'COLABORADOR',
          'senha': parts.length > 5 && parts[5].isNotEmpty ? parts[5] : _loteDefaultSenhaController.text.trim(),
        });
      }
    }

    setState(() {
      _lotePreview = parsed;
      _loteResultado = null;
    });
  }

  void _carregarExemploCsv() {
    _loteTextController.text =
        'Nome;Email;Matricula;Departamento;Perfil\n'
        'Carlos Mendes;carlos.mendes@empresa.com;MAT0091;Tecnologia;COLABORADOR\n'
        'Fernanda Lima;fernanda.lima@empresa.com;MAT0092;Recursos Humanos;GESTAO\n'
        'Rodrigo Silva;rodrigo.silva@empresa.com;MAT0093;Operações;COLABORADOR\n'
        'Mariana Costa;mariana.costa@empresa.com;MAT0094;Comercial;COLABORADOR';
    _processarPreviaLote();
  }

  Future<void> _executarImportacaoLote() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    if (auth.token == null || auth.adminToken == null) return;

    if (_lotePreview.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nenhum registro para importar. Cole dados em CSV ou gere o exemplo.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    final res = await _apiService.importarLoteUsuariosAdmin(
      auth.token!,
      auth.adminToken!,
      _lotePreview,
      defaultSenha: _loteDefaultSenhaController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (mounted) {
      setState(() {
        _loteResultado = res.data;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(res.message ?? res.error ?? 'Processamento concluído.'),
          backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
        ),
      );
      await _carregarUsuarios();
      await _carregarDepartamentos();
    }
  }

  // ==========================================
  // AÇÕES: RESERVAS (CANCELAMENTO RH)
  // ==========================================
  void _abrirModalCancelarReserva(AdminReservaModel reserva) {
    ModalCancelarReserva.show(
      context,
      reserva: reserva,
      onCancelado: () => _carregarReservas(),
    );
  }

  // ==========================================
  // AÇÕES: DEPARTAMENTOS
  // ==========================================
  void _abrirModalNovoDepartamento() {
    ModalDepartamentoForm.show(
      context,
      onSalvo: () => _carregarDepartamentos(),
    );
  }

  // ==========================================
  // AÇÕES: PARÂMETROS & POLÍTICAS
  // ==========================================
  Future<void> _salvarParametros() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    if (auth.token == null || auth.adminToken == null) return;

    setState(() => _isLoading = true);
    final payload = [
      {'chave': 'LIMITE_SEMANAL_RESERVAS', 'valor': _limiteSemanalController.text.trim()},
      {'chave': 'HORARIO_ABERTURA_GESTAO', 'valor': _horarioGestaoController.text.trim()},
      {'chave': 'DIA_ABERTURA_GESTAO', 'valor': _diaGestao},
      {'chave': 'HORARIO_ABERTURA_COLABORADOR', 'valor': _horarioColabController.text.trim()},
      {'chave': 'DIA_ABERTURA_COLABORADOR', 'valor': _diaColab},
      {'chave': 'HORARIO_INICIO_CHECKIN', 'valor': _horarioInicioCheckinController.text.trim()},
      {'chave': 'HORARIO_LIMITE_CHECKIN', 'valor': _horarioCheckinController.text.trim()},
      {'chave': 'HORARIO_INICIO_RESERVA_TARDIA', 'valor': _horarioInicioReservaTardiaController.text.trim()},
      {'chave': 'TOLERANCIA_CHECKIN_RESERVA_TARDIA_MINUTOS', 'valor': _toleranciaCheckinTardiaController.text.trim()},
      {'chave': 'PERMITIR_TROCA_MESMO_DIA', 'valor': _permitirTroca.toString()},
      {'chave': 'CHECKIN_AUTOMATICO_GESTAO', 'valor': _checkinAutoGestao.toString()},
      {'chave': 'AVISO_GLOBAL_SISTEMA', 'valor': _avisoGlobalController.text.trim()},
    ];

    final res = await _apiService.updateParametros(auth.token!, auth.adminToken!, payload);
    setState(() => _isLoading = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(res.message ?? res.error ?? 'Configurações salvas.'),
        backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  Future<void> _executarLimpezaEmergencial() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    if (auth.token == null || auth.adminToken == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Executar Limpeza de No-Show'),
        content: const Text(
          'Deseja disparar agora a rotina de cancelamento para todas as reservas de hoje que ainda não realizaram check-in e liberar os assentos?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Executar Agora', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);
    final res = await _apiService.executarLimpezaNoShow(auth.token!, auth.adminToken!);
    setState(() => _isLoading = false);

    final total = res.data?['totalExpiradas'] ?? 0;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Limpeza concluída! $total reservas foram expiradas por No-Show.'),
        backgroundColor: Colors.green.shade700,
      ),
    );
    await _carregarReservas();
  }

  // ==========================================
  // BUILD PRINCIPAL & TABS
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Painel de Gestão do RH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.today_rounded, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(
                  DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_outlined, size: 20), text: 'Usuários'),
            Tab(icon: Icon(Icons.upload_file_outlined, size: 20), text: 'Importação em Lote'),
            Tab(icon: Icon(Icons.event_seat_outlined, size: 20), text: 'Reservas'),
            Tab(icon: Icon(Icons.build_rounded, size: 20), text: 'Manutenção & Facilities'),
            Tab(icon: Icon(Icons.domain_outlined, size: 20), text: 'Departamentos'),
            Tab(icon: Icon(Icons.tune_rounded, size: 20), text: 'Políticas de Agendamento'),
            Tab(icon: Icon(Icons.analytics_rounded, size: 20), text: 'Relatórios & BI'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                TabUsuarios(
                  usuarios: _usuarios,
                  departamentos: _departamentos,
                  totalUsuarios: _totalUsuarios,
                  searchController: _searchUsuarioController,
                  filtroDep: _filtroDepUsuario,
                  filtroPerfil: _filtroPerfilUsuario,
                  filtroStatus: _filtroStatusUsuario,
                  onFiltroDepChanged: (v) {
                    setState(() => _filtroDepUsuario = v ?? 'todos');
                    _carregarUsuarios();
                  },
                  onFiltroPerfilChanged: (v) {
                    setState(() => _filtroPerfilUsuario = v ?? 'todos');
                    _carregarUsuarios();
                  },
                  onFiltroStatusChanged: (v) {
                    setState(() => _filtroStatusUsuario = v ?? 'todos');
                    _carregarUsuarios();
                  },
                  onBuscar: _carregarUsuarios,
                  onNovoUsuario: () => _abrirModalUsuario(),
                  onEditarUsuario: (u) => _abrirModalUsuario(usuario: u),
                  onResetSenha: (u) => _abrirModalResetSenha(u),
                  onToggleStatus: (u) => _toggleStatusUsuario(u),
                ),
                TabImportacaoLote(
                  loteTextController: _loteTextController,
                  loteDefaultSenhaController: _loteDefaultSenhaController,
                  lotePreview: _lotePreview,
                  loteResultado: _loteResultado,
                  onProcessarPrevia: _processarPreviaLote,
                  onCarregarExemplo: _carregarExemploCsv,
                  onExecutarImportacao: _executarImportacaoLote,
                ),
                TabReservasGlobal(
                  reservas: _reservas,
                  totalReservas: _totalReservas,
                  searchController: _searchReservaController,
                  filtroDataInicio: _filtroDataInicio,
                  filtroDataFim: _filtroDataFim,
                  filtroEscritorio: _filtroEscritorioReserva,
                  filtroStatus: _filtroStatusReserva,
                  onBuscar: _carregarReservas,
                  onDataInicioChanged: (d) {
                    setState(() => _filtroDataInicio = d);
                    _carregarReservas();
                  },
                  onDataFimChanged: (d) {
                    setState(() => _filtroDataFim = d);
                    _carregarReservas();
                  },
                  onEscritorioChanged: (v) {
                    setState(() => _filtroEscritorioReserva = v ?? 'todos');
                    _carregarReservas();
                  },
                  onStatusChanged: (v) {
                    setState(() => _filtroStatusReserva = v ?? 'todos');
                    _carregarReservas();
                  },
                  onCancelarReserva: (r) => _abrirModalCancelarReserva(r),
                ),
                TabManutencao(
                  token: auth.token ?? '',
                  adminToken: auth.adminToken,
                  escritorios: _escritorios,
                ),
                TabDepartamentos(
                  departamentos: _departamentos,
                  onNovoDepartamento: _abrirModalNovoDepartamento,
                ),
                TabPoliticas(
                  limiteSemanalController: _limiteSemanalController,
                  horarioGestaoController: _horarioGestaoController,
                  horarioColabController: _horarioColabController,
                  horarioInicioCheckinController: _horarioInicioCheckinController,
                  horarioCheckinController: _horarioCheckinController,
                  horarioInicioReservaTardiaController: _horarioInicioReservaTardiaController,
                  toleranciaCheckinTardiaController: _toleranciaCheckinTardiaController,
                  avisoGlobalController: _avisoGlobalController,
                  diaGestao: _diaGestao,
                  diaColab: _diaColab,
                  permitirTroca: _permitirTroca,
                  checkinAutoGestao: _checkinAutoGestao,
                  onDiaGestaoChanged: (v) => setState(() => _diaGestao = v ?? '5'),
                  onDiaColabChanged: (v) => setState(() => _diaColab = v ?? '5'),
                  onPermitirTrocaChanged: (v) => setState(() => _permitirTroca = v),
                  onCheckinAutoGestaoChanged: (v) => setState(() => _checkinAutoGestao = v),
                  onSalvarParametros: _salvarParametros,
                  onExecutarLimpezaNoShow: _executarLimpezaEmergencial,
                ),
                TabRelatorios(
                  departamentos: _departamentos,
                  escritorios: _escritorios,
                ),
              ],
            ),
    );
  }
}
