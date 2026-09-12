import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _senhaController = TextEditingController();
  final _apiService = ApiService();
  bool _obscurePassword = true;

  // SSO & Biometrics State
  bool _ssoEnabled = false;
  List<dynamic> _ssoProviders = [];
  List<dynamic> _ssoAllowedDomains = [];
  bool _biometricsAvailable = false;

  @override
  void initState() {
    super.initState();
    _carregarSsoConfig();
    _verificarBiometria();
  }

  Future<void> _verificarBiometria() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final available = await auth.isBiometricsAvailable();
    if (mounted) {
      setState(() => _biometricsAvailable = available);
    }
  }

  Future<void> _carregarSsoConfig() async {
    final res = await _apiService.getSsoConfig();
    if (res.success && res.data != null && mounted) {
      setState(() {
        _ssoEnabled = res.data!['ssoEnabled'] == true;
        _ssoProviders = res.data!['providers'] ?? [];
        _ssoAllowedDomains = res.data!['allowedDomains'] ?? [];
      });
    }
  }

  @override
  void dispose() {
    _loginController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _prefillUser(String login, String senha) {
    _loginController.text = login;
    _senhaController.text = senha;
  }

  Future<void> _realizarLoginSso(String providerId, String providerNome) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final emailCtrl = TextEditingController(text: _loginController.text.contains('@') ? _loginController.text.trim() : '');
    final nomeCtrl = TextEditingController();
    String? erroSso;
    bool loading = false;

    showDialog(
      context: context,
      barrierDismissible: !loading,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(
                    Icons.window_rounded,
                    color: Color(0xFF0078D4),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Entrar com $providerNome',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Informe seu e-mail corporativo autorizado para validar as credenciais via $providerNome.',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    if (erroSso != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade700, width: 1),
                        ),
                        child: Text(erroSso!, style: TextStyle(color: Colors.red.shade200, fontSize: 12)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: emailCtrl,
                      style: const TextStyle(color: Colors.white),
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'E-mail Corporativo *',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: _ssoAllowedDomains.isNotEmpty ? 'nome@${_ssoAllowedDomains.first}' : 'usuario@empresa.com.br',
                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                        prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF38BDF8)),
                        filled: true,
                        fillColor: const Color(0xFF334155),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nomeCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Nome Completo (Opcional no 1º acesso)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF38BDF8)),
                        filled: true,
                        fillColor: const Color(0xFF334155),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0078D4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: loading
                      ? null
                      : () async {
                          final email = emailCtrl.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            setModalState(() => erroSso = 'Informe um e-mail corporativo válido.');
                            return;
                          }

                          setModalState(() {
                            loading = true;
                            erroSso = null;
                          });

                          final dialogNav = Navigator.of(ctx);

                          final ok = await authProvider.loginSso(
                            provider: providerId,
                            email: email,
                            name: nomeCtrl.text.trim().isNotEmpty ? nomeCtrl.text.trim() : null,
                          );

                          if (ok && mounted) {
                            dialogNav.pop();
                            await _mostrarModalSugerirBiometria(authProvider);
                          } else if (mounted) {
                            setModalState(() {
                              loading = false;
                              erroSso = authProvider.errorMessage ?? 'Falha na autenticação SSO.';
                            });
                          }
                        },
                  child: loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Autenticar SSO', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _realizarLoginBiometrico() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final ok = await authProvider.loginComBiometria(
      emailOrMatricula: _loginController.text.trim().isNotEmpty ? _loginController.text.trim() : null,
    );
    if (!ok && mounted && authProvider.errorMessage != null && !authProvider.errorMessage!.toLowerCase().contains('cancelad')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _mostrarModalSugerirBiometria(AuthProvider authProvider) async {
    if (!_biometricsAvailable || authProvider.token == null) return;
    try {
      final devicesRes = await _apiService.getWebAuthnDevices(authProvider.token!);
      if (devicesRes.success && devicesRes.data != null && devicesRes.data!.isNotEmpty) {
        return; // Aparelho ou usuário já possui chave cadastrada
      }
    } catch (_) {}

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool enrolling = false;
        String? erroBio;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.fingerprint_rounded, color: Color(0xFF38BDF8), size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Login com Biometria',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Deseja ativar o Face ID ou a Impressão Digital neste aparelho para entrar com 1 toque nos próximos acessos?',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Segurança por Hardware (FIDO2/Passkey): seus dados biométricos nunca saem do celular.',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (erroBio != null) ...[
                      const SizedBox(height: 12),
                      Text(erroBio!, style: TextStyle(color: Colors.red.shade300, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: enrolling ? null : () => Navigator.pop(ctx),
                  child: const Text('Agora Não', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: enrolling
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.fingerprint_rounded, size: 18),
                  label: Text(enrolling ? 'Confirmando...' : 'Ativar Biometria'),
                  onPressed: enrolling
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);

                          setModalState(() {
                            enrolling = true;
                            erroBio = null;
                          });
                          final ok = await authProvider.cadastrarBiometriaAtual(deviceName: 'Dispositivo PWA');
                          if (ok && mounted) {
                            nav.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Biometria ativada com sucesso neste dispositivo!'),
                                backgroundColor: Color(0xFF16A34A),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else if (mounted) {
                            setModalState(() {
                              enrolling = false;
                              erroBio = 'Não foi possível registrar a biometria ou leitura cancelada.';
                            });
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _loginController.text.trim(),
      _senhaController.text,
    );

    if (success && mounted) {
      await _mostrarModalSugerirBiometria(authProvider);
    } else if (authProvider.requiresMfaStep && mounted) {
      _abrirModalMfa(authProvider);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Falha ao autenticar.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _abrirModalMfa(AuthProvider authProvider) {
    final isEmail = authProvider.mfaType == 'EMAIL';
    final codigoCtrl = TextEditingController();
    bool loading = false;
    String? erroMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEmail ? Icons.mark_email_read_rounded : Icons.security_rounded,
                      color: const Color(0xFF38BDF8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEmail ? 'Verificação por E-mail' : 'Autenticação em 2 Etapas (MFA)',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isEmail
                          ? 'Um código PIN de 6 dígitos foi enviado para seu e-mail corporativo (${authProvider.emailMascarado ?? "cadastrado"}). Digite o código abaixo para autenticar.'
                          : 'Digite o código de 6 dígitos gerado no seu aplicativo autenticador (Google ou Microsoft Authenticator) ou um código de backup.',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    if (erroMsg != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade700, width: 1),
                        ),
                        child: Text(
                          erroMsg!,
                          style: TextStyle(color: Colors.red.shade200, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: codigoCtrl,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      maxLength: 9,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        letterSpacing: 4,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), letterSpacing: 4),
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () {
                          authProvider.cancelarMfaStep();
                          Navigator.pop(ctx);
                        },
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: loading
                      ? null
                      : () async {
                          final code = codigoCtrl.text.trim();
                          if (code.isEmpty) {
                            setModalState(() => erroMsg = 'Informe o código de verificação.');
                            return;
                          }
                          setModalState(() {
                            loading = true;
                            erroMsg = null;
                          });

                          final dialogNav = Navigator.of(ctx);

                          final ok = isEmail
                              ? await authProvider.validarLoginEmailMfa(code)
                              : await authProvider.validarLoginTotp(code);

                          if (ok && mounted) {
                            dialogNav.pop();
                          } else if (mounted) {
                            setModalState(() {
                              loading = false;
                              erroMsg = authProvider.errorMessage ?? 'Código inválido.';
                            });
                          }
                        },
                  child: loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Confirmar e Entrar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _abrirModalRecuperacaoSenha() {
    final loginRecupCtrl = TextEditingController(text: _loginController.text.trim());
    final codigoCtrl = TextEditingController();
    final novaSenhaCtrl = TextEditingController();
    final confirmSenhaCtrl = TextEditingController();

    int passo = 1; // 1 = Solicitar código, 2 = Digitar código e nova senha
    bool loading = false;
    String? erroMsg;
    String? emailMascarado;

    showDialog(
      context: context,
      barrierDismissible: !loading,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: AppConstants.primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Recuperar Senha',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (erroMsg != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade700, width: 1),
                          ),
                          child: Text(
                            erroMsg!,
                            style: TextStyle(color: Colors.red.shade200, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (passo == 1) ...[
                        const Text(
                          'Informe sua matrícula ou e-mail cadastrado para receber um código de redefinição de senha.',
                          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: loginRecupCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Matrícula ou E-mail',
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.person_outline, color: AppConstants.primaryColor),
                            filled: true,
                            fillColor: const Color(0xFF334155),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: loading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(loading ? 'Enviando...' : 'Enviar Código por E-mail'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: loading
                              ? null
                              : () async {
                                  final login = loginRecupCtrl.text.trim();
                                  if (login.isEmpty) {
                                    setModalState(() => erroMsg = 'Informe a matrícula ou e-mail.');
                                    return;
                                  }

                                  setModalState(() {
                                    loading = true;
                                    erroMsg = null;
                                  });

                                  final res = await _apiService.solicitarRecuperacaoSenha(login);

                                  if (mounted) {
                                    setModalState(() {
                                      loading = false;
                                      if (res.success) {
                                        passo = 2;
                                        emailMascarado = res.data?['emailMascarado'] as String? ?? 'seu e-mail';
                                      } else {
                                        erroMsg = res.error ?? 'Falha ao solicitar código.';
                                      }
                                    });
                                  }
                                },
                        ),
                      ] else ...[
                        Text(
                          'Enviamos um código de 6 dígitos para o e-mail ${emailMascarado ?? 'cadastrado'}.',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: codigoCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 6, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Código de 6 dígitos',
                            labelStyle: const TextStyle(color: Colors.white70),
                            counterText: '',
                            prefixIcon: const Icon(Icons.pin_rounded, color: AppConstants.primaryColor),
                            filled: true,
                            fillColor: const Color(0xFF334155),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: novaSenhaCtrl,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Nova Senha (mín. 6 caracteres)',
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.lock_outline, color: AppConstants.primaryColor),
                            filled: true,
                            fillColor: const Color(0xFF334155),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: confirmSenhaCtrl,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Confirmar Nova Senha',
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.lock_reset, color: AppConstants.primaryColor),
                            filled: true,
                            fillColor: const Color(0xFF334155),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: loading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_circle_outline, size: 18),
                          label: Text(loading ? 'Redefinindo...' : 'Salvar Nova Senha'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: loading
                              ? null
                              : () async {
                                  final login = loginRecupCtrl.text.trim();
                                  final codigo = codigoCtrl.text.trim();
                                  final novaSenha = novaSenhaCtrl.text;
                                  final confirmSenha = confirmSenhaCtrl.text;

                                  if (codigo.length != 6) {
                                    setModalState(() => erroMsg = 'O código deve ter 6 dígitos.');
                                    return;
                                  }

                                  if (novaSenha.length < 6) {
                                    setModalState(() => erroMsg = 'A senha deve ter no mínimo 6 caracteres.');
                                    return;
                                  }

                                  if (novaSenha != confirmSenha) {
                                    setModalState(() => erroMsg = 'As senhas informadas não coincidem.');
                                    return;
                                  }

                                  final messenger = ScaffoldMessenger.of(context);
                                  final navigator = Navigator.of(ctx);

                                  setModalState(() {
                                    loading = true;
                                    erroMsg = null;
                                  });

                                  final res = await _apiService.redefinirSenha(login, codigo, novaSenha);

                                  if (mounted) {
                                    setModalState(() => loading = false);
                                    if (res.success) {
                                      navigator.pop();
                                      _loginController.text = login;
                                      _senhaController.text = novaSenha;
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Senha redefinida com sucesso! Você já pode entrar.'),
                                          backgroundColor: Color(0xFF16A34A),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    } else {
                                      setModalState(() => erroMsg = res.error ?? 'Falha ao redefinir senha.');
                                    }
                                  }
                                },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: const Color(0xFF1E293B),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      const Icon(Icons.chair_alt, size: 54, color: AppConstants.primaryColor),
                      const SizedBox(height: 12),
                      const Text(
                        'SeatMap Internal',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sistema Inteligente de Reserva de Assentos',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 28),

                      // Campo Login
                      TextFormField(
                        controller: _loginController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Matrícula ou E-mail',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(Icons.person_outline, color: AppConstants.primaryColor),
                          filled: true,
                          fillColor: const Color(0xFF334155),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a matrícula ou e-mail' : null,
                      ),
                      const SizedBox(height: 16),

                      // Campo Senha
                      TextFormField(
                        controller: _senhaController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(Icons.lock_outline, color: AppConstants.primaryColor),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF334155),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Informe sua senha' : null,
                      ),

                      // Link Esqueci Minha Senha
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _abrirModalRecuperacaoSenha,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Esqueceu sua senha?',
                            style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Botão Entrar
                      ElevatedButton(
                        onPressed: auth.isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: auth.isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Entrar no Sistema', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),

                      // Botão Entrar com Biometria / Face ID (FIDO2)
                      if (_biometricsAvailable) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: auth.isLoading ? null : _realizarLoginBiometrico,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.12),
                            side: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.fingerprint_rounded, color: Color(0xFF38BDF8), size: 22),
                          label: const Text(
                            'Entrar com Biometria / Face ID',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],

                      // Provedores de Single Sign-On (SSO) Corporativo
                      if (_ssoEnabled && _ssoProviders.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Expanded(child: Divider(color: Colors.white24)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'OU ACESSE COM',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.5), letterSpacing: 1),
                              ),
                            ),
                            const Expanded(child: Divider(color: Colors.white24)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ..._ssoProviders.map((prov) {
                          final String id = prov['id'] ?? '';
                          final String nome = prov['nome'] ?? 'Microsoft 365 / Entra ID';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFF0078D4).withValues(alpha: 0.12),
                                side: const BorderSide(
                                  color: Color(0xFF0078D4),
                                  width: 1.2,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: auth.isLoading ? null : () => _realizarLoginSso(id, nome),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.window_rounded,
                                    color: Color(0xFF0078D4),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Entrar com $nome',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 24),

                      // Botões de Acesso Rápido para Demonstração
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 12),
                      const Text(
                        'Acesso Rápido para Testes:',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.badge, size: 16, color: Colors.white),
                            label: const Text('Colaborador', style: TextStyle(color: Colors.white, fontSize: 12)),
                            backgroundColor: const Color(0xFF0284C7),
                            onPressed: () => _prefillUser('colaborador@seatmap.local', '123456'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.manage_accounts, size: 16, color: Colors.white),
                            label: const Text('Gestão', style: TextStyle(color: Colors.white, fontSize: 12)),
                            backgroundColor: const Color(0xFF0D9488),
                            onPressed: () => _prefillUser('gestao@seatmap.local', '123456'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.admin_panel_settings, size: 16, color: Colors.white),
                            label: const Text('Admin RH', style: TextStyle(color: Colors.white, fontSize: 12)),
                            backgroundColor: const Color(0xFF7C3AED),
                            onPressed: () => _prefillUser('admin@seatmap.local', '123456'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.terminal, size: 16, color: Colors.white),
                            label: const Text('Admin TI', style: TextStyle(color: Colors.white, fontSize: 12)),
                            backgroundColor: const Color(0xFF0F172A),
                            onPressed: () => _prefillUser('ti@seatmap.local', '123456'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
