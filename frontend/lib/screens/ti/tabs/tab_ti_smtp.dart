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
                      const Row(
                        children: [
                          Icon(Icons.mark_email_read_rounded, color: Color(0xFF2563EB), size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Canal de E-mails Corporativos (Criptografia AES-256-GCM)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Selecione o provedor de saída para despacho de comprovantes de reserva, códigos MFA e alertas.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 20),

                      // Seletor de Provedor
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => onProviderChanged('RESEND'),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isResend ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: isResend
                                        ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.bolt_rounded, size: 18, color: isResend ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Resend API (Nuvem / HTTPS)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isResend ? FontWeight.bold : FontWeight.w500,
                                          color: isResend ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: InkWell(
                                onTap: () => onProviderChanged('SMTP'),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: !isResend ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: !isResend
                                        ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.dns_rounded, size: 18, color: !isResend ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'SMTP Tradicional (Gmail / M365)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: !isResend ? FontWeight.bold : FontWeight.w500,
                                          color: !isResend ? const Color(0xFF0F172A) : const Color(0xFF64748B),
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

                      // PAINEL RESEND API
                      if (isResend) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'O Resend opera via HTTPS (Porta 443), garantindo entrega instantânea sem bloqueios de firewall em provedores como Render, AWS ou VPS. Gratuito para até 3.000 e-mails/mês.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.4),
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
                            helperText: resendApiKeyConfigured ? '✔ Chave criptografada ativa no banco' : 'Obtenha gratuitamente em resend.com/api-keys',
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
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ] else ...[
                        // PAINEL SMTP TRADICIONAL
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
                                  helperText: passConfigured ? '✔ Senha criptografada ativa' : null,
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
                            border: const OutlineInputBorder(),
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
                          label: const Text('Salvar Configurações de E-mail', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      const Text(
                        'Teste de Disparo em Tempo Real',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Envie uma mensagem de diagnóstico para verificar a autenticação e tempo de resposta.',
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

