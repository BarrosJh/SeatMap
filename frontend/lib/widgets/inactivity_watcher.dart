import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class InactivityWatcher extends StatefulWidget {
  final Widget child;

  const InactivityWatcher({super.key, required this.child});

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  Timer? _timer;
  final TextEditingController _unlockPasswordController = TextEditingController();
  bool _isUnlocking = false;
  String? _unlockError;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _unlockPasswordController.dispose();
    super.dispose();
  }

  void _resetTimer() {
    _timer?.cancel();
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (auth.isAuthenticated && auth.autoLockAtivo && !auth.isSessionLocked) {
      final timeoutDuration = Duration(minutes: auth.autoLockMinutos);
      _timer = Timer(timeoutDuration, () {
        if (mounted && auth.isAuthenticated && auth.autoLockAtivo) {
          auth.lockSession();
        }
      });
    }
  }

  void _onUserActivity([dynamic _]) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isSessionLocked) {
      _resetTimer();
    }
  }

  Future<void> _desbloquearSessao(AuthProvider auth) async {
    final senha = _unlockPasswordController.text.trim();
    if (senha.isEmpty) {
      setState(() => _unlockError = 'Informe sua senha para desbloquear a estação.');
      return;
    }

    setState(() {
      _isUnlocking = true;
      _unlockError = null;
    });

    final loginInformado = auth.user?.email ?? auth.user?.matricula ?? '';
    final success = await auth.login(loginInformado, senha);

    if (mounted) {
      setState(() => _isUnlocking = false);
      if (success) {
        _unlockPasswordController.clear();
        auth.unlockSession();
        _resetTimer();
      } else {
        setState(() => _unlockError = auth.errorMessage ?? 'Senha incorreta.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onUserActivity,
          onPointerMove: _onUserActivity,
          onPointerHover: _onUserActivity,
          onPointerSignal: _onUserActivity,
          child: Stack(
            children: [
              widget.child,
              if (auth.isAuthenticated && auth.isSessionLocked)
                _buildLockOverlay(context, auth),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLockOverlay(BuildContext context, AuthProvider auth) {
    final user = auth.user;

    return Material(
      color: const Color(0xEB0A0F1D), // Dark Bank Blur Style
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            elevation: 16,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF334155), width: 1.5),
            ),
            color: const Color(0xFF0F172A),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0x26E11D48),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x66E11D48), width: 2),
                    ),
                    child: const Icon(
                      Icons.lock_clock_rounded,
                      color: Color(0xFFFB7185),
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Sessão Bloqueada por Inatividade',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Por conformidade de segurança bancária, a estação foi protegida após ${auth.autoLockMinutos} minutos de inatividade.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  if (user != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF38BDF8),
                            child: Text(
                              (user.nome.isNotEmpty ? user.nome[0] : 'U').toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.nome,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  user.email,
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _unlockPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Senha de Acesso',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      errorText: _unlockError,
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF38BDF8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => _desbloquearSessao(auth),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isUnlocking ? null : () => _desbloquearSessao(auth),
                      icon: _isUnlocking
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.lock_open_rounded, size: 20),
                      label: Text(
                        _isUnlocking ? 'Verificando...' : 'Desbloquear Estação',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      _unlockPasswordController.clear();
                      auth.unlockSession();
                      auth.logout();
                    },
                    icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFF94A3B8)),
                    label: const Text(
                      'Trocar de Usuário / Encerrar Sessão',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

