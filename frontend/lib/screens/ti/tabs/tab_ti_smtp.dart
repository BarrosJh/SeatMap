import 'package:flutter/material.dart';

class TabTiSmtp extends StatelessWidget {
  final String emailProvider; // 'RESEND' ou 'SMTP'
  final ValueChanged<String> onProviderChanged;
  final TextEditingController resendApiKeyController;
  final bool resendApiKeyObscure;
  final VoidCallback onToggleResendApiKeyObscure;
  final bool resendApiKeyConfigured;
  final TextEditingController hostController;
  final TextEditingController portController;
  final bool secure;
  final ValueChanged<bool> onSecureChanged;
  final TextEditingController userController;
  final TextEditingController passController;
  final bool passObscure;
  final VoidCallback onTogglePassObscure;
  final bool passConfigured;
  final TextEditingController emailFromController;
  final TextEditingController testEmailController;
  final bool isSaving;
  final bool isTesting;
  final VoidCallback onSalvar;
  final VoidCallback onTestar;

  const TabTiSmtp({
    super.key,
    required this.emailProvider,
    required this.onProviderChanged,
    required this.resendApiKeyController,
    required this.resendApiKeyObscure,
    required this.onToggleResendApiKeyObscure,
    required this.resendApiKeyConfigured,
    required this.hostController,
    required this.portController,
    required this.secure,
    required this.onSecureChanged,
    required this.userController,
    required this.passController,
    required this.passObscure,
    required this.onTogglePassObscure,
    required this.passConfigured,
    required this.emailFromController,
    required this.testEmailController,
    required this.isSaving,
    required this.isTesting,
    required this.onSalvar,
    required this.onTestar,
  });

  @override
  Widget build(BuildContext context) {
    final isResend = emailProvider == 'RESEND';

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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.mark_email_read_rounded, color: Color(0xFF2563EB), size: 24),
                              SizedBox(width: 10),
                              Text(
                                'Canal de E-mails Corporativos',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isResend ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isResend ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 8, color: isResend ? const Color(0xFF10B981) : const Color(0xFF2563EB)),
                                const SizedBox(width: 6),
                                Text(
                                  isResend ? 'PROVEDOR SELECIONADO: RESEND API' : 'PROVEDOR SELECIONADO: SMTP',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isResend ? const Color(0xFF065F46) : const Color(0xFF1E40AF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Escolha qual mecanismo de saída o SeatMap utilizará para despachar comprovantes de reserva, códigos MFA e alertas.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 20),

                      // SELETOR COM SWITCH / RADIO VISUAL CLARO
                      RadioGroup<String>(
                        groupValue: emailProvider,
                        onChanged: (val) {
                          if (val != null) onProviderChanged(val);
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => onProviderChanged('RESEND'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isResend ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isResend ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0),
                                      width: isResend ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Radio<String>(
                                        value: 'RESEND',
                                        activeColor: Color(0xFF16A34A),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Text(
                                                  'Resend API (HTTPS)',
                                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isResend ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    isResend ? 'ATIVO' : 'CLIQUE P/ ATIVAR',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: isResend ? const Color(0xFF15803D) : const Color(0xFF94A3B8),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Recomendado para Nuvem / Render (Porta 443 sem bloqueios)',
                                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => onProviderChanged('SMTP'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: !isResend ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: !isResend ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                      width: !isResend ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Radio<String>(
                                        value: 'SMTP',
                                        activeColor: Color(0xFF2563EB),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Text(
                                                  'SMTP Tradicional',
                                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: !isResend ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    !isResend ? 'ATIVO' : 'CLIQUE P/ ATIVAR',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: !isResend ? const Color(0xFF1E40AF) : const Color(0xFF94A3B8),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Gmail, Office 365 ou Servidor de E-mail Dedicado',
                                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // CAMPOS DO PROVEDOR RESEND API
                      if (isResend) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.bolt_rounded, color: Color(0xFF16A34A), size: 22),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Conexão Direta HTTPS ativa. As mensagens são despachadas instantaneamente através da API oficial do Resend.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: resendApiKeyController,
                          obscureText: resendApiKeyObscure,
                          decoration: InputDecoration(
                            labelText: 'API Key do Resend (re_...) *',
                            helperText: resendApiKeyConfigured ? '✔ Chave criptografada com AES-256 ativa no banco' : 'Obtenha gratuitamente em resend.com/api-keys',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(resendApiKeyObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: onToggleResendApiKeyObscure,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: emailFromController,
                          decoration: const InputDecoration(
                            labelText: 'E-mail Remetente (From) *',
                            helperText: 'Ex: SeatMap Corporativo <onboarding@resend.dev> ou seu domínio verificado',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ] else ...[
                        // CAMPOS DO PROVEDOR SMTP TRADICIONAL
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
                          subtitle: const Text('Desmarque para porta 587 (STARTTLS)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
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
                                  helperText: passConfigured ? '✔ Senha criptografada com AES-256 ativa' : null,
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
                          decoration: const InputDecoration(
                            labelText: 'E-mail Remetente (From) *',
                            helperText: 'Ex: "SeatMap Corporativo" <nao-responda@suaempresa.com.br>',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
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
                          label: Text(
                            isResend ? 'Salvar & Ativar Resend API' : 'Salvar & Ativar SMTP',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: isSaving ? null : onSalvar,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // CARD DE TESTE DE DISPARO
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
                          const Text(
                            'Teste de Disparo em Tempo Real',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            isResend ? 'Canal: Resend API (HTTPS)' : 'Canal: SMTP (${hostController.text})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isResend ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Envie uma mensagem de diagnóstico para verificar a autenticação e tempo de resposta do canal configurado.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: testEmailController,
                              decoration: const InputDecoration(labelText: 'E-mail de Destino para Teste', border: OutlineInputBorder()),
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
                            label: const Text('Testar Disparo', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: isTesting ? null : onTestar,
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
}

