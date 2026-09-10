import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/admin_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'admin/tabs/tab_importacao_lote.dart';
import 'admin/tabs/tab_usuarios.dart';
import 'admin/modals/modal_reset_senha.dart';
import 'admin/modals/modal_usuario_form.dart';
import 'ti/tabs/tab_ti_smtp.dart';
import 'ti/tabs/tab_ti_seguranca_sso.dart';
import 'ti/tabs/tab_ti_auditoria.dart';
import 'ti/tabs/tab_ti_diagnostico.dart';

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

  // TAB 1: Email Controllers (Resend API & SMTP)
  String _emailProvider = 'RESEND'; // 'RESEND' ou 'SMTP'
  final _resendApiKeyController = TextEditingController();
  bool _resendApiKeyObscure = true;
  bool _resendApiKeyConfigurada = false;

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

  // Auto-Lock por Inatividade
  bool _autoLockAtivo = true;
  int _autoLockMinutos = 15;

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
    _resendApiKeyController.dispose();
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

  void _abrirModalUsuario({AdminUsuarioModel? usuario}) {
    ModalUsuarioForm.show(
      context,
      usuario: usuario,
      departamentos: _departamentos,
      titleSuffix: 'T.I.',
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
      final email = data['email'] ?? {};
      final resend = email['resend'] ?? {};
      final smtp = data['smtp'] ?? {};
      final mfa = data['mfa'] ?? {};
      final autoLock = data['autoLock'] ?? {};
      final sso = data['sso'] ?? {};
      final google = sso['google'] ?? {};
      final azure = sso['azure'] ?? {};
      final okta = sso['okta'] ?? {};

      setState(() {
        _emailProvider = email['provider'] ?? 'RESEND';
        _resendApiKeyConfigurada = resend['apiKeyConfigured'] == true;
        _resendApiKeyController.text = _resendApiKeyConfigurada ? '••••••••••••' : '';

        _smtpHostController.text = smtp['host'] ?? 'smtp.gmail.com';
        _smtpPortController.text = (smtp['port'] ?? 587).toString();
        _smtpSecure = smtp['secure'] == true;
        _smtpUserController.text = smtp['user'] ?? '';
        _smtpPassConfigurada = smtp['passConfigured'] == true || smtp['passConfigurada'] == true;
        _smtpPassController.text = _smtpPassConfigurada ? '••••••••••••' : '';
        _emailFromController.text = email['emailFrom'] ?? smtp['from'] ?? smtp['emailFrom'] ?? 'SeatMap Corporativo <onboarding@resend.dev>';

        _mfaPolicy = mfa['policy'] ?? 'OPCIONAL';
        _mfaEmailEnabled = mfa['emailEnabled'] ?? true;
        _mfaTotpEnabled = mfa['totpEnabled'] ?? true;
        _mfaExpiracaoController.text = (mfa['expiracaoMinutos'] ?? 10).toString();
        _mfaTentativasController.text = (mfa['maxTentativas'] ?? 3).toString();

        _autoLockAtivo = autoLock['ativo'] ?? true;
        _autoLockMinutos = (autoLock['minutos'] as int?) ?? 15;

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

    final from = _emailFromController.text.trim();
    if (from.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('E-mail Remetente (From) é obrigatório.'), backgroundColor: Colors.red),
      );
      return;
    }

    final payload = <String, dynamic>{
      'emailProvider': _emailProvider,
      'emailFrom': from,
    };

    if (_emailProvider == 'RESEND') {
      final resendKey = _resendApiKeyController.text.trim();
      if (resendKey.isNotEmpty && resendKey != '••••••••••••') {
        payload['resendApiKey'] = resendKey;
      }
    } else {
      final host = _smtpHostController.text.trim();
      final port = int.tryParse(_smtpPortController.text.trim()) ?? 587;
      final user = _smtpUserController.text.trim();
      final pass = _smtpPassController.text.trim();

      if (host.isEmpty || user.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Host e Usuário SMTP são obrigatórios para o modo SMTP.'), backgroundColor: Colors.red),
        );
        return;
      }

      payload['smtpHost'] = host;
      payload['smtpPort'] = port;
      payload['smtpSecure'] = _smtpSecure;
      payload['smtpUser'] = user;
      if (pass.isNotEmpty && pass != '••••••••••••') {
        payload['smtpPass'] = pass;
      }
    }

    setState(() => _isSavingSmtp = true);
    final res = await _apiService.updateConfiguracoesTi(auth.token!, payload);
    setState(() => _isSavingSmtp = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(res.message ?? res.error ?? 'Configurações de E-mail atualizadas com sucesso.'),
        backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );

    await _carregarConfiguracoesTi();
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
      // Auto-Lock por Inatividade
      'autoLockAtivo': _autoLockAtivo,
      'autoLockMinutos': _autoLockMinutos,
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
            Tab(icon: Icon(Icons.mail_outline_rounded, size: 20), text: 'Canal de E-mail'),
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
                TabTiSmtp(
                  emailProvider: _emailProvider,
                  onProviderChanged: (v) => setState(() => _emailProvider = v),
                  resendApiKeyController: _resendApiKeyController,
                  resendApiKeyObscure: _resendApiKeyObscure,
                  onToggleResendApiKeyObscure: () => setState(() => _resendApiKeyObscure = !_resendApiKeyObscure),
                  resendApiKeyConfigured: _resendApiKeyConfigurada,
                  hostController: _smtpHostController,
                  portController: _smtpPortController,
                  secure: _smtpSecure,
                  onSecureChanged: (v) => setState(() => _smtpSecure = v),
                  userController: _smtpUserController,
                  passController: _smtpPassController,
                  passObscure: _smtpPassObscure,
                  onTogglePassObscure: () => setState(() => _smtpPassObscure = !_smtpPassObscure),
                  passConfigured: _smtpPassConfigurada,
                  emailFromController: _emailFromController,
                  testEmailController: _testEmailDestinoController,
                  isSaving: _isSavingSmtp,
                  isTesting: _isTestingEmail,
                  onSalvar: _salvarSmtp,
                  onTestar: _testarDisparoEmail,
                ),
                TabTiSegurancaSso(
                  mfaPolicy: _mfaPolicy,
                  onMfaPolicyChanged: (v) => setState(() => _mfaPolicy = v ?? 'OPCIONAL'),
                  mfaTotpEnabled: _mfaTotpEnabled,
                  onMfaTotpChanged: (v) => setState(() => _mfaTotpEnabled = v),
                  mfaEmailEnabled: _mfaEmailEnabled,
                  onMfaEmailChanged: (v) => setState(() => _mfaEmailEnabled = v),
                  autoLockAtivo: _autoLockAtivo,
                  onAutoLockAtivoChanged: (v) => setState(() => _autoLockAtivo = v),
                  autoLockMinutos: _autoLockMinutos,
                  onAutoLockMinutosChanged: (v) => setState(() => _autoLockMinutos = v ?? 15),
                  ssoEnabled: _ssoEnabled,
                  onSsoEnabledChanged: (v) => setState(() => _ssoEnabled = v),
                  ssoAllowedDomainsController: _ssoAllowedDomainsController,
                  ssoAutoProvision: _ssoAutoProvision,
                  onSsoAutoProvisionChanged: (v) => setState(() => _ssoAutoProvision = v),
                  ssoDefaultRole: _ssoDefaultRole,
                  onSsoDefaultRoleChanged: (v) => setState(() => _ssoDefaultRole = v ?? 'COLABORADOR'),
                  ssoEnforceForDomains: _ssoEnforceForDomains,
                  onSsoEnforceChanged: (v) => setState(() => _ssoEnforceForDomains = v),
                  ssoAzureEnabled: _ssoAzureEnabled,
                  onSsoAzureEnabledChanged: (v) => setState(() => _ssoAzureEnabled = v),
                  ssoAzureTenantType: _ssoAzureTenantType,
                  onSsoAzureTenantTypeChanged: (v) => setState(() => _ssoAzureTenantType = v ?? 'single_tenant'),
                  ssoAzureTenantIdController: _ssoAzureTenantIdController,
                  ssoAzureClientIdController: _ssoAzureClientIdController,
                  ssoAzureSecretController: _ssoAzureSecretController,
                  ssoAzureSecretObscure: _ssoAzureSecretObscure,
                  ssoAzureSecretConfigured: _ssoAzureSecretConfigured,
                  onToggleAzureSecretObscure: () => setState(() => _ssoAzureSecretObscure = !_ssoAzureSecretObscure),
                  ssoAzureRedirectUriController: _ssoAzureRedirectUriController,
                  ssoAzureScopesController: _ssoAzureScopesController,
                  ssoAzureSecurityGroupController: _ssoAzureSecurityGroupController,
                  ssoGoogleEnabled: _ssoGoogleEnabled,
                  onSsoGoogleEnabledChanged: (v) => setState(() => _ssoGoogleEnabled = v),
                  ssoGoogleClientIdController: _ssoGoogleClientIdController,
                  ssoGoogleSecretController: _ssoGoogleSecretController,
                  ssoGoogleSecretObscure: _ssoGoogleSecretObscure,
                  ssoGoogleSecretConfigured: _ssoGoogleSecretConfigured,
                  onToggleGoogleSecretObscure: () => setState(() => _ssoGoogleSecretObscure = !_ssoGoogleSecretObscure),
                  ssoGoogleHdController: _ssoGoogleHdController,
                  ssoGoogleRedirectUriController: _ssoGoogleRedirectUriController,
                  ssoOktaEnabled: _ssoOktaEnabled,
                  onSsoOktaEnabledChanged: (v) => setState(() => _ssoOktaEnabled = v),
                  ssoOktaDomainController: _ssoOktaDomainController,
                  ssoOktaClientIdController: _ssoOktaClientIdController,
                  ssoOktaSecretController: _ssoOktaSecretController,
                  ssoOktaSecretObscure: _ssoOktaSecretObscure,
                  ssoOktaSecretConfigured: _ssoOktaSecretConfigured,
                  onToggleOktaSecretObscure: () => setState(() => _ssoOktaSecretObscure = !_ssoOktaSecretObscure),
                  isSaving: _isSavingSecurity,
                  onSalvar: _salvarSegurancaESso,
                ),
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
                TabTiAuditoria(
                  searchController: _auditSearchController,
                  filterType: _auditFilterType,
                  onFilterTypeChanged: (v) {
                    setState(() {
                      _auditFilterType = v ?? 'TODOS';
                      _auditPage = 1;
                    });
                    _carregarAuditoriaAcessos();
                  },
                  onSearch: () {
                    setState(() => _auditPage = 1);
                    _carregarAuditoriaAcessos();
                  },
                  isLoading: _isLoadingAudit,
                  logs: _auditLogs,
                  page: _auditPage,
                  totalPages: _auditTotalPages,
                  totalLogs: _auditTotal,
                  onPrevPage: _auditPage > 1
                      ? () {
                          setState(() => _auditPage--);
                          _carregarAuditoriaAcessos();
                        }
                      : null,
                  onNextPage: _auditPage < _auditTotalPages
                      ? () {
                          setState(() => _auditPage++);
                          _carregarAuditoriaAcessos();
                        }
                      : null,
                ),
                TabTiDiagnostico(
                  statusSistema: _statusSistema,
                  isRefreshing: _isRefreshingStatus,
                  onRefresh: () => _carregarStatusSistema(showSpinner: true),
                ),
              ],
            ),
    );
  }
}
