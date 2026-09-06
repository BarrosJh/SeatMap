import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'main_navigation.dart';

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _loginController.text.trim(),
      _senhaController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Falha ao autenticar.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
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
