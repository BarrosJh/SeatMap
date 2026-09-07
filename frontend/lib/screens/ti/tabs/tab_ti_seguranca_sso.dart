import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TabTiSegurancaSso extends StatelessWidget {
  // MFA
  final String mfaPolicy;
  final ValueChanged<String?> onMfaPolicyChanged;
  final bool mfaTotpEnabled;
  final ValueChanged<bool> onMfaTotpChanged;
  final bool mfaEmailEnabled;
  final ValueChanged<bool> onMfaEmailChanged;

  // Auto-Lock por Inatividade (Segurança Bancária)
  final bool autoLockAtivo;
  final ValueChanged<bool> onAutoLockAtivoChanged;
  final int autoLockMinutos;
  final ValueChanged<int?> onAutoLockMinutosChanged;

  // SSO Global
  final bool ssoEnabled;
  final ValueChanged<bool> onSsoEnabledChanged;
  final TextEditingController ssoAllowedDomainsController;
  final bool ssoAutoProvision;
  final ValueChanged<bool> onSsoAutoProvisionChanged;
  final String ssoDefaultRole;
  final ValueChanged<String?> onSsoDefaultRoleChanged;
  final bool ssoEnforceForDomains;
  final ValueChanged<bool> onSsoEnforceChanged;

  // Azure AD
  final bool ssoAzureEnabled;
  final ValueChanged<bool> onSsoAzureEnabledChanged;
  final String ssoAzureTenantType;
  final ValueChanged<String?> onSsoAzureTenantTypeChanged;
  final TextEditingController ssoAzureTenantIdController;
  final TextEditingController ssoAzureClientIdController;
  final TextEditingController ssoAzureSecretController;
  final bool ssoAzureSecretObscure;
  final bool ssoAzureSecretConfigured;
  final VoidCallback onToggleAzureSecretObscure;
  final TextEditingController ssoAzureRedirectUriController;
  final TextEditingController ssoAzureScopesController;
  final TextEditingController ssoAzureSecurityGroupController;

  // Google
  final bool ssoGoogleEnabled;
  final ValueChanged<bool> onSsoGoogleEnabledChanged;
  final TextEditingController ssoGoogleClientIdController;
  final TextEditingController ssoGoogleSecretController;
  final bool ssoGoogleSecretObscure;
  final bool ssoGoogleSecretConfigured;
  final VoidCallback onToggleGoogleSecretObscure;
  final TextEditingController ssoGoogleHdController;
  final TextEditingController ssoGoogleRedirectUriController;

  // Okta
  final bool ssoOktaEnabled;
  final ValueChanged<bool> onSsoOktaEnabledChanged;
  final TextEditingController ssoOktaDomainController;
  final TextEditingController ssoOktaClientIdController;
  final TextEditingController ssoOktaSecretController;
  final bool ssoOktaSecretObscure;
  final bool ssoOktaSecretConfigured;
  final VoidCallback onToggleOktaSecretObscure;

  // Salvar
  final bool isSaving;
  final VoidCallback onSalvar;

  const TabTiSegurancaSso({
    super.key,
    required this.mfaPolicy,
    required this.onMfaPolicyChanged,
    required this.mfaTotpEnabled,
    required this.onMfaTotpChanged,
    required this.mfaEmailEnabled,
    required this.onMfaEmailChanged,
    required this.autoLockAtivo,
    required this.onAutoLockAtivoChanged,
    required this.autoLockMinutos,
    required this.onAutoLockMinutosChanged,
    required this.ssoEnabled,
    required this.onSsoEnabledChanged,
    required this.ssoAllowedDomainsController,
    required this.ssoAutoProvision,
    required this.onSsoAutoProvisionChanged,
    required this.ssoDefaultRole,
    required this.onSsoDefaultRoleChanged,
    required this.ssoEnforceForDomains,
    required this.onSsoEnforceChanged,
    required this.ssoAzureEnabled,
    required this.onSsoAzureEnabledChanged,
    required this.ssoAzureTenantType,
    required this.onSsoAzureTenantTypeChanged,
    required this.ssoAzureTenantIdController,
    required this.ssoAzureClientIdController,
    required this.ssoAzureSecretController,
    required this.ssoAzureSecretObscure,
    required this.ssoAzureSecretConfigured,
    required this.onToggleAzureSecretObscure,
    required this.ssoAzureRedirectUriController,
    required this.ssoAzureScopesController,
    required this.ssoAzureSecurityGroupController,
    required this.ssoGoogleEnabled,
    required this.onSsoGoogleEnabledChanged,
    required this.ssoGoogleClientIdController,
    required this.ssoGoogleSecretController,
    required this.ssoGoogleSecretObscure,
    required this.ssoGoogleSecretConfigured,
    required this.onToggleGoogleSecretObscure,
    required this.ssoGoogleHdController,
    required this.ssoGoogleRedirectUriController,
    required this.ssoOktaEnabled,
    required this.onSsoOktaEnabledChanged,
    required this.ssoOktaDomainController,
    required this.ssoOktaClientIdController,
    required this.ssoOktaSecretController,
    required this.ssoOktaSecretObscure,
    required this.ssoOktaSecretConfigured,
    required this.onToggleOktaSecretObscure,
    required this.isSaving,
    required this.onSalvar,
  });

  @override
  Widget build(BuildContext context) {
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
                          Icon(Icons.lock_person_rounded, color: Color(0xFF7C3AED), size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Políticas de Autenticação em 2 Etapas (MFA / TOTP)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: mfaPolicy,
                        decoration: const InputDecoration(labelText: 'Política de Aplicação do 2FA', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'OPCIONAL', child: Text('Opcional por Colaborador')),
                          DropdownMenuItem(value: 'OBRIGATORIO_RH', child: Text('Obrigatório para RH & Gestão')),
                          DropdownMenuItem(value: 'OBRIGATORIO_TODOS', child: Text('Obrigatório para Todos os Usuários')),
                          DropdownMenuItem(value: 'DESATIVADO', child: Text('Desativado Globalmente')),
                        ],
                        onChanged: onMfaPolicyChanged,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('App Autenticador TOTP (Google / Microsoft Authenticator RFC 6238)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: const Text('Permite escanear QR Code e autenticar com códigos instantâneos de 30 segundos.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        value: mfaTotpEnabled,
                        activeThumbColor: const Color(0xFF7C3AED),
                        onChanged: onMfaTotpChanged,
                      ),
                      SwitchListTile(
                        title: const Text('Código via E-mail Corporativo (SMTP)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: const Text('Envia PIN de 6 dígitos para o e-mail cadastrado.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        value: mfaEmailEnabled,
                        activeThumbColor: const Color(0xFF7C3AED),
                        onChanged: onMfaEmailChanged,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Bloqueio de Sessão por Inatividade (Padrão Bancário)
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
                          Icon(Icons.timer_outlined, color: Color(0xFFE11D48), size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Bloqueio de Sessão por Inatividade (Auto-Lock Bancário)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Ativar Bloqueio Automático por Inatividade', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: const Text('Bloqueia a tela da aplicação após tempo de inatividade sem interação.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        value: autoLockAtivo,
                        activeThumbColor: const Color(0xFFE11D48),
                        onChanged: onAutoLockAtivoChanged,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: autoLockMinutos,
                        decoration: const InputDecoration(
                          labelText: 'Tempo Limite de Inatividade',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.hourglass_bottom_rounded, size: 20),
                        ),
                        items: const [
                          DropdownMenuItem(value: 5, child: Text('5 minutos (Alta Segurança)')),
                          DropdownMenuItem(value: 10, child: Text('10 minutos')),
                          DropdownMenuItem(value: 15, child: Text('15 minutos (Padrão Bancário)')),
                          DropdownMenuItem(value: 30, child: Text('30 minutos')),
                          DropdownMenuItem(value: 60, child: Text('60 minutos (Máximo)')),
                        ],
                        onChanged: autoLockAtivo ? onAutoLockMinutosChanged : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Governança Global de SSO & JIT
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
                          Icon(Icons.corporate_fare_rounded, color: Color(0xFF0284C7), size: 22),
                          SizedBox(width: 10),
                          Text('Governança Global de Single Sign-On (SSO)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Habilitar Single Sign-On (SSO) Global', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Exibe opções de login corporativo na tela inicial e autoriza federação de identidade.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        value: ssoEnabled,
                        activeThumbColor: const Color(0xFF0284C7),
                        onChanged: onSsoEnabledChanged,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ssoAllowedDomainsController,
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
                              value: ssoAutoProvision,
                              activeThumbColor: const Color(0xFF0284C7),
                              onChanged: onSsoAutoProvisionChanged,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: ssoDefaultRole,
                              decoration: const InputDecoration(
                                labelText: 'Perfil Padrão de Novos Usuários',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'COLABORADOR', child: Text('Colaborador')),
                                DropdownMenuItem(value: 'RH', child: Text('Gestão / RH')),
                              ],
                              onChanged: onSsoDefaultRoleChanged,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Forçar SSO para Domínios Corporativos (SSO Enforcement)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: const Text('Bloqueia login tradicional por senha e exige autenticação via Microsoft/Google para contas do domínio.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        value: ssoEnforceForDomains,
                        activeThumbColor: const Color(0xFFEA580C),
                        onChanged: onSsoEnforceChanged,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Microsoft Entra ID / Azure AD
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: ssoAzureEnabled ? const Color(0xFF0078D4) : const Color(0xFFE2E8F0), width: ssoAzureEnabled ? 1.5 : 1.0),
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
                            value: ssoAzureEnabled,
                            activeThumbColor: const Color(0xFF0078D4),
                            onChanged: onSsoAzureEnabledChanged,
                          ),
                        ],
                      ),
                      if (ssoAzureEnabled) ...[
                        const Divider(height: 32),
                        DropdownButtonFormField<String>(
                          initialValue: ssoAzureTenantType,
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
                          onChanged: onSsoAzureTenantTypeChanged,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: ssoAzureTenantIdController,
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
                                controller: ssoAzureClientIdController,
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
                          controller: ssoAzureSecretController,
                          obscureText: ssoAzureSecretObscure,
                          decoration: InputDecoration(
                            labelText: ssoAzureSecretConfigured ? 'Segredo do Cliente (Client Secret Criptografado AES-256)' : 'Segredo do Cliente (Client Secret) *',
                            helperText: 'Criptografado at-rest com AES-256-GCM. Deixe preenchido com pontos para manter o segredo atual.',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(ssoAzureSecretObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: onToggleAzureSecretObscure,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: ssoAzureRedirectUriController,
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
                                Clipboard.setData(ClipboardData(text: ssoAzureRedirectUriController.text));
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
                                controller: ssoAzureScopesController,
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
                                controller: ssoAzureSecurityGroupController,
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

              // 4. Google Workspace
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: ssoGoogleEnabled ? const Color(0xFFEA4335) : const Color(0xFFE2E8F0), width: ssoGoogleEnabled ? 1.5 : 1.0),
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
                            value: ssoGoogleEnabled,
                            activeThumbColor: const Color(0xFFEA4335),
                            onChanged: onSsoGoogleEnabledChanged,
                          ),
                        ],
                      ),
                      if (ssoGoogleEnabled) ...[
                        const Divider(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: ssoGoogleClientIdController,
                                decoration: const InputDecoration(
                                  labelText: 'ID do Cliente OAuth 2.0 (Client ID) *',
                                  hintText: '000000000000-xxxx.apps.googleusercontent.com',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: ssoGoogleSecretController,
                                obscureText: ssoGoogleSecretObscure,
                                decoration: InputDecoration(
                                  labelText: ssoGoogleSecretConfigured ? 'Segredo do Cliente (Criptografado AES-256)' : 'Segredo do Cliente (Client Secret) *',
                                  helperText: 'Criptografado at-rest com AES-256-GCM.',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: Icon(ssoGoogleSecretObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    onPressed: onToggleGoogleSecretObscure,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: ssoGoogleHdController,
                          decoration: const InputDecoration(
                            labelText: 'Restrição de Domínio Hospedado (Hosted Domain - hd)',
                            hintText: 'empresa.com.br',
                            helperText: 'Impede login com contas Gmail pessoais (@gmail.com).',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: ssoGoogleRedirectUriController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'URI de Redirecionamento Autorizada (Google Cloud Console)',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.copy_rounded, color: Color(0xFFEA4335)),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: ssoGoogleRedirectUriController.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('URI copiada!'), duration: Duration(seconds: 2)),
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

              // 5. Okta Enterprise / SAML 2.0
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: ssoOktaEnabled ? const Color(0xFF00297A) : const Color(0xFFE2E8F0), width: ssoOktaEnabled ? 1.5 : 1.0),
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
                                  Text('Okta Identity Cloud & SAML 2.0', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  Text('Integração corporativa para SSO federado via Okta OIDC/SAML', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: ssoOktaEnabled,
                            activeThumbColor: const Color(0xFF00297A),
                            onChanged: onSsoOktaEnabledChanged,
                          ),
                        ],
                      ),
                      if (ssoOktaEnabled) ...[
                        const Divider(height: 32),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: ssoOktaDomainController,
                                decoration: const InputDecoration(
                                  labelText: 'Domínio Okta (Okta Domain URL) *',
                                  hintText: 'https://sua-empresa.okta.com',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: ssoOktaClientIdController,
                                decoration: const InputDecoration(
                                  labelText: 'Client ID Okta *',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: ssoOktaSecretController,
                                obscureText: ssoOktaSecretObscure,
                                decoration: InputDecoration(
                                  labelText: ssoOktaSecretConfigured ? 'Client Secret (Criptografado AES-256)' : 'Client Secret / Token *',
                                  helperText: 'Criptografado com AES-256-GCM.',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: Icon(ssoOktaSecretObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                    onPressed: onToggleOktaSecretObscure,
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
                  icon: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 20),
                  label: const Text('Salvar Políticas de Segurança & SSO Enterprise', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: isSaving ? null : onSalvar,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

