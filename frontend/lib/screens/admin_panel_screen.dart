import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/admin_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

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

  // TAB 5: Políticas & Relatórios
  final _limiteSemanalController = TextEditingController();
  final _horarioGestaoController = TextEditingController();
  final _horarioColabController = TextEditingController();
  final _horarioCheckinController = TextEditingController();
  String _diaGestao = '5';
  String _diaColab = '5';
  DateTime _dataRelatorio = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
    _horarioCheckinController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosIniciais() async {
    if (mounted) setState(() => _isLoading = true);
    await Future.wait([
      _carregarDepartamentos(setLoading: false),
      _carregarUsuarios(setLoading: false),
      _carregarReservas(setLoading: false),
      _carregarParametros(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  // ==========================================
  // CARREGAMENTO DE DADOS
  // ==========================================
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
        final valor = item['valor'];
        if (chave == 'LIMITE_SEMANAL_RESERVAS') _limiteSemanalController.text = valor;
        if (chave == 'HORARIO_ABERTURA_GESTAO') _horarioGestaoController.text = valor;
        if (chave == 'HORARIO_ABERTURA_COLABORADOR') _horarioColabController.text = valor;
        if (chave == 'HORARIO_LIMITE_CHECKIN') _horarioCheckinController.text = valor;
        if (chave == 'DIA_ABERTURA_GESTAO') _diaGestao = valor;
        if (chave == 'DIA_ABERTURA_COLABORADOR') _diaColab = valor;
      }
    }
  }

  // ==========================================
  // AÇÕES: USUÁRIOS
  // ==========================================
  void _abrirModalUsuario({AdminUsuarioModel? usuario}) {
    final nomeCtrl = TextEditingController(text: usuario?.nome ?? '');
    final emailCtrl = TextEditingController(text: usuario?.email ?? '');
    final matCtrl = TextEditingController(text: usuario?.matricula ?? '');
    final senhaCtrl = TextEditingController();
    int? selectedDep = usuario?.departamentoId;
    String selectedPerfil = (usuario?.perfil == 'GESTAO') ? 'GESTAO' : 'COLABORADOR';
    bool permissaoRh = usuario?.permissaoRh ?? (usuario?.perfil == 'ADMIN_RH');
    bool ativo = usuario?.ativo ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Icon(usuario == null ? Icons.person_add_alt_1_rounded : Icons.manage_accounts_rounded, color: const Color(0xFF0F172A)),
              const SizedBox(width: 10),
              Text(
                usuario == null ? 'Novo Usuário' : 'Editar Usuário',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  // Linha 1: Nome e Matrícula
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: nomeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nome Completo *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: matCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Matrícula *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge_outlined, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Linha 2: E-mail e Senha (se novo)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: usuario == null ? 3 : 1,
                        child: TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'E-mail Corporativo *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                          ),
                        ),
                      ),
                      if (usuario == null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: senhaCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Senha Inicial *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock_outline, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Linha 3: Departamento e Perfil Funcional
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          initialValue: selectedDep,
                          decoration: const InputDecoration(
                            labelText: 'Departamento',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.domain_outlined, size: 20),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Nenhum / Geral')),
                            ..._departamentos.map((d) => DropdownMenuItem(value: d.id, child: Text(d.nome))),
                          ],
                          onChanged: (v) => setModalState(() => selectedDep = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedPerfil,
                          decoration: const InputDecoration(
                            labelText: 'Perfil Funcional *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge_rounded, size: 20),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'COLABORADOR', child: Text('Colaborador (Faz Check-in)')),
                            DropdownMenuItem(value: 'GESTAO', child: Text('Gestão (Isento Check-in)')),
                          ],
                          onChanged: (v) => setModalState(() => selectedPerfil = v ?? 'COLABORADOR'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Permissão Especial de RH
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: permissaoRh ? Colors.purple.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: permissaoRh ? Colors.purple.shade300 : Colors.grey.shade300),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        permissaoRh ? 'Permissão Especial de RH (Ativa)' : 'Permissão Especial de RH (Inativa)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: permissaoRh ? Colors.purple.shade900 : Colors.grey.shade800,
                        ),
                      ),
                      subtitle: const Text(
                        'Acesso ao painel administrativo e navegação irrestrita no mapa.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      value: permissaoRh,
                      activeThumbColor: Colors.purple.shade700,
                      onChanged: (v) => setModalState(() => permissaoRh = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Status Ativo / Inativo
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: ativo ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ativo ? Colors.green.shade200 : Colors.red.shade200),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        ativo ? 'Usuário Ativo (Acesso Liberado)' : 'Usuário Inativo (Acesso Bloqueado)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: ativo ? Colors.green.shade900 : Colors.red.shade900,
                        ),
                      ),
                      value: ativo,
                      activeThumbColor: Colors.green.shade700,
                      onChanged: (v) => setModalState(() => ativo = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final messenger = ScaffoldMessenger.of(context);
                if (auth.token == null || auth.adminToken == null) return;

                if (nomeCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty || matCtrl.text.trim().isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Preencha os campos obrigatórios (*).'), backgroundColor: Colors.red),
                  );
                  return;
                }

                if (usuario == null && senhaCtrl.text.trim().isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Informe uma senha inicial.'), backgroundColor: Colors.red),
                  );
                  return;
                }

                Navigator.pop(ctx);
                setState(() => _isLoading = true);

                if (usuario == null) {
                  final res = await _apiService.criarUsuarioAdmin(auth.token!, auth.adminToken!, {
                    'nome': nomeCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'matricula': matCtrl.text.trim(),
                    'senha': senhaCtrl.text.trim(),
                    'departamentoId': selectedDep,
                    'perfil': selectedPerfil,
                    'permissaoRh': permissaoRh,
                    'ativo': ativo,
                  });
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(res.message ?? res.error ?? 'Usuário criado.'),
                      backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  );
                } else {
                  final res = await _apiService.updateUsuarioAdmin(auth.token!, auth.adminToken!, usuario.id, {
                    'nome': nomeCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'matricula': matCtrl.text.trim(),
                    'departamentoId': selectedDep,
                    'perfil': selectedPerfil,
                    'permissaoRh': permissaoRh,
                    'ativo': ativo,
                  });
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(res.message ?? res.error ?? 'Usuário atualizado.'),
                      backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  );
                }

                await _carregarUsuarios();
                await _carregarDepartamentos();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirModalResetSenha(AdminUsuarioModel usuario) {
    final senhaCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Redefinir Senha: ${usuario.nome}'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('E-mail: ${usuario.email} | Matrícula: ${usuario.matricula}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
              const SizedBox(height: 16),
              TextField(
                controller: senhaCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nova Senha *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_reset),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade800, foregroundColor: Colors.white),
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final messenger = ScaffoldMessenger.of(context);
              if (auth.token == null || auth.adminToken == null) return;

              if (senhaCtrl.text.trim().length < 4) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('A senha deve possuir pelo menos 4 caracteres.'), backgroundColor: Colors.red),
                );
                return;
              }

              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              final res = await _apiService.resetSenhaUsuarioAdmin(auth.token!, auth.adminToken!, usuario.id, senhaCtrl.text.trim());
              setState(() => _isLoading = false);

              messenger.showSnackBar(
                SnackBar(
                  content: Text(res.message ?? res.error ?? 'Senha alterada com sucesso.'),
                  backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
                ),
              );
            },
            child: const Text('Confirmar Nova Senha'),
          ),
        ],
      ),
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
    final justCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Cancelar Reserva (Gestão/RH)'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Colaborador: ${reserva.usuarioNome} (${reserva.matricula})', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Data: ${reserva.dataReserva} | Assento: ${reserva.assento} (${reserva.baiaNome})'),
              const SizedBox(height: 4),
              Text('Escritório: ${reserva.escritorioNome}'),
              const SizedBox(height: 16),
              TextField(
                controller: justCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Justificativa do Cancelamento (Opcional)',
                  hintText: 'Ex: Mudança de escala, evento corporativo...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Voltar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final messenger = ScaffoldMessenger.of(context);
              if (auth.token == null || auth.adminToken == null) return;

              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              final res = await _apiService.cancelarReservaAdmin(
                auth.token!,
                auth.adminToken!,
                reserva.id,
                justificativa: justCtrl.text.trim(),
              );
              setState(() => _isLoading = false);

              messenger.showSnackBar(
                SnackBar(
                  content: Text(res.message ?? res.error ?? 'Reserva cancelada.'),
                  backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
                ),
              );
              await _carregarReservas();
            },
            child: const Text('Confirmar Cancelamento'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // AÇÕES: DEPARTAMENTOS
  // ==========================================
  void _abrirModalNovoDepartamento() {
    _novoDepController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Novo Departamento'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: _novoDepController,
            decoration: const InputDecoration(
              labelText: 'Nome do Departamento *',
              border: OutlineInputBorder(),
              hintText: 'Ex: Financeiro, Recursos Humanos...',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white),
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final messenger = ScaffoldMessenger.of(context);
              if (auth.token == null || auth.adminToken == null) return;

              if (_novoDepController.text.trim().isEmpty) return;

              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              final res = await _apiService.criarDepartamentoAdmin(
                auth.token!,
                auth.adminToken!,
                _novoDepController.text.trim(),
              );
              setState(() => _isLoading = false);

              messenger.showSnackBar(
                SnackBar(
                  content: Text(res.message ?? res.error ?? 'Departamento criado.'),
                  backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
                ),
              );
              await _carregarDepartamentos();
            },
            child: const Text('Criar Departamento'),
          ),
        ],
      ),
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
      {'chave': 'HORARIO_LIMITE_CHECKIN', 'valor': _horarioCheckinController.text.trim()},
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

  void _exportarCsv() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null || auth.adminToken == null) return;

    final dataIso = DateFormat('yyyy-MM-dd').format(_dataRelatorio);
    final url = '${AppConstants.baseUrl}/admin/relatorio/exportar?data=$dataIso';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Relatório de Ocupação'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Relatório referente a: $dataIso'),
            const SizedBox(height: 12),
            const Text(
              'O relatório em formato CSV contém os registros detalhados de presença, matrículas, horários de check-in e alocações de assentos.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            SelectableText(
              'Endpoint: $url',
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Baixar CSV'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Download do relatório de $dataIso iniciado.'),
                  backgroundColor: Colors.green.shade700,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BUILD PRINCIPAL & TABS
  // ==========================================
  @override
  Widget build(BuildContext context) {
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
            Tab(icon: Icon(Icons.domain_outlined, size: 20), text: 'Departamentos'),
            Tab(icon: Icon(Icons.settings_suggest_outlined, size: 20), text: 'Políticas & Relatórios'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTabUsuarios(),
                _buildTabImportacaoLote(),
                _buildTabReservas(),
                _buildTabDepartamentos(),
                _buildTabPoliticas(),
              ],
            ),
    );
  }

  // ==========================================
  // TAB 1: GESTÃO DE USUÁRIOS
  // ==========================================
  Widget _buildTabUsuarios() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: LayoutBuilder(
                    builder: (context, filterConstraints) {
                      final isMobileFilter = filterConstraints.maxWidth < 650;

                      final searchField = TextField(
                        controller: _searchUsuarioController,
                        decoration: const InputDecoration(
                          hintText: 'Buscar por nome, e-mail ou matrícula...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _carregarUsuarios(),
                      );

                      final btnBuscar = ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        icon: const Icon(Icons.search),
                        label: const Text('Buscar'),
                        onPressed: _carregarUsuarios,
                      );

                      final btnNovo = ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Novo Usuário'),
                        onPressed: () => _abrirModalUsuario(),
                      );

                      final dropDepto = DropdownButtonFormField<String>(
                        initialValue: _filtroDepUsuario,
                        decoration: const InputDecoration(labelText: 'Departamento', isDense: true, border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem(value: 'todos', child: Text('Todos os Departamentos', overflow: TextOverflow.ellipsis)),
                          ..._departamentos.map((d) => DropdownMenuItem(value: d.id.toString(), child: Text(d.nome, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) {
                          setState(() => _filtroDepUsuario = v ?? 'todos');
                          _carregarUsuarios();
                        },
                      );

                      final dropPerfil = DropdownButtonFormField<String>(
                        initialValue: _filtroPerfilUsuario,
                        decoration: const InputDecoration(labelText: 'Perfil', isDense: true, border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'todos', child: Text('Todos os Perfis')),
                          DropdownMenuItem(value: 'COLABORADOR', child: Text('Colaborador')),
                          DropdownMenuItem(value: 'GESTAO', child: Text('Gestão')),
                          DropdownMenuItem(value: 'ADMIN_RH', child: Text('Administrador RH')),
                        ],
                        onChanged: (v) {
                          setState(() => _filtroPerfilUsuario = v ?? 'todos');
                          _carregarUsuarios();
                        },
                      );

                      final dropStatus = DropdownButtonFormField<String>(
                        initialValue: _filtroStatusUsuario,
                        decoration: const InputDecoration(labelText: 'Status', isDense: true, border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'todos', child: Text('Todos os Status')),
                          DropdownMenuItem(value: 'true', child: Text('Apenas Ativos')),
                          DropdownMenuItem(value: 'false', child: Text('Apenas Inativos')),
                        ],
                        onChanged: (v) {
                          setState(() => _filtroStatusUsuario = v ?? 'todos');
                          _carregarUsuarios();
                        },
                      );

                      if (isMobileFilter) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(child: searchField),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  style: IconButton.styleFrom(backgroundColor: AppConstants.primaryColor),
                                  icon: const Icon(Icons.search, color: Colors.white),
                                  onPressed: _carregarUsuarios,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            btnNovo,
                            const SizedBox(height: 12),
                            dropDepto,
                            const SizedBox(height: 10),
                            dropPerfil,
                            const SizedBox(height: 10),
                            dropStatus,
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: searchField),
                              const SizedBox(width: 12),
                              btnBuscar,
                              const SizedBox(width: 12),
                              btnNovo,
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: dropDepto),
                              const SizedBox(width: 12),
                              Expanded(child: dropPerfil),
                              const SizedBox(width: 12),
                              Expanded(child: dropStatus),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Colaboradores Cadastrados ($_totalUsuarios)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Atualizar Lista',
                    onPressed: _carregarUsuarios,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _usuarios.isEmpty
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text('Nenhum usuário encontrado com os filtros aplicados.', style: TextStyle(color: Colors.grey.shade600)),
                        ),
                      ),
                    )
                  : Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _usuarios.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final u = _usuarios[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            leading: CircleAvatar(
                              backgroundColor: u.ativo ? const Color(0xFF0F172A) : Colors.grey.shade400,
                              foregroundColor: Colors.white,
                              child: Text(u.nome.isNotEmpty ? u.nome[0].toUpperCase() : 'U'),
                            ),
                            title: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  u.nome,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: u.ativo ? const Color(0xFF0F172A) : Colors.grey,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: u.perfil == 'GESTAO' ? Colors.blue.shade50 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: u.perfil == 'GESTAO' ? Colors.blue.shade300 : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    u.perfil == 'GESTAO' ? 'GESTÃO' : 'COLABORADOR',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: u.perfil == 'GESTAO' ? Colors.blue.shade700 : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                if (u.permissaoRh) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.purple.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.admin_panel_settings, size: 11, color: Colors.purple.shade700),
                                        const SizedBox(width: 3),
                                        Text(
                                          'RH ADMIN',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: u.ativo ? Colors.green.shade50 : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: u.ativo ? Colors.green.shade300 : Colors.red.shade300),
                                  ),
                                  child: Text(
                                    u.ativo ? 'ATIVO' : 'INATIVO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: u.ativo ? Colors.green.shade700 : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Matrícula: ${u.matricula} | Depto: ${u.departamentoNome ?? "Geral"}\nE-mail: ${u.email}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  tooltip: 'Editar Usuário',
                                  onPressed: () => _abrirModalUsuario(usuario: u),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.lock_reset, size: 18),
                                  tooltip: 'Redefinir Senha',
                                  onPressed: () => _abrirModalResetSenha(u),
                                ),
                                IconButton(
                                  icon: Icon(
                                    u.ativo ? Icons.person_off_outlined : Icons.person_outline,
                                    size: 18,
                                    color: u.ativo ? Colors.red.shade600 : Colors.green.shade700,
                                  ),
                                  tooltip: u.ativo ? 'Desativar Usuário' : 'Reativar Usuário',
                                  onPressed: () => _toggleStatusUsuario(u),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatarData(String isoDate) {
    try {
      final parsed = DateTime.parse(isoDate);
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {
      return isoDate;
    }
  }

  // ==========================================
  // TAB 2: IMPORTAÇÃO EM LOTE
  // ==========================================
  Widget _buildTabImportacaoLote() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, boxConstraints) {
                      final isMobile = boxConstraints.maxWidth < 650;

                      final inputSenha = TextField(
                        controller: _loteDefaultSenhaController,
                        decoration: const InputDecoration(
                          labelText: 'Senha Padrão Inicial (se não informada)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      );

                      final btnExemplo = OutlinedButton.icon(
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Carregar Exemplo'),
                        onPressed: _carregarExemploCsv,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Importação em Lote de Colaboradores',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Cole os dados de colaboradores em formato CSV (delimitado por ponto e vírgula ou vírgula). O sistema criará automaticamente departamentos que não existirem e gerará as credenciais de acesso.',
                            style: TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: const Text(
                              'Formato esperado das colunas:\nNome;Email;Matricula;Departamento;Perfil;Senha (opcional)',
                              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (isMobile) ...[
                            inputSenha,
                            const SizedBox(height: 10),
                            SizedBox(width: double.infinity, child: btnExemplo),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(child: inputSenha),
                                const SizedBox(width: 12),
                                btnExemplo,
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextField(
                            controller: _loteTextController,
                            maxLines: 8,
                            onChanged: (_) => _processarPreviaLote(),
                            decoration: const InputDecoration(
                              hintText: 'Cole aqui os registros CSV...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (isMobile) ...[
                            Text('Linhas identificadas: ${_lotePreview.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                icon: const Icon(Icons.cloud_upload_outlined),
                                label: Text('Importar ${_lotePreview.length} Usuários'),
                                onPressed: _lotePreview.isEmpty ? null : _executarImportacaoLote,
                              ),
                            ),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Linhas identificadas: ${_lotePreview.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                  icon: const Icon(Icons.cloud_upload_outlined),
                                  label: Text('Importar ${_lotePreview.length} Usuários'),
                                  onPressed: _lotePreview.isEmpty ? null : _executarImportacaoLote,
                                ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (_loteResultado != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.green.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.green.shade300)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Resultado da Importação:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                        const SizedBox(height: 6),
                        Text(
                          'Total: ${_loteResultado!["totalProcessados"]} | Novos Criados: ${_loteResultado!["criados"]} | Atualizados: ${_loteResultado!["atualizados"]} | Erros: ${_loteResultado!["totalErros"]}',
                          style: TextStyle(color: Colors.green.shade900),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_lotePreview.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pré-visualização dos Dados:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Nome')),
                              DataColumn(label: Text('E-mail')),
                              DataColumn(label: Text('Matrícula')),
                              DataColumn(label: Text('Departamento')),
                              DataColumn(label: Text('Perfil')),
                            ],
                            rows: _lotePreview.map((item) {
                              return DataRow(cells: [
                                DataCell(Text(item['nome'] ?? '')),
                                DataCell(Text(item['email'] ?? '')),
                                DataCell(Text(item['matricula'] ?? '')),
                                DataCell(Text(item['departamento'] ?? '')),
                                DataCell(Text(item['perfil'] ?? '')),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: GESTÃO GLOBAL DE RESERVAS
  // ==========================================
  Widget _buildTabReservas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: LayoutBuilder(
                    builder: (context, filterConstraints) {
                      final isMobileFilter = filterConstraints.maxWidth < 650;

                      final searchField = TextField(
                        controller: _searchReservaController,
                        decoration: const InputDecoration(
                          hintText: 'Buscar por colaborador, matrícula ou assento...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _carregarReservas(),
                      );

                      final btnFiltrar = ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        icon: const Icon(Icons.search),
                        label: const Text('Filtrar'),
                        onPressed: _carregarReservas,
                      );

                      final btnDataInicio = OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text('De: ${DateFormat("dd/MM/yyyy").format(_filtroDataInicio)}', style: const TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: _filtroDataInicio,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (p != null) {
                            setState(() => _filtroDataInicio = p);
                            _carregarReservas();
                          }
                        },
                      );

                      final btnDataFim = OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text('Até: ${DateFormat("dd/MM/yyyy").format(_filtroDataFim)}', style: const TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: _filtroDataFim,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (p != null) {
                            setState(() => _filtroDataFim = p);
                            _carregarReservas();
                          }
                        },
                      );

                      final dropEscritorio = DropdownButtonFormField<String>(
                        initialValue: _filtroEscritorioReserva,
                        decoration: const InputDecoration(labelText: 'Escritório', isDense: true, border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'todos', child: Text('Todos os Escritórios', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: '1', child: Text('Berrini')),
                          DropdownMenuItem(value: '2', child: Text('Barueri')),
                        ],
                        onChanged: (v) {
                          setState(() => _filtroEscritorioReserva = v ?? 'todos');
                          _carregarReservas();
                        },
                      );

                      final dropStatus = DropdownButtonFormField<String>(
                        initialValue: _filtroStatusReserva,
                        decoration: const InputDecoration(labelText: 'Status', isDense: true, border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'todos', child: Text('Todos os Status')),
                          DropdownMenuItem(value: 'ATIVA', child: Text('Ativa')),
                          DropdownMenuItem(value: 'CANCELADA', child: Text('Cancelada')),
                          DropdownMenuItem(value: 'EXPIRADA_NOSHOW', child: Text('No-Show')),
                        ],
                        onChanged: (v) {
                          setState(() => _filtroStatusReserva = v ?? 'todos');
                          _carregarReservas();
                        },
                      );

                      if (isMobileFilter) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(child: searchField),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  style: IconButton.styleFrom(backgroundColor: AppConstants.primaryColor),
                                  icon: const Icon(Icons.search, color: Colors.white),
                                  onPressed: _carregarReservas,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            btnDataInicio,
                            const SizedBox(height: 10),
                            btnDataFim,
                            const SizedBox(height: 10),
                            dropEscritorio,
                            const SizedBox(height: 10),
                            dropStatus,
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: searchField),
                              const SizedBox(width: 12),
                              btnFiltrar,
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: btnDataInicio),
                              const SizedBox(width: 8),
                              Expanded(child: btnDataFim),
                              const SizedBox(width: 8),
                              Expanded(child: dropEscritorio),
                              const SizedBox(width: 8),
                              Expanded(child: dropStatus),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total de Reservas Encontradas ($_totalReservas)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Atualizar Lista',
                    onPressed: _carregarReservas,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _reservas.isEmpty
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text('Nenhuma reserva encontrada para o período selecionado.', style: TextStyle(color: Colors.grey.shade600)),
                        ),
                      ),
                    )
                  : Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _reservas.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final r = _reservas[i];
                          final isAtiva = r.status == 'ATIVA';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isAtiva ? const Color(0xFF0F172A) : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                r.assento,
                                style: TextStyle(fontWeight: FontWeight.bold, color: isAtiva ? Colors.white : Colors.grey.shade700),
                              ),
                            ),
                            title: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(r.usuarioNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isAtiva
                                        ? Colors.green.shade50
                                        : (r.status == 'CANCELADA' ? Colors.red.shade50 : Colors.orange.shade50),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isAtiva
                                          ? Colors.green.shade300
                                          : (r.status == 'CANCELADA' ? Colors.red.shade300 : Colors.orange.shade300),
                                    ),
                                  ),
                                  child: Text(
                                    r.status,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isAtiva
                                          ? Colors.green.shade700
                                          : (r.status == 'CANCELADA' ? Colors.red.shade700 : Colors.orange.shade800),
                                    ),
                                  ),
                                ),
                                if (r.checkinRealizado) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.blue.shade300),
                                    ),
                                    child: Text(
                                      'CHECK-IN OK',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Data: ${_formatarData(r.dataReserva)} | Local: ${r.escritorioNome} - ${r.baiaNome}\nMatrícula: ${r.matricula} | Depto: ${r.departamentoNome ?? "Geral"}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ),
                            trailing: isAtiva
                                ? IconButton(
                                    icon: const Icon(Icons.cancel_outlined, size: 20, color: Colors.red),
                                    tooltip: 'Cancelar Reserva',
                                    onPressed: () => _abrirModalCancelarReserva(r),
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 4: DEPARTAMENTOS
  // ==========================================
  Widget _buildTabDepartamentos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Text('Departamentos Corporativos (${_departamentos.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Novo Departamento'),
                    onPressed: _abrirModalNovoDepartamento,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _departamentos.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final d = _departamentos[i];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        child: Icon(Icons.corporate_fare, size: 20),
                      ),
                      title: Text(d.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('ID: ${d.id} | Total de Colaboradores Vinculados: ${d.totalUsuarios}'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 5: POLÍTICAS & RELATÓRIOS
  // ==========================================
  Widget _buildTabPoliticas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, polConstraints) {
                      final isMobile = polConstraints.maxWidth < 600;

                      final inputHorarioGestao = TextFormField(
                        controller: _horarioGestaoController,
                        decoration: const InputDecoration(
                          labelText: 'Abertura Gestão (Horário)',
                          border: OutlineInputBorder(),
                        ),
                      );

                      final dropDiaGestao = DropdownButtonFormField<String>(
                        initialValue: _diaGestao,
                        decoration: const InputDecoration(
                          labelText: 'Dia da Semana (Gestão)',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: '1', child: Text('Segunda-feira')),
                          DropdownMenuItem(value: '4', child: Text('Quinta-feira')),
                          DropdownMenuItem(value: '5', child: Text('Sexta-feira')),
                        ],
                        onChanged: (v) => setState(() => _diaGestao = v ?? '5'),
                      );

                      final inputHorarioColab = TextFormField(
                        controller: _horarioColabController,
                        decoration: const InputDecoration(
                          labelText: 'Abertura Geral (Horário)',
                          border: OutlineInputBorder(),
                        ),
                      );

                      final dropDiaColab = DropdownButtonFormField<String>(
                        initialValue: _diaColab,
                        decoration: const InputDecoration(
                          labelText: 'Dia da Semana (Colaborador)',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: '1', child: Text('Segunda-feira')),
                          DropdownMenuItem(value: '4', child: Text('Quinta-feira')),
                          DropdownMenuItem(value: '5', child: Text('Sexta-feira')),
                        ],
                        onChanged: (v) => setState(() => _diaColab = v ?? '5'),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Parâmetros Globais de Reserva',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _limiteSemanalController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Limite de Reservas Semanais por Usuário',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (isMobile) ...[
                            inputHorarioGestao,
                            const SizedBox(height: 12),
                            dropDiaGestao,
                          ] else ...[
                            Row(
                              children: [
                                Expanded(child: inputHorarioGestao),
                                const SizedBox(width: 12),
                                Expanded(child: dropDiaGestao),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (isMobile) ...[
                            inputHorarioColab,
                            const SizedBox(height: 12),
                            dropDiaColab,
                          ] else ...[
                            Row(
                              children: [
                                Expanded(child: inputHorarioColab),
                                const SizedBox(width: 12),
                                Expanded(child: dropDiaColab),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _horarioCheckinController,
                            decoration: const InputDecoration(
                              labelText: 'Horário Limite de Check-in Diário (No-Show Cutoff)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              icon: const Icon(Icons.save),
                              label: const Text('Salvar Parâmetros'),
                              onPressed: _salvarParametros,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ações Operacionais de Emergência',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Dispare manualmente a rotina de liberação de no-show para cancelar reservas sem check-in do dia imediatamente.',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        icon: const Icon(Icons.cleaning_services),
                        label: const Text('Executar Limpeza de No-Show Agora'),
                        onPressed: _executarLimpezaEmergencial,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, relConstraints) {
                      final isMobile = relConstraints.maxWidth < 550;

                      final btnDataRelatorio = OutlinedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text('Data: ${DateFormat("dd/MM/yyyy").format(_dataRelatorio)}'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dataRelatorio,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() => _dataRelatorio = picked);
                        },
                      );

                      final btnExportar = ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        icon: const Icon(Icons.download),
                        label: const Text('Exportar CSV de Ocupação'),
                        onPressed: _exportarCsv,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Exportação de Relatórios de Ocupação',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          if (isMobile) ...[
                            SizedBox(width: double.infinity, child: btnDataRelatorio),
                            const SizedBox(height: 10),
                            SizedBox(width: double.infinity, child: btnExportar),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(child: btnDataRelatorio),
                                const SizedBox(width: 12),
                                btnExportar,
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
