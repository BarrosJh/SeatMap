import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../models/admin_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';

class ModalUsuarioForm {
  static void show(
    BuildContext context, {
    AdminUsuarioModel? usuario,
    required List<DepartamentoModel> departamentos,
    String? titleSuffix,
    required VoidCallback onSalvo,
  }) {
    final nomeCtrl = TextEditingController(text: usuario?.nome ?? '');
    final emailCtrl = TextEditingController(text: usuario?.email ?? '');
    final matCtrl = TextEditingController(text: usuario?.matricula ?? '');
    final senhaCtrl = TextEditingController();
    int? selectedDep = usuario?.departamentoId;
    String selectedPerfil = (usuario?.perfil == 'GESTAO') ? 'GESTAO' : 'COLABORADOR';
    bool permissaoRh = usuario?.permissaoRh ?? (usuario?.perfil == 'ADMIN_RH');
    bool permissaoTi = usuario?.permissaoTi ?? (usuario?.perfil == 'ADMIN_TI');
    bool exigirMfa = usuario?.exigirMfa ?? false;
    bool ativo = usuario?.ativo ?? true;

    final String titleText = usuario == null
        ? 'Novo Usuário${titleSuffix != null ? " ($titleSuffix)" : ""}'
        : 'Editar Usuário${titleSuffix != null ? " ($titleSuffix)" : ""}';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Icon(
                usuario == null ? Icons.person_add_alt_1_rounded : Icons.manage_accounts_rounded,
                color: const Color(0xFF0F172A),
              ),
              const SizedBox(width: 10),
              Text(
                titleText,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  // Linha 1: Nome e Matrícula
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: nomeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nome Completo *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: matCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Matrícula *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge_outlined, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Linha 2: E-mail e Senha (se novo)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: usuario == null ? 3 : 1,
                        child: TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'E-mail Corporativo *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                          ),
                        ),
                      ),
                      if (usuario == null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: senhaCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Senha Inicial *',
                              helperText: 'Mín. 8 caracteres (A-Z, a-z, 0-9, símbolos)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock_outline, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Linha 3: Departamento e Perfil Funcional
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          initialValue: selectedDep,
                          decoration: const InputDecoration(
                            labelText: 'Departamento',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.domain_outlined, size: 20),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Nenhum / Geral')),
                            ...departamentos.map((d) => DropdownMenuItem(value: d.id, child: Text(d.nome))),
                          ],
                          onChanged: (v) => setModalState(() => selectedDep = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedPerfil,
                          decoration: const InputDecoration(
                            labelText: 'Perfil Funcional *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge_rounded, size: 20),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'COLABORADOR', child: Text('Colaborador (Faz Check-in)')),
                            DropdownMenuItem(value: 'GESTAO', child: Text('Gestão (Isento Check-in)')),
                          ],
                          onChanged: (v) => setModalState(() => selectedPerfil = v ?? 'COLABORADOR'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Permissão Especial de RH
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: permissaoRh ? Colors.purple.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: permissaoRh ? Colors.purple.shade300 : Colors.grey.shade300),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        permissaoRh ? 'Permissão Especial de RH (Ativa)' : 'Permissão Especial de RH (Inativa)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: permissaoRh ? Colors.purple.shade900 : Colors.grey.shade800,
                        ),
                      ),
                      subtitle: const Text(
                        'Acesso ao painel administrativo de gestão de pessoas e reservas.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      value: permissaoRh,
                      activeThumbColor: Colors.purple.shade700,
                      onChanged: (v) => setModalState(() => permissaoRh = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Permissão Especial de T.I.
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: permissaoTi ? Colors.cyan.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: permissaoTi ? Colors.cyan.shade300 : Colors.grey.shade300),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        permissaoTi ? 'Permissão de T.I. & Infraestrutura (Ativa)' : 'Permissão de T.I. (Inativa)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: permissaoTi ? Colors.cyan.shade900 : Colors.grey.shade800,
                        ),
                      ),
                      subtitle: const Text(
                        'Acesso ao painel de infraestrutura, SMTP, auditoria e gestão de usuários.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      value: permissaoTi,
                      activeThumbColor: Colors.cyan.shade700,
                      onChanged: (v) => setModalState(() => permissaoTi = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Exigir Autenticação em 2 Etapas (MFA)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: exigirMfa ? Colors.amber.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: exigirMfa ? Colors.amber.shade400 : Colors.grey.shade300),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        exigirMfa ? 'Exigir 2FA / MFA no Login (Ativo)' : 'Exigir 2FA / MFA no Login (Opcional)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: exigirMfa ? Colors.amber.shade900 : Colors.grey.shade800,
                        ),
                      ),
                      subtitle: const Text(
                        'Obriga o colaborador a validar PIN por E-mail ou TOTP ao autenticar.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      value: exigirMfa,
                      activeThumbColor: Colors.amber.shade800,
                      onChanged: (v) => setModalState(() => exigirMfa = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Status Ativo / Inativo
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: ativo ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ativo ? Colors.green.shade200 : Colors.red.shade200),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        ativo ? 'Usuário Ativo (Acesso Liberado)' : 'Usuário Inativo (Acesso Bloqueado)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: ativo ? Colors.green.shade900 : Colors.red.shade900,
                        ),
                      ),
                      value: ativo,
                      activeThumbColor: Colors.green.shade700,
                      onChanged: (v) => setModalState(() => ativo = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final messenger = ScaffoldMessenger.of(context);
                final effectiveAdminToken = auth.adminToken ?? auth.token;
                if (auth.token == null || effectiveAdminToken == null) return;

                if (nomeCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty || matCtrl.text.trim().isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Preencha os campos obrigatórios (*).'), backgroundColor: Colors.red),
                  );
                  return;
                }

                if (usuario == null && senhaCtrl.text.trim().isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Informe uma senha inicial.'), backgroundColor: Colors.red),
                  );
                  return;
                }

                Navigator.pop(ctx);

                final apiService = ApiService();
                if (usuario == null) {
                  final res = await apiService.criarUsuarioAdmin(auth.token!, effectiveAdminToken, {
                    'nome': nomeCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'matricula': matCtrl.text.trim(),
                    'senha': senhaCtrl.text.trim(),
                    'departamentoId': selectedDep,
                    'perfil': selectedPerfil,
                    'permissaoRh': permissaoRh,
                    'permissaoTi': permissaoTi,
                    'exigirMfa': exigirMfa,
                    'ativo': ativo,
                  });
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(res.message ?? res.error ?? 'Usuário criado com sucesso.'),
                      backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  );
                } else {
                  final res = await apiService.updateUsuarioAdmin(auth.token!, effectiveAdminToken, usuario.id, {
                    'nome': nomeCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'matricula': matCtrl.text.trim(),
                    'departamentoId': selectedDep,
                    'perfil': selectedPerfil,
                    'permissaoRh': permissaoRh,
                    'permissaoTi': permissaoTi,
                    'exigirMfa': exigirMfa,
                    'ativo': ativo,
                  });
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(res.message ?? res.error ?? 'Usuário atualizado com sucesso.'),
                      backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  );
                }

                onSalvo();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
