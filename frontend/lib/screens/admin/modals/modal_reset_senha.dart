import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/admin_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';

class ModalResetSenha {
  static void show(
    BuildContext context, {
    required AdminUsuarioModel usuario,
    required VoidCallback onSucesso,
  }) {
    final senhaCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Redefinir Senha: ${usuario.nome}'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'E-mail: ${usuario.email} | Matrícula: ${usuario.matricula}',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: senhaCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nova Senha *',
                  helperText: 'Mín. 8 caracteres (A-Z, a-z, 0-9, símbolos)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_reset),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final messenger = ScaffoldMessenger.of(context);
              final effectiveAdminToken = auth.adminToken ?? auth.token;
              if (auth.token == null || effectiveAdminToken == null) return;

              if (senhaCtrl.text.trim().length < 8) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('A senha deve possuir no mínimo 8 caracteres.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(ctx);

              final apiService = ApiService();
              final res = await apiService.resetSenhaUsuarioAdmin(
                auth.token!,
                effectiveAdminToken,
                usuario.id,
                senhaCtrl.text.trim(),
              );

              messenger.showSnackBar(
                SnackBar(
                  content: Text(res.message ?? res.error ?? 'Senha alterada com sucesso.'),
                  backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
                ),
              );

              if (res.success) {
                onSucesso();
              }
            },
            child: const Text('Confirmar Nova Senha'),
          ),
        ],
      ),
    );
  }
}

