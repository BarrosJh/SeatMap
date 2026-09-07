import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/admin_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'admin/tabs/tab_importacao_lote.dart';
import 'admin/tabs/tab_usuarios.dart';

class TiPanelScreen extends StatefulWidget {
  const TiPanelScreen({super.key});

  @override
  State<TiPanelScreen> createState() => _TiPanelScreenState();
}

class _TiPanelScreenState extends State<TiPanelScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  bool _isLoading = false;
  bool _isSavingSmtp = false;
  bool _isSavingSecurity = false;
  bool _isTestingEmail = false;
  bool _isRefreshingStatus = false;
  bool _isLoadingAudit = false;

  // TAB 1: SMTP Controllers
  final _smtpHostController = TextEditingController();
  final _smtpPortController = TextEditingController(text: '587');
  bool _smtpSecure = false;
  final _smtpUserController = TextEditingController();
  final _smtpPassController = TextEditingController();
  bool _smtpPassObscure = true;
  bool _smtpPassConfigurada = false;
  final _emailFromController = TextEditingController();
  final _testEmailDestinoController = TextEditingController();

  // TAB 2: Segurança, MFA & SSO
  final _mfaExpiracaoController = TextEditingController(text: '10');
  final _mfaTentativasController = TextEditingController(text: '3');
  String _mfaPolicy = 'OPCIONAL';
  bool _mfaEmailEnabled = true;
  bool _mfaTotpEnabled = true;

  // SSO Governança Global
  bool _ssoEnabled = false;
  final _ssoAllowedDomainsController = TextEditingController();
  bool _ssoAutoProvision = true;
  String _ssoDefaultRole = 'COLABORADOR';
  bool _ssoEnforceForDomains = false;

  // Microsoft Entra ID / Azure AD
  bool _ssoAzureEnabled = false;
  String _ssoAzureTenantType = 'single_tenant';
  final _ssoAzureTenantIdController = TextEditingController();
  final _ssoAzureClientIdController = TextEditingController();
  final _ssoAzureSecretController = TextEditingController();
  bool _ssoAzureSecretObscure = true;
  bool _ssoAzureSecretConfigured = false;
  final _ssoAzureScopesController = TextEditingController(text: 'openid profile email User.Read');
  final _ssoAzureSecurityGroupController = TextEditingController();
  final _ssoAzureRedirectUriController = TextEditingController();

  // Google Workspace
  bool _ssoGoogleEnabled = false;
  final _ssoGoogleClientIdController = TextEditingController();
  final _ssoGoogleSecretController = TextEditingController();
  bool _ssoGoogleSecretObscure = true;
  bool _ssoGoogleSecretConfigured = false;
  final _ssoGoogleHdController = TextEditingController();
  final _ssoGoogleRedirectUriController = TextEditingController();

  // SAML 2.0 / Okta Enterprise
  bool _ssoOktaEnabled = false;
  final _ssoOktaDomainController = TextEditingController();
  final _ssoOktaClientIdController = TextEditingController();
  final _ssoOktaSecretController = TextEditingController();
  bool _ssoOktaSecretObscure = true;
  bool _ssoOktaSecretConfigured = false;

  // TAB 3: Gestão de Usuários (T.I.)
  List<AdminUsuarioModel> _usuarios = [];
  List<DepartamentoModel> _departamentos = [];
  final _searchUsuarioController = TextEditingController();
  String _filtroDepUsuario = 'todos';
  String _filtroPerfilUsuario = 'todos';
  String _filtroStatusUsuario = 'todos';
  int _totalUsuarios = 0;

  // TAB 4: Importação em Lote (T.I.)
  final _loteTextController = TextEditingController();
  final _loteDefaultSenhaController = TextEditingController(text: 'Mudar@123');
  List<Map<String, dynamic>> _lotePreview = [];
  Map<String, dynamic>? _loteResultado;

  // TAB 5: Trilha de Auditoria
  List<dynamic> _auditLogs = [];
  int _auditPage = 1;
  int _auditTotalPages = 1;
  int _auditTotal = 0;
  final _auditSearchController = TextEditingController();
  String _auditFilterType = 'TODOS';

  // TAB 6: Diagnóstico de Saúde
  Map<String, dynamic>? _statusSistema;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _carregarDados();

    _statusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _tabController.index == 5) {
        _carregarStatusSistema(showSpinner: false);
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _tabController.dispose();
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _smtpUserController.dispose();
    _smtpPassController.dispose();
    _emailFromController.dispose();
    _testEmailDestinoController.dispose();
    _mfaExpiracaoController.dispose();
    _mfaTentativasController.dispose();
    _ssoAllowedDomainsController.dispose();
    _ssoAzureTenantIdController.dispose();
    _ssoAzureClientIdController.dispose();
    _ssoAzureSecretController.dispose();
    _ssoAzureScopesController.dispose();
    _ssoAzureSecurityGroupController.dispose();
    _ssoAzureRedirectUriController.dispose();
    _ssoGoogleClientIdController.dispose();
    _ssoGoogleSecretController.dispose();
    _ssoGoogleHdController.dispose();
    _ssoGoogleRedirectUriController.dispose();
    _ssoOktaDomainController.dispose();
    _ssoOktaClientIdController.dispose();
    _ssoOktaSecretController.dispose();
    _searchUsuarioController.dispose();
    _loteTextController.dispose();
    _loteDefaultSenhaController.dispose();
    _auditSearchController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    if (mounted) setState(() => _isLoading = true);

    if (_testEmailDestinoController.text.isEmpty && auth.user?.email != null) {
      _testEmailDestinoController.text = auth.user!.email;
    }

    await Future.wait([
      _carregarConfiguracoesTi(),
      _carregarAuditoriaAcessos(),
      _carregarStatusSistema(showSpinner: false),
      _carregarDepartamentos(setLoading: false),
      _carregarUsuarios(setLoading: false),
    ]);

    if (mounted) setState(() => _isLoading = false);
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

  void _abrirModalUsuario({AdminUsuarioModel? usuario}) {
    final nomeCtrl = TextEditingController(text: usuario?.nome ?? '');
    final emailCtrl = TextEditingController(text: usuario?.email ?? '');
    final matCtrl = TextEditingController(text: usuario?.matricula ?? '');
    final senhaCtrl = TextEditingController();
    int? selectedDep = usuario?.departamentoId;
    String selectedPerfil = (usuario?.perfil == 'GESTAO') ? 'GESTAO' : 'COLABORADOR';
    bool permissaoRh = usuario?.permissaoRh ?? (usuario?.perfil == 'ADMIN_RH');
    bool permissaoTi = usuario?.permissaoTi ?? (usuario?.perfil == 'ADMIN_TI');
    bool exigirMfa = usuario?.exigirMfa ?? false;
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
                usuario == null ? 'Novo Usuário (T.I.)' : 'Editar Usuário (T.I.)',
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
                        'Acesso ao painel administrativo de gestão de pessoas e reservas.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      value: permissaoRh,
                      activeThumbColor: Colors.purple.shade700,
                      onChanged: (v) => setModalState(() => permissaoRh = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Permissão Especial de T.I.
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: permissaoTi ? Colors.cyan.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: permissaoTi ? Colors.cyan.shade300 : Colors.grey.shade300),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        permissaoTi ? 'Permissão de T.I. & Infraestrutura (Ativa)' : 'Permissão de T.I. (Inativa)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: permissaoTi ? Colors.cyan.shade900 : Colors.grey.shade800,
                        ),
                      ),
                      subtitle: const Text(
                        'Acesso ao painel de infraestrutura, SMTP, auditoria e gestão de usuários.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      value: permissaoTi,
                      activeThumbColor: Colors.cyan.shade700,
                      onChanged: (v) => setModalState(() => permissaoTi = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Exigir Autenticação em 2 Etapas (MFA)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: exigirMfa ? Colors.amber.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: exigirMfa ? Colors.amber.shade400 : Colors.grey.shade300),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        exigirMfa ? 'Exigir 2FA / MFA no Login (Ativo)' : 'Exigir 2FA / MFA no Login (Opcional)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: exigirMfa ? Colors.amber.shade900 : Colors.grey.shade800,
                        ),
                      ),
                      subtitle: const Text(
                        'Obriga o colaborador a validar PIN por E-mail ou TOTP ao autenticar.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      value: exigirMfa,
                      activeThumbColor: Colors.amber.shade800,
                      onChanged: (v) => setModalState(() => exigirMfa = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 8),

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
                if (auth.token == null) return;

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
                  final res = await _apiService.criarUsuarioAdmin(auth.token!, auth.adminToken ?? auth.token!, {
                    'nome': nomeCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'matricula': matCtrl.text.trim(),
                    'senha': senhaCtrl.text.trim(),
                    'departamentoId': selectedDep,
                    'perfil': selectedPerfil,
                    'permissaoRh': permissaoRh,
                    'permissaoTi': permissaoTi,
                    'exigirMfa': exigirMfa,
                    'ativo': ativo,
                  });
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(res.message ?? res.error ?? 'Usuário criado com sucesso.'),
                      backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  );
                } else {
                  final res = await _apiService.updateUsuarioAdmin(auth.token!, auth.adminToken ?? auth.token!, usuario.id, {
                    'nome': nomeCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'matricula': matCtrl.text.trim(),
                    'departamentoId': selectedDep,
                    'perfil': selectedPerfil,
                    'permissaoRh': permissaoRh,
                    'permissaoTi': permissaoTi,
                    'exigirMfa': exigirMfa,
                    'ativo': ativo,
                  });
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(res.message ?? res.error ?? 'Usuário atualizado com sucesso.'),
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
              if (auth.token == null) return;

              if (senhaCtrl.text.trim().length < 4) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('A senha deve possuir pelo menos 4 caracteres.'), backgroundColor: Colors.red),
                );
                return;
              }

              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              final res = await _apiService.resetSenhaUsuarioAdmin(auth.token!, auth.adminToken ?? auth.token!, usuario.id, senhaCtrl.text.trim());
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
    if (auth.token == null) return;

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
    final res = await _apiService.toggleStatusUsuarioAdmin(auth.token!, auth.adminToken ?? auth.token!, usuario.id, ativo: !usuario.ativo);
    setState(() => _isLoading = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(res.message ?? res.error ?? 'Status alterado.'),
        backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
    await _carregarUsuarios();
  }

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
    if (auth.token == null) return;

    if (_lotePreview.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nenhum registro para importar. Cole dados em CSV ou gere o exemplo.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    final res = await _apiService.importarLoteUsuariosAdmin(
      auth.token!,
      auth.adminToken ?? auth.token!,
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

  Future<void> _carregarConfiguracoesTi() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    final res = await _apiService.getConfiguracoesTi(auth.token!);
    if (res.success && res.data != null && mounted) {
      final data = res.data!;
      final smtp = data['smtp'] ?? {};
      final mfa = data['mfa'] ?? {};
      final sso = data['sso'] ?? {};
      final google = sso['google'] ?? {};
      final azure = sso['azure'] ?? {};
      final okta = sso['okta'] ?? {};

      setState(() {
        _smtpHostController.text = smtp['host'] ?? 'smtp.gmail.com';
        _smtpPortController.text = (smtp['port'] ?? 587).toString();
        _smtpSecure = smtp['secure'] == true;
        _smtpUserController.text = smtp['user'] ?? '';
        _smtpPassConfigurada = smtp['passConfigurada'] == true;
        _smtpPassController.text = _smtpPassConfigurada ? '••••••••••••' : '';
        _emailFromController.text = smtp['from'] ?? '"SeatMap Corporativo" <nao-responda@seatmap.local>';

        _mfaPolicy = mfa['policy'] ?? 'OPCIONAL';
        _mfaEmailEnabled = mfa['emailEnabled'] ?? true;
        _mfaTotpEnabled = mfa['totpEnabled'] ?? true;
        _mfaExpiracaoController.text = (mfa['expiracaoMinutos'] ?? 10).toString();
        _mfaTentativasController.text = (mfa['maxTentativas'] ?? 3).toString();

        // SSO Governança
        _ssoEnabled = sso['enabled'] == true;
        _ssoAllowedDomainsController.text = sso['allowedDomains'] ?? '';
        _ssoAutoProvision = sso['autoProvision'] ?? true;
        _ssoDefaultRole = sso['defaultRole'] ?? 'COLABORADOR';
        _ssoEnforceForDomains = sso['enforceForDomains'] == true;

        // Microsoft Entra ID / Azure AD
        _ssoAzureEnabled = azure['enabled'] == true;
        _ssoAzureTenantType = azure['tenantType'] ?? 'single_tenant';
        _ssoAzureTenantIdController.text = azure['tenantId'] ?? '';
        _ssoAzureClientIdController.text = azure['clientId'] ?? '';
        _ssoAzureSecretConfigured = azure['secretConfigured'] == true;
        _ssoAzureSecretController.text = _ssoAzureSecretConfigured ? '••••••••••••' : '';
        _ssoAzureScopesController.text = azure['scopes'] ?? 'openid profile email User.Read';
        _ssoAzureSecurityGroupController.text = azure['securityGroup'] ?? '';
        _ssoAzureRedirectUriController.text = (azure['redirectUri'] != null && (azure['redirectUri'] as String).isNotEmpty)
            ? azure['redirectUri']
            : 'https://sistema.suaempresa.com.br/api/auth/sso/callback/azure';

        // Google Workspace
        _ssoGoogleEnabled = google['enabled'] == true;
        _ssoGoogleClientIdController.text = google['clientId'] ?? '';
        _ssoGoogleSecretConfigured = google['secretConfigured'] == true;
        _ssoGoogleSecretController.text = _ssoGoogleSecretConfigured ? '••••••••••••' : '';
        _ssoGoogleHdController.text = google['hd'] ?? '';
        _ssoGoogleRedirectUriController.text = (google['redirectUri'] != null && (google['redirectUri'] as String).isNotEmpty)
            ? google['redirectUri']
            : 'https://sistema.suaempresa.com.br/api/auth/sso/callback/google';

        // Okta / SAML 2.0
        _ssoOktaEnabled = okta['enabled'] == true;
        _ssoOktaDomainController.text = okta['domain'] ?? '';
        _ssoOktaClientIdController.text = okta['clientId'] ?? '';
        _ssoOktaSecretConfigured = okta['secretConfigured'] == true;
        _ssoOktaSecretController.text = _ssoOktaSecretConfigured ? '••••••••••••' : '';
      });
    }
  }

  Future<void> _carregarAuditoriaAcessos() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    setState(() => _isLoadingAudit = true);

    final res = await _apiService.getAuditoriaAcessos(
      auth.token!,
      pagina: _auditPage,
      limite: 20,
      termo: _auditSearchController.text.trim(),
      tipoEvento: _auditFilterType == 'TODOS' ? null : _auditFilterType,
    );

    if (mounted) {
      setState(() {
        _isLoadingAudit = false;
        if (res.success && res.data != null) {
          _auditLogs = res.data!['logs'] ?? [];
          _auditPage = res.data!['pagina'] ?? 1;
          _auditTotalPages = res.data!['totalPaginas'] ?? 1;
          _auditTotal = res.data!['total'] ?? 0;
        }
      });
    }
  }

  Future<void> _carregarStatusSistema({bool showSpinner = true}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    if (showSpinner && mounted) setState(() => _isRefreshingStatus = true);

    final res = await _apiService.getStatusSistema(auth.token!);
    if (mounted) {
      setState(() {
        if (showSpinner) _isRefreshingStatus = false;
        if (res.success && res.data != null) {
          _statusSistema = res.data;
        }
      });
    }
  }

  Future<void> _salvarSmtp() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    if (auth.token == null) return;

    final host = _smtpHostController.text.trim();
    final port = int.tryParse(_smtpPortController.text.trim()) ?? 587;
    final user = _smtpUserController.text.trim();
    final pass = _smtpPassController.text.trim();
    final from = _emailFromController.text.trim();

    if (host.isEmpty || user.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Host e Usuário SMTP são obrigatórios.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSavingSmtp = true);

    final payload = <String, dynamic>{
      'smtpHost': host,
      'smtpPort': port,
      'smtpSecure': _smtpSecure,
      'smtpUser': user,
      'emailFrom': from,
    };

    if (pass.isNotEmpty && pass != '••••••••••••') {
      payload['smtpPass'] = pass;
    }

    final res = await _apiService.updateConfiguracoesTi(auth.token!, payload);
    setState(() => _isSavingSmtp = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(res.message ?? res.error ?? 'Configurações SMTP atualizadas com sucesso.'),
        backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  Future<void> _salvarSegurancaESso() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    if (auth.token == null) return;

    final exp = int.tryParse(_mfaExpiracaoController.text.trim()) ?? 10;
    final tent = int.tryParse(_mfaTentativasController.text.trim()) ?? 3;

    setState(() => _isSavingSecurity = true);

    final payload = <String, dynamic>{
      'mfaPolicy': _mfaPolicy,
      'mfaEmailEnabled': _mfaEmailEnabled,
      'mfaTotpEnabled': _mfaTotpEnabled,
      'mfaExpiracaoMinutos': exp,
      'mfaMaxTentativas': tent,
      // Governança SSO
      'ssoEnabled': _ssoEnabled,
      'ssoAllowedDomains': _ssoAllowedDomainsController.text.trim(),
      'ssoAutoProvision': _ssoAutoProvision,
      'ssoDefaultRole': _ssoDefaultRole,
      'ssoEnforceForDomains': _ssoEnforceForDomains,
      // Microsoft Entra ID / Azure AD
      'ssoAzureEnabled': _ssoAzureEnabled,
      'ssoAzureTenantType': _ssoAzureTenantType,
      'ssoAzureTenantId': _ssoAzureTenantIdController.text.trim(),
      'ssoAzureClientId': _ssoAzureClientIdController.text.trim(),
      'ssoAzureScopes': _ssoAzureScopesController.text.trim(),
      'ssoAzureSecurityGroup': _ssoAzureSecurityGroupController.text.trim(),
      'ssoAzureRedirectUri': _ssoAzureRedirectUriController.text.trim(),
      // Google Workspace
      'ssoGoogleEnabled': _ssoGoogleEnabled,
      'ssoGoogleClientId': _ssoGoogleClientIdController.text.trim(),
      'ssoGoogleHd': _ssoGoogleHdController.text.trim(),
      'ssoGoogleRedirectUri': _ssoGoogleRedirectUriController.text.trim(),
      // Okta / SAML 2.0
      'ssoOktaEnabled': _ssoOktaEnabled,
      'ssoOktaDomain': _ssoOktaDomainController.text.trim(),
      'ssoOktaClientId': _ssoOktaClientIdController.text.trim(),
    };

    final azSec = _ssoAzureSecretController.text.trim();
    if (azSec.isNotEmpty && azSec != '••••••••••••') payload['ssoAzureClientSecret'] = azSec;

    final gSec = _ssoGoogleSecretController.text.trim();
    if (gSec.isNotEmpty && gSec != '••••••••••••') payload['ssoGoogleClientSecret'] = gSec;

    final okSec = _ssoOktaSecretController.text.trim();
    if (okSec.isNotEmpty && okSec != '••••••••••••') payload['ssoOktaClientSecret'] = okSec;

    final res = await _apiService.updateConfiguracoesTi(auth.token!, payload);
    setState(() => _isSavingSecurity = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(res.message ?? res.error ?? 'Políticas de Segurança e SSO atualizadas com sucesso.'),
        backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  Future<void> _testarDisparoEmail() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    if (auth.token == null) return;

    final targetEmail = _testEmailDestinoController.text.trim();
    if (targetEmail.isEmpty || !targetEmail.contains('@')) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Informe um e-mail de destino válido para o teste.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isTestingEmail = true);
    final res = await _apiService.testarConexaoEmail(auth.token!, emailDestino: targetEmail);
    setState(() => _isTestingEmail = false);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              res.success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: res.success ? Colors.green : Colors.red,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              res.success ? 'Conexão SMTP Validada!' : 'Falha no Teste SMTP',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(res.message ?? res.error ?? 'Teste concluído.'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatUptime(int seconds) {
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final parts = <String>[];
    if (d > 0) parts.add('${d}d');
    if (h > 0) parts.add('${h}h');
    if (m > 0) parts.add('${m}m');
    parts.add('${s}s');
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.terminal_rounded, size: 22, color: Color(0xFF38BDF8)),
            SizedBox(width: 10),
            Text('Painel de TI & Infraestrutura Enterprise', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.mail_outline_rounded, size: 20), text: 'Servidor SMTP'),
            Tab(icon: Icon(Icons.shield_rounded, size: 20), text: 'Segurança, MFA & SSO'),
            Tab(icon: Icon(Icons.people_alt_outlined, size: 20), text: 'Usuários'),
            Tab(icon: Icon(Icons.upload_file_outlined, size: 20), text: 'Importação em Lote'),
            Tab(icon: Icon(Icons.history_toggle_off_rounded, size: 20), text: 'Trilha de Auditoria'),
            Tab(icon: Icon(Icons.monitor_heart_outlined, size: 20), text: 'Diagnóstico & Saúde'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTabSmtp(),
                _buildTabSegurancaSso(),
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
                _buildTabAuditoria(),
                _buildTabDiagnostico(),
              ],
            ),
    );
  }

  Widget _buildTabSmtp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.dns_rounded, color: Color(0xFF2563EB), size: 22),
                          SizedBox(width: 10),
                          Text('Parâmetros do Servidor SMTP (Criptografia AES-256-GCM)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _smtpHostController,
                              decoration: const InputDecoration(labelText: 'Host do Servidor SMTP *', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _smtpPortController,
                              decoration: const InputDecoration(labelText: 'Porta *', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Conexão Segura Direta (SSL / TLS 465)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        value: _smtpSecure,
                        activeThumbColor: const Color(0xFF2563EB),
                        onChanged: (v) => setState(() => _smtpSecure = v),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _smtpUserController,
                              decoration: const InputDecoration(labelText: 'Usuário SMTP *', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _smtpPassController,
                              obscureText: _smtpPassObscure,
                              decoration: InputDecoration(
                                labelText: 'Senha / App Password *',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(_smtpPassObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                  onPressed: () => setState(() => _smtpPassObscure = !_smtpPassObscure),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailFromController,
                        decoration: const InputDecoration(labelText: 'E-mail Remetente (From) *', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                          icon: _isSavingSmtp ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Salvar Servidor SMTP', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _isSavingSmtp ? null : _salvarSmtp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _testEmailDestinoController,
                          decoration: const InputDecoration(labelText: 'E-mail de Teste de Disparo', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
                        icon: _isTestingEmail ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Testar Conexão', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _isTestingEmail ? null : _testarDisparoEmail,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSegurancaSso() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Políticas de MFA / 2FA
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_person_rounded, color: Color(0xFF7C3AED), size: 22),
                          SizedBox(width: 10),
                          Text('Políticas de Autenticação em 2 Etapas (MFA / TOTP)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _mfaPolicy,
                        decoration: const InputDecoration(labelText: 'Política de Aplicação do 2FA', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'OPCIONAL', child: Text('Opcional por Colaborador')),
                          DropdownMenuItem(value: 'OBRIGATORIO_RH', child: Text('Obrigatório para RH & Gestão')),
                          DropdownMenuItem(value: 'OBRIGATORIO_TODOS', child: Text('Obrigatório para Todos os Usuários')),
                          DropdownMenuItem(value: 'DESATIVADO', child: Text('Desativado Globalmente')),
                        ],
                        onChanged: (v) => setState(() => _mfaPolicy = v ?? 'OPCIONAL'),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('App Autenticador TOTP (Google / Microsoft Authenticator RFC 6238)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: const Text('Permite escanear QR Code e autenticar com códigos instantâneos de 30 segundos.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        value: _mfaTotpEnabled,
                        activeThumbColor: const Color(0xFF7C3AED),
                        onChanged: (v) => setState(() => _mfaTotpEnabled = v),
                      ),
                      SwitchListTile(
                        title: const Text('Código via E-mail Corporativo (SMTP)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: const Text('Envia PIN de 6 dígitos para o e-mail cadastrado.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        value: _mfaEmailEnabled,
                        activeThumbColor: const Color(0xFF7C3AED),
                        onChanged: (v) => setState(() => _mfaEmailEnabled = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Governança Global de SSO & JIT
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.corporate_fare_rounded, color: Color(0xFF0284C7), size: 22),
                          SizedBox(width: 10),
                          Text('Governança Global de Single Sign-On (SSO)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Habilitar Single Sign-On (SSO) Global', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Exibe opções de login corporativo na tela inicial e autoriza federação de identidade.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        value: _ssoEnabled,
                        activeThumbColor: const Color(0xFF0284C7),
                        onChanged: (v) => setState(() => _ssoEnabled = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ssoAllowedDomainsController,
                        decoration: const InputDecoration(
                          labelText: 'Domínios Corporativos Autorizados *',
                          hintText: 'ex: empresa.com.br, filial.com.br (ou * para todos)',
                          helperText: 'Separe múltiplos domínios por vírgula.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Auto-provisionamento JIT (Just-In-Time)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: const Text('Cria automaticamente a conta do colaborador no primeiro login SSO.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              value: _ssoAutoProvision,
                              activeThumbColor: const Color(0xFF0284C7),
                              onChanged: (v) => setState(() => _ssoAutoProvision = v),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _ssoDefaultRole,
                              decoration: const InputDecoration(
                                labelText: 'Perfil Padrão de Novos Usuários',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'COLABORADOR', child: Text('Colaborador')),
                                DropdownMenuItem(value: 'RH', child: Text('Gestão / RH')),
                              ],
                              onChanged: (v) => setState(() => _ssoDefaultRole = v ?? 'COLABORADOR'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Forçar SSO para Domínios Corporativos (SSO Enforcement)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: const Text('Bloqueia login tradicional por senha e exige autenticação via Microsoft/Google para contas do domínio.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        value: _ssoEnforceForDomains,
                        activeThumbColor: const Color(0xFFEA580C),
                        onChanged: (v) => setState(() => _ssoEnforceForDomains = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Microsoft Entra ID / Azure AD (Enterprise Identity)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: _ssoAzureEnabled ? const Color(0xFF0078D4) : const Color(0xFFE2E8F0), width: _ssoAzureEnabled ? 1.5 : 1.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0078D4).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.window_rounded, color: Color(0xFF0078D4), size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Microsoft Entra ID / Azure Active Directory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  Text('Autenticação corporativa com Microsoft 365, Graph API e Tokens OAuth 2.0 / OIDC', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: _ssoAzureEnabled,
                            activeThumbColor: const Color(0xFF0078D4),
                            onChanged: (v) => setState(() => _ssoAzureEnabled = v),
                          ),
                        ],
                      ),
                      if (_ssoAzureEnabled) ...[
                        const Divider(height: 32),
                        DropdownButtonFormField<String>(
                          initialValue: _ssoAzureTenantType,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de Locatário / Autoridade do Tenant *',
                            helperText: 'Single Tenant é o padrão recomendado para locatários corporativos exclusivos.',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'single_tenant', child: Text('Single Tenant (Locatário Corporativo Específico - Recomendado)')),
                            DropdownMenuItem(value: 'organizations', child: Text('Multitenant Corporativo (Qualquer conta corporativa Microsoft 365)')),
                            DropdownMenuItem(value: 'common', child: Text('Geral (Contas Corporativas + Microsoft Pessoais)')),
                          ],
                          onChanged: (v) => setState(() => _ssoAzureTenantType = v ?? 'single_tenant'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _ssoAzureTenantIdController,
                                decoration: const InputDecoration(
                                  labelText: 'ID do Diretório / Locatário (Tenant ID GUID) *',
                                  hintText: '00000000-0000-0000-0000-000000000000',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _ssoAzureClientIdController,
                                decoration: const InputDecoration(
                                  labelText: 'ID do Aplicativo / Cliente (Application ID GUID) *',
                                  hintText: '11111111-2222-3333-4444-555555555555',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _ssoAzureSecretController,
                          obscureText: _ssoAzureSecretObscure,
                          decoration: InputDecoration(
                            labelText: _ssoAzureSecretConfigured ? 'Segredo do Cliente (Client Secret Criptografado AES-256)' : 'Segredo do Cliente (Client Secret) *',
                            helperText: 'Criptografado at-rest com AES-256-GCM. Deixe preenchido com pontos para manter o segredo atual.',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_ssoAzureSecretObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _ssoAzureSecretObscure = !_ssoAzureSecretObscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _ssoAzureRedirectUriController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'URI de Redirecionamento (Redirect URI / Callback URL)',
                            helperText: 'Copie e cadastre exatamente esta URL em "Registros de aplicativo > Autenticação" no Microsoft Entra.',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy_rounded, color: Color(0xFF0078D4)),
                              tooltip: 'Copiar URI para Área de Transferência',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _ssoAzureRedirectUriController.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('URI de redirecionamento copiada com sucesso!'), duration: Duration(seconds: 2)),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _ssoAzureScopesController,
                                decoration: const InputDecoration(
                                  labelText: 'Escopos do Microsoft Graph (Scopes)',
                                  hintText: 'openid profile email User.Read',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _ssoAzureSecurityGroupController,
                                decoration: const InputDecoration(
                                  labelText: 'Restrição por Grupo de Segurança (Security Group ID)',
                                  hintText: 'Opcional (ex: GUID do Grupo no Entra)',
                                  helperText: 'Se informado, apenas membros deste grupo poderão logar.',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 4. Google Workspace & Cloud Identity
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: _ssoGoogleEnabled ? const Color(0xFFEA4335) : const Color(0xFFE2E8F0), width: _ssoGoogleEnabled ? 1.5 : 1.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEA4335).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.g_mobiledata_rounded, color: Color(0xFFEA4335), size: 24),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Google Workspace & Cloud Identity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  Text('Single Sign-On com Contas Corporativas Google Workspace', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: _ssoGoogleEnabled,
                            activeThumbColor: const Color(0xFFEA4335),
                            onChanged: (v) => setState(() => _ssoGoogleEnabled = v),
                          ),
                        ],
                      ),
                      if (_ssoGoogleEnabled) ...[
                        const Divider(height: 32),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _ssoGoogleClientIdController,
                                decoration: const InputDecoration(
                                  labelText: 'Client ID OAuth 2.0 (Google Cloud) *',
                                  hintText: 'ex: 123456789.apps.googleusercontent.com',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _ssoGoogleHdController,
                                decoration: const InputDecoration(
                                  labelText: 'Domínio Hospedado Obrigatório (hd)',
                                  hintText: 'empresa.com.br',
                                  helperText: 'Restringe autenticação apenas a este domínio.',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _ssoGoogleSecretController,
                          obscureText: _ssoGoogleSecretObscure,
                          decoration: InputDecoration(
                            labelText: _ssoGoogleSecretConfigured ? 'Client Secret (Criptografado AES-256)' : 'Client Secret do Google Cloud *',
                            helperText: 'Criptografado com AES-256-GCM. Deixe preenchido com pontos para manter o atual.',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_ssoGoogleSecretObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _ssoGoogleSecretObscure = !_ssoGoogleSecretObscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _ssoGoogleRedirectUriController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'URI de Redirecionamento Autorizada do Google',
                            helperText: 'Cadastre este URI no Console do Google Cloud em "URIs de redirecionamento autorizados".',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy_rounded, color: Color(0xFFEA4335)),
                              tooltip: 'Copiar URI Google',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _ssoGoogleRedirectUriController.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('URI Google copiada com sucesso!'), duration: Duration(seconds: 2)),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 5. SAML 2.0 / Okta Enterprise / OIDC Genérico
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: _ssoOktaEnabled ? const Color(0xFF00297A) : const Color(0xFFE2E8F0), width: _ssoOktaEnabled ? 1.5 : 1.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00297A).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.security_rounded, color: Color(0xFF00297A), size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Okta Enterprise SSO & SAML 2.0 / OIDC', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  Text('Federação de identidade SAML 2.0 ou Provedor de Identidade Aberto OIDC', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: _ssoOktaEnabled,
                            activeThumbColor: const Color(0xFF00297A),
                            onChanged: (v) => setState(() => _ssoOktaEnabled = v),
                          ),
                        ],
                      ),
                      if (_ssoOktaEnabled) ...[
                        const Divider(height: 32),
                        TextFormField(
                          controller: _ssoOktaDomainController,
                          decoration: const InputDecoration(
                            labelText: 'Domínio Okta / IdP Issuer / Metadata URL *',
                            hintText: 'https://suaempresa.okta.com ou URL do IdP',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _ssoOktaClientIdController,
                                decoration: const InputDecoration(
                                  labelText: 'Client ID / Entity ID da Aplicação *',
                                  hintText: '0oaxxxxxxxxxx',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _ssoOktaSecretController,
                                obscureText: _ssoOktaSecretObscure,
                                decoration: InputDecoration(
                                  labelText: _ssoOktaSecretConfigured ? 'Client Secret (Criptografado AES-256)' : 'Client Secret / Token *',
                                  helperText: 'Criptografado com AES-256-GCM.',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: Icon(_ssoOktaSecretObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    onPressed: () => setState(() => _ssoOktaSecretObscure = !_ssoOktaSecretObscure),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botão Salvar
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isSavingSecurity
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 20),
                  label: const Text('Salvar Políticas de Segurança & SSO Enterprise', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: _isSavingSecurity ? null : _salvarSegurancaESso,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabAuditoria() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _auditSearchController,
                  decoration: InputDecoration(
                    hintText: 'Filtrar por nome, e-mail ou endereço IP...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _auditSearchController.clear();
                        _carregarAuditoriaAcessos();
                      },
                    ),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) {
                    _auditPage = 1;
                    _carregarAuditoriaAcessos();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _auditFilterType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Evento',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'TODOS', child: Text('Todos os Eventos')),
                    DropdownMenuItem(value: 'LOGIN_SUCESSO', child: Text('Login Sucesso')),
                    DropdownMenuItem(value: 'LOGIN_FALHA_SENHA', child: Text('Falha de Senha')),
                    DropdownMenuItem(value: 'LOGIN_CONTA_BLOQUEADA', child: Text('Conta Bloqueada')),
                    DropdownMenuItem(value: 'TOTP_VALIDADO', child: Text('TOTP Validado')),
                    DropdownMenuItem(value: 'TOTP_FALHA', child: Text('TOTP Falha')),
                    DropdownMenuItem(value: 'MFA_VALIDADO_EMAIL', child: Text('MFA E-mail')),
                    DropdownMenuItem(value: 'SENHA_RESET_CONCLUIDO', child: Text('Senha Redefinida')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _auditFilterType = v ?? 'TODOS';
                      _auditPage = 1;
                    });
                    _carregarAuditoriaAcessos();
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Buscar'),
                onPressed: () {
                  _auditPage = 1;
                  _carregarAuditoriaAcessos();
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoadingAudit
              ? const Center(child: CircularProgressIndicator())
              : _auditLogs.isEmpty
                  ? const Center(child: Text('Nenhum registro de auditoria encontrado.', style: TextStyle(color: Colors.blueGrey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _auditLogs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final log = _auditLogs[index];
                        final bool sucesso = log['sucesso'] == true;
                        final String evento = log['tipoEvento'] ?? 'ACESSO';
                        final String usuario = log['usuarioNome'] ?? log['loginInformado'] ?? 'Desconhecido';
                        final String ip = log['ip'] ?? '127.0.0.1';
                        final String userAgent = log['userAgent'] ?? 'N/A';
                        final String dataHora = log['criadoEm'] != null
                            ? DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.parse(log['criadoEm']).toLocal())
                            : 'N/A';

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: Colors.white,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: sucesso ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  sucesso ? Icons.check_circle_rounded : Icons.gpp_bad_rounded,
                                  color: sucesso ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(usuario, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: sucesso ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            evento,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: sucesso ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('IP: $ip • Dispositivo: $userAgent', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Text(dataHora, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        );
                      },
                    ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: $_auditTotal eventos registrados • Página $_auditPage de $_auditTotalPages',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: 'Página Anterior',
                    onPressed: _auditPage > 1
                        ? () {
                            setState(() => _auditPage--);
                            _carregarAuditoriaAcessos();
                          }
                        : null,
                  ),
                  Text('$_auditPage / $_auditTotalPages', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: 'Próxima Página',
                    onPressed: _auditPage < _auditTotalPages
                        ? () {
                            setState(() => _auditPage++);
                            _carregarAuditoriaAcessos();
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabDiagnostico() {
    final db = _statusSistema?['database'] ?? {};
    final ws = _statusSistema?['websocket'] ?? {};
    final mem = _statusSistema?['memory'] ?? {};
    final uptimeSeconds = _statusSistema?['uptimeSegundos'] ?? 0;
    final server = _statusSistema?['server'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Monitoramento em Tempo Real', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
                    icon: _isRefreshingStatus ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Atualizar Métricas'),
                    onPressed: _isRefreshingStatus ? null : () => _carregarStatusSistema(showSpinner: true),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.storage_rounded,
                      iconColor: const Color(0xFF2563EB),
                      title: 'Banco PostgreSQL',
                      statusText: 'OPERACIONAL',
                      statusColor: Colors.green.shade700,
                      details: [
                        'Latência: ${db['latenciaMs'] ?? 0} ms',
                        'Pool Total: ${db['pool']?['total'] ?? 0}',
                        'Conexões Livres: ${db['pool']?['idle'] ?? 0}',
                        'Em Fila: ${db['pool']?['waiting'] ?? 0}',
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.sync_alt_rounded,
                      iconColor: const Color(0xFF0D9488),
                      title: 'WebSockets Nativo',
                      statusText: 'ONLINE',
                      statusColor: Colors.green.shade700,
                      details: [
                        'Clientes Ativos: ${ws['conexoesAtivas'] ?? 0}',
                        'Engine: WebSocket Nativo (ws)',
                        'Heartbeat: 30 segundos',
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.memory_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      title: 'Memória do Processo',
                      statusText: 'ESTÁVEL',
                      statusColor: Colors.green.shade700,
                      details: [
                        'Heap Utilizado: ${mem['heapUsedMb'] ?? 0} MB',
                        'Heap Total: ${mem['heapTotalMb'] ?? 0} MB',
                        'Memória RSS: ${mem['rssMb'] ?? 0} MB',
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.timer_outlined,
                      iconColor: const Color(0xFFEA580C),
                      title: 'Servidor & Uptime',
                      statusText: 'ATIVO',
                      statusColor: Colors.green.shade700,
                      details: [
                        'Tempo Ativo: ${_formatUptime(uptimeSeconds)}',
                        'Node.js: ${server['nodeVersion'] ?? 'v20+'}',
                        'Plataforma: ${server['platform'] ?? 'win32'}',
                      ],
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

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String statusText,
    required Color statusColor,
    required List<String> details,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: iconColor, size: 20),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(statusText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...details.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $d', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                )),
          ],
        ),
      ),
    );
  }
}
