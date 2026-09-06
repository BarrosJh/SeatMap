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
  bool _isSavingMfa = false;
  bool _isTestingEmail = false;
  bool _isRefreshingStatus = false;

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

  // TAB 2: MFA & Segurança
  final _mfaExpiracaoController = TextEditingController(text: '10');
  final _mfaTentativasController = TextEditingController(text: '3');
  List<dynamic> _auditoriaMfa = [];

  // TAB 3: Diagnóstico de Saúde
  Map<String, dynamic>? _statusSistema;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _carregarDados();

    // Auto-atualização periódica de diagnóstico a cada 30 segundos
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _tabController.index == 2) {
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
      _carregarStatusSistema(showSpinner: false),
      _carregarAuditoriaMfa(),
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

      setState(() {
        _smtpHostController.text = smtp['host'] ?? 'smtp.gmail.com';
        _smtpPortController.text = (smtp['port'] ?? 587).toString();
        _smtpSecure = smtp['secure'] == true;
        _smtpUserController.text = smtp['user'] ?? '';
        _smtpPassConfigurada = smtp['passConfigurada'] == true;
        _smtpPassController.text = _smtpPassConfigurada ? '••••••••••••' : '';
        _emailFromController.text = smtp['from'] ?? '"SeatMap Corporativo" <nao-responda@seatmap.local>';

        _mfaExpiracaoController.text = (mfa['expiracaoMinutos'] ?? 10).toString();
        _mfaTentativasController.text = (mfa['maxTentativas'] ?? 3).toString();
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

  Future<void> _carregarAuditoriaMfa() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    final res = await _apiService.getAuditoriaMfa(auth.token!);
    if (res.success && res.data != null && mounted) {
      setState(() {
        _auditoriaMfa = res.data!;
      });
    }
  }

  // ==========================================
  // AÇÕES: SMTP & DISPARO DE TESTE
  // ==========================================
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
        content: Text(res.message ?? res.error ?? 'Configurações SMTP salvas.'),
        backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );

    await _carregarConfiguracoesTi();
  }

  Future<void> _testarDisparoEmail() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    if (auth.token == null) return;

    final targetEmail = _testEmailDestinoController.text.trim();
    if (targetEmail.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Informe um e-mail destinatário para o teste.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isTestingEmail = true);
    final res = await _apiService.testarConexaoEmail(
      auth.token!,
      emailDestino: targetEmail,
      nomeDestino: auth.user?.nome ?? 'Administrador de TI',
    );
    setState(() => _isTestingEmail = false);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(
              res.success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: res.success ? Colors.green.shade600 : Colors.red.shade600,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              res.success ? 'Conexão SMTP Bem-Sucedida!' : 'Falha no Teste SMTP',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                res.success
                    ? 'O e-mail de teste foi despachado com êxito para $targetEmail.'
                    : 'Não foi possível completar o envio através do servidor SMTP.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: res.success ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: res.success ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resposta do Servidor:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: res.success ? const Color(0xFF166534) : const Color(0xFF991B1B)),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      res.message ?? res.error ?? 'Sem resposta adicional',
                      style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: res.success ? const Color(0xFF15803D) : const Color(0xFFB91C1C)),
                    ),
                    if (res.data?['detalhes'] != null) ...[
                      const SizedBox(height: 8),
                      SelectableText(
                        'Detalhes: ${res.data!['detalhes'].toString()}',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.blueGrey),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK, Entendido'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // AÇÕES: SEGURANÇA & MFA
  // ==========================================
  Future<void> _salvarMfa() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    if (auth.token == null) return;

    final exp = int.tryParse(_mfaExpiracaoController.text.trim()) ?? 10;
    final tent = int.tryParse(_mfaTentativasController.text.trim()) ?? 3;

    if (exp <= 0 || tent <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Valores de expiração e tentativas devem ser maiores que zero.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSavingMfa = true);

    final res = await _apiService.updateConfiguracoesTi(auth.token!, {
      'mfaExpiracaoMinutos': exp,
      'mfaMaxTentativas': tent,
    });

    setState(() => _isSavingMfa = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(res.message ?? res.error ?? 'Configurações de segurança salvas.'),
        backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
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
            Text('Painel de TI & Infraestrutura', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
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
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'TI Operational',
                  style: TextStyle(
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
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.mail_outline_rounded, size: 20), text: 'Servidor de E-mail (SMTP)'),
            Tab(icon: Icon(Icons.security_rounded, size: 20), text: 'Segurança & MFA'),
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
                _buildTabSegurancaMfa(),
                _buildTabDiagnostico(),
              ],
            ),
    );
  }

  // ==========================================
  // TAB 1: SMTP & MENSAGERIA DE E-MAIL
  // ==========================================
  Widget _buildTabSmtp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card 1: Configuração do Servidor SMTP
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.dns_rounded, color: Color(0xFF2563EB), size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Parâmetros do Servidor SMTP',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Configure os dados do gateway SMTP institucional para envio em tempo real de vouchers, MFA e redefinição de senha.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 20),

                      // Host e Porta
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _smtpHostController,
                              decoration: const InputDecoration(
                                labelText: 'Host SMTP *',
                                hintText: 'smtp.gmail.com ou smtp.office365.com',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.cloud_outlined, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _smtpPortController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Porta *',
                                hintText: '587',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.numbers_rounded, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // TLS / SSL Switch
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Conexão Segura Direta (SSL / TLS 465)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: const Text('Ative se estiver utilizando a porta 465 com SSL implícito. Desative para STARTTLS (Porta 587).', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          value: _smtpSecure,
                          activeThumbColor: const Color(0xFF2563EB),
                          onChanged: (v) => setState(() => _smtpSecure = v),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Usuário e Senha
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _smtpUserController,
                              decoration: const InputDecoration(
                                labelText: 'Usuário / Conta SMTP *',
                                hintText: 'seu-email@dominio.com',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.account_circle_outlined, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _smtpPassController,
                              obscureText: _smtpPassObscure,
                              decoration: InputDecoration(
                                labelText: 'Senha / App Password *',
                                hintText: _smtpPassConfigurada ? '••••••••••••' : 'Senha do e-mail',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(_smtpPassObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                                  onPressed: () => setState(() => _smtpPassObscure = !_smtpPassObscure),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Remetente From
                      TextFormField(
                        controller: _emailFromController,
                        decoration: const InputDecoration(
                          labelText: 'E-mail Remetente (From Header) *',
                          hintText: '"SeatMap Corporativo" <nao-responda@empresa.com>',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.forward_to_inbox_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: _isSavingSmtp
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Salvar e Aplicar Servidor SMTP', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _isSavingSmtp ? null : _salvarSmtp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Card 2: Teste de Disparo e Validação Real
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.send_and_archive_rounded, color: Color(0xFF16A34A), size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Diagnóstico & Teste de Disparo em Tempo Real',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Envie uma mensagem de verificação para testar a comunicação direta com o servidor de e-mails.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _testEmailDestinoController,
                              decoration: const InputDecoration(
                                labelText: 'E-mail de Destino para Teste',
                                hintText: 'seu.email@empresa.com',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.mark_email_read_outlined, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: _isTestingEmail
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.play_arrow_rounded, size: 20),
                            label: const Text('Testar Conexão e Envio', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _isTestingEmail ? null : _testarDisparoEmail,
                          ),
                        ],
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

  // ==========================================
  // TAB 2: SEGURANÇA & AUDITORIA MFA
  // ==========================================
  Widget _buildTabSegurancaMfa() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card: Governança MFA
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_rounded, color: Color(0xFF7C3AED), size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Políticas de Segurança Step-Up (MFA)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Defina os parâmetros criptográficos de expiração e tolerância a tentativas de invasão / força bruta.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _mfaExpiracaoController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Tempo de Expiração do Código (Minutos) *',
                                hintText: '10',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.timer_outlined, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _mfaTentativasController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Máximo de Tentativas Incorretas *',
                                hintText: '3',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.security_update_warning_outlined, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: _isSavingMfa
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Salvar Políticas de Segurança', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _isSavingMfa ? null : _salvarMfa,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Card: Histórico de Auditoria MFA
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.history_toggle_off_rounded, color: Color(0xFF0F172A), size: 22),
                              SizedBox(width: 10),
                              Text(
                                'Auditoria de Códigos de Autenticação (Últimos Disparos)',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            onPressed: _carregarAuditoriaMfa,
                            tooltip: 'Atualizar Auditoria',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_auditoriaMfa.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: const Text('Nenhum registro de código MFA encontrado no histórico.', style: TextStyle(color: Colors.blueGrey)),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _auditoriaMfa.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _auditoriaMfa[index];
                            final nome = item['usuario_nome'] ?? 'Usuário #${item['usuario_id']}';
                            final email = item['usuario_email'] ?? '';
                            final tipo = item['tipo'] ?? 'MFA';
                            final criadoEm = item['criado_em'] != null
                                ? DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.parse(item['criado_em']).toLocal())
                                : 'N/A';
                            final utilizado = item['utilizado_em'] != null;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: utilizado ? Colors.green.shade50 : Colors.blue.shade50,
                                child: Icon(
                                  utilizado ? Icons.check_circle_outline : Icons.vpn_key_outlined,
                                  size: 18,
                                  color: utilizado ? Colors.green.shade700 : Colors.blue.shade700,
                                ),
                              ),
                              title: Text('$nome ($email)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('Tipo: $tipo • Disparado em: $criadoEm • Tentativas: ${item['tentativas'] ?? 0}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: utilizado ? Colors.green.shade100 : Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  utilizado ? 'UTILIZADO' : 'PENDENTE/EXPIRADO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: utilizado ? Colors.green.shade800 : Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            );
                          },
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

  // ==========================================
  // TAB 3: DIAGNÓSTICO & SAÚDE DO SISTEMA
  // ==========================================
  Widget _buildTabDiagnostico() {
    final db = _statusSistema?['database'] ?? {};
    final ws = _statusSistema?['websockets'] ?? {};
    final mem = _statusSistema?['memory'] ?? {};
    final uptimeSeconds = _statusSistema?['uptimeSeconds'] ?? 0;
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
                  const Text(
                    'Monitoramento em Tempo Real',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isRefreshingStatus
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Atualizar Métricas', style: TextStyle(fontSize: 12)),
                    onPressed: _isRefreshingStatus ? null : () => _carregarStatusSistema(showSpinner: true),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Grid de Cards de Diagnóstico
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 580;
                  return Column(
                    children: [
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
                                'Latência de Ping: ${db['latencyMs'] ?? 0} ms',
                                'Pool Total: ${db['pool']?['totalConnections'] ?? 0} conexões',
                                'Conexões Ociosas: ${db['pool']?['idleConnections'] ?? 0}',
                                'Requisições em Fila: ${db['pool']?['waitingRequests'] ?? 0}',
                              ],
                            ),
                          ),
                          if (isWide) const SizedBox(width: 16),
                          if (isWide)
                            Expanded(
                              child: _buildMetricCard(
                                icon: Icons.sync_alt_rounded,
                                iconColor: const Color(0xFF0D9488),
                                title: 'WebSockets & Realtime',
                                statusText: 'ONLINE',
                                statusColor: Colors.green.shade700,
                                details: [
                                  'Clientes Conectados: ${ws['activeClients'] ?? 0}',
                                  'Salas / Escritórios Ativos: ${ws['activeRooms'] ?? 0}',
                                  'Engine: WebSocket Nativo (ws)',
                                  'Heartbeat Ping: 30 segundos',
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (!isWide) const SizedBox(height: 16),
                      if (!isWide)
                        _buildMetricCard(
                          icon: Icons.sync_alt_rounded,
                          iconColor: const Color(0xFF0D9488),
                          title: 'WebSockets & Realtime',
                          statusText: 'ONLINE',
                          statusColor: Colors.green.shade700,
                          details: [
                            'Clientes Conectados: ${ws['activeClients'] ?? 0}',
                            'Salas / Escritórios Ativos: ${ws['activeRooms'] ?? 0}',
                            'Engine: WebSocket Nativo (ws)',
                            'Heartbeat Ping: 30 segundos',
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
                                'Heap Alocado: ${mem['heapTotalMb'] ?? 0} MB',
                                'Memória Total (RSS): ${mem['rssMb'] ?? 0} MB',
                                'External / Buffers: ${mem['externalMb'] ?? 0} MB',
                              ],
                            ),
                          ),
                          if (isWide) const SizedBox(width: 16),
                          if (isWide)
                            Expanded(
                              child: _buildMetricCard(
                                icon: Icons.timer_outlined,
                                iconColor: const Color(0xFFEA580C),
                                title: 'Uptime & Servidor',
                                statusText: 'ATIVO',
                                statusColor: Colors.green.shade700,
                                details: [
                                  'Tempo Ativo: ${_formatUptime(uptimeSeconds)}',
                                  'Node.js: ${server['nodeVersion'] ?? 'v20+'}',
                                  'Plataforma: ${server['platform'] ?? 'win32'}',
                                  'Ambiente: ${server['env'] ?? 'development'}',
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (!isWide) const SizedBox(height: 16),
                      if (!isWide)
                        _buildMetricCard(
                          icon: Icons.timer_outlined,
                          iconColor: const Color(0xFFEA580C),
                          title: 'Uptime & Servidor',
                          statusText: 'ATIVO',
                          statusColor: Colors.green.shade700,
                          details: [
                            'Tempo Ativo: ${_formatUptime(uptimeSeconds)}',
                            'Node.js: ${server['nodeVersion'] ?? 'v20+'}',
                            'Plataforma: ${server['platform'] ?? 'win32'}',
                            'Ambiente: ${server['env'] ?? 'development'}',
                          ],
                        ),
                    ],
                  );
                },
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
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
                    Icon(icon, color: iconColor, size: 22),
                    const SizedBox(width: 10),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...details.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_right_rounded, size: 16, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        d,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
