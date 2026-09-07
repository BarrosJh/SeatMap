import 'package:flutter/material.dart';

class TabTiSmtp extends StatelessWidget {
  final TextEditingController hostController;
  final TextEditingController portController;
  final bool secure;
  final ValueChanged<bool> onSecureChanged;
  final TextEditingController userController;
  final TextEditingController passController;
  final bool passObscure;
  final VoidCallback onTogglePassObscure;
  final TextEditingController emailFromController;
  final TextEditingController testEmailController;
  final bool isSaving;
  final bool isTesting;
  final VoidCallback onSalvar;
  final VoidCallback onTestar;

  const TabTiSmtp({
    super.key,
    required this.hostController,
    required this.portController,
    required this.secure,
    required this.onSecureChanged,
    required this.userController,
    required this.passController,
    required this.passObscure,
    required this.onTogglePassObscure,
    required this.emailFromController,
    required this.testEmailController,
    required this.isSaving,
    required this.isTesting,
    required this.onSalvar,
    required this.onTestar,
  });

  @override
  Widget build(BuildContext context) {
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
                            'Parâmetros do Servidor SMTP (Criptografia AES-256-GCM)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: hostController,
                              decoration: const InputDecoration(labelText: 'Host do Servidor SMTP *', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: portController,
                              decoration: const InputDecoration(labelText: 'Porta *', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Conexão Segura Direta (SSL / TLS 465)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        value: secure,
                        activeThumbColor: const Color(0xFF2563EB),
                        onChanged: onSecureChanged,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: userController,
                              decoration: const InputDecoration(labelText: 'Usuário SMTP *', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: passController,
                              obscureText: passObscure,
                              decoration: InputDecoration(
                                labelText: 'Senha / App Password *',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(passObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                  onPressed: onTogglePassObscure,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailFromController,
                        decoration: const InputDecoration(labelText: 'E-mail Remetente (From) *', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          ),
                          icon: isSaving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Salvar Servidor SMTP', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: isSaving ? null : onSalvar,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: testEmailController,
                          decoration: const InputDecoration(labelText: 'E-mail de Teste de Disparo', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                        icon: isTesting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Testar Conexão', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: isTesting ? null : onTestar,
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
}

