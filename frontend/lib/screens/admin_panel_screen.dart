import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/admin_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'admin/tabs/tab_departamentos.dart';
import 'admin/tabs/tab_importacao_lote.dart';
import 'admin/tabs/tab_politicas_relatorios.dart';
import 'admin/tabs/tab_reservas_global.dart';
import 'admin/tabs/tab_usuarios.dart';

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
                TabDepartamentos(
                  departamentos: _departamentos,
                  onNovoDepartamento: _abrirModalNovoDepartamento,
                ),
                TabPoliticasRelatorios(
                  limiteSemanalController: _limiteSemanalController,
                  horarioGestaoController: _horarioGestaoController,
                  horarioColabController: _horarioColabController,
                  horarioCheckinController: _horarioCheckinController,
                  diaGestao: _diaGestao,
                  diaColab: _diaColab,
                  dataRelatorio: _dataRelatorio,
                  onDiaGestaoChanged: (v) => setState(() => _diaGestao = v ?? '5'),
                  onDiaColabChanged: (v) => setState(() => _diaColab = v ?? '5'),
                  onDataRelatorioChanged: (d) => setState(() => _dataRelatorio = d),
                  onSalvarParametros: _salvarParametros,
                  onExecutarLimpezaNoShow: _executarLimpezaEmergencial,
                  onExportarCsv: _exportarCsv,
                ),
              ],
            ),
    );
  }
}
