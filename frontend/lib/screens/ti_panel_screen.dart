import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

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

  // SSO
  bool _ssoEnabled = false;
  final _ssoAllowedDomainsController = TextEditingController();
  bool _ssoAutoProvision = true;
  bool _ssoGoogleEnabled = false;
  final _ssoGoogleClientIdController = TextEditingController();
  final _ssoGoogleSecretController = TextEditingController();
  bool _ssoGoogleSecretConfigured = false;

  bool _ssoAzureEnabled = false;
  final _ssoAzureTenantIdController = TextEditingController();
  final _ssoAzureClientIdController = TextEditingController();
  final _ssoAzureSecretController = TextEditingController();
  bool _ssoAzureSecretConfigured = false;

  bool _ssoOktaEnabled = false;
  final _ssoOktaClientIdController = TextEditingController();
  final _ssoOktaSecretController = TextEditingController();
  bool _ssoOktaSecretConfigured = false;

  // TAB 3: Trilha de Auditoria
  List<dynamic> _auditLogs = [];
  int _auditPage = 1;
  int _auditTotalPages = 1;
  int _auditTotal = 0;
  final _auditSearchController = TextEditingController();
  String _auditFilterType = 'TODOS';

  // TAB 4: Diagnóstico de Saúde
  Map<String, dynamic>? _statusSistema;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _carregarDados();

    _statusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _tabController.index == 3) {
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
    _ssoGoogleClientIdController.dispose();
    _ssoGoogleSecretController.dispose();
    _ssoAzureTenantIdController.dispose();
    _ssoAzureClientIdController.dispose();
    _ssoAzureSecretController.dispose();
    _ssoOktaClientIdController.dispose();
    _ssoOktaSecretController.dispose();
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
    ]);

    if (mounted) setState(() => _isLoading = false);
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

        _ssoEnabled = sso['enabled'] == true;
        _ssoAllowedDomainsController.text = sso['allowedDomains'] ?? '';
        _ssoAutoProvision = sso['autoProvision'] ?? true;

        _ssoGoogleEnabled = google['enabled'] == true;
        _ssoGoogleClientIdController.text = google['clientId'] ?? '';
        _ssoGoogleSecretConfigured = google['secretConfigured'] == true;
        _ssoGoogleSecretController.text = _ssoGoogleSecretConfigured ? '••••••••••••' : '';

        _ssoAzureEnabled = azure['enabled'] == true;
        _ssoAzureTenantIdController.text = azure['tenantId'] ?? '';
        _ssoAzureClientIdController.text = azure['clientId'] ?? '';
        _ssoAzureSecretConfigured = azure['secretConfigured'] == true;
        _ssoAzureSecretController.text = _ssoAzureSecretConfigured ? '••••••••••••' : '';

        _ssoOktaEnabled = okta['enabled'] == true;
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
      'ssoEnabled': _ssoEnabled,
      'ssoAllowedDomains': _ssoAllowedDomainsController.text.trim(),
      'ssoAutoProvision': _ssoAutoProvision,
      'ssoGoogleEnabled': _ssoGoogleEnabled,
      'ssoGoogleClientId': _ssoGoogleClientIdController.text.trim(),
      'ssoAzureEnabled': _ssoAzureEnabled,
      'ssoAzureTenantId': _ssoAzureTenantIdController.text.trim(),
      'ssoAzureClientId': _ssoAzureClientIdController.text.trim(),
      'ssoOktaEnabled': _ssoOktaEnabled,
      'ssoOktaClientId': _ssoOktaClientIdController.text.trim(),
    };

    final gSec = _ssoGoogleSecretController.text.trim();
    if (gSec.isNotEmpty && gSec != '••••••••••••') payload['ssoGoogleClientSecret'] = gSec;

    final azSec = _ssoAzureSecretController.text.trim();
    if (azSec.isNotEmpty && azSec != '••••••••••••') payload['ssoAzureClientSecret'] = azSec;

    final okSec = _ssoOktaSecretController.text.trim();
    if (okSec.isNotEmpty && okSec != '••••••••••••') payload['ssoOktaClientSecret'] = okSec;

    final res = await _apiService.updateConfiguracoesTi(auth.token!, payload);
    setState(() => _isSavingSecurity = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(res.message ?? res.error ?? 'Políticas de Segurança e SSO atualizadas.'),
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
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.mail_outline_rounded, size: 20), text: 'Servidor SMTP'),
            Tab(icon: Icon(Icons.shield_rounded, size: 20), text: 'Segurança, MFA & SSO'),
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
                          Text('Single Sign-On Corporativo (SSO / OIDC / Azure AD)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Habilitar Single Sign-On (SSO)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Exibe botões de login corporativo com Google e Microsoft na tela inicial.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        value: _ssoEnabled,
                        activeThumbColor: const Color(0xFF0284C7),
                        onChanged: (v) => setState(() => _ssoEnabled = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ssoAllowedDomainsController,
                        decoration: const InputDecoration(
                          labelText: 'Domínios Corporativos Autorizados *',
                          hintText: 'empresa.com.br, filial.com.br (ou * para todos)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Auto-provisionamento de Colaboradores', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: const Text('Cria automaticamente a conta do colaborador no primeiro login SSO se o e-mail pertencer ao domínio corporativo.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        value: _ssoAutoProvision,
                        activeThumbColor: const Color(0xFF0284C7),
                        onChanged: (v) => setState(() => _ssoAutoProvision = v),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                          icon: _isSavingSecurity ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Salvar Segurança & SSO', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _isSavingSecurity ? null : _salvarSegurancaESso,
                        ),
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
