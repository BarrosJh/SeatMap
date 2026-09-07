import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';

class ModalDepartamentoForm {
  static void show(
    BuildContext context, {
    required VoidCallback onSalvo,
  }) {
    final novoDepController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Novo Departamento'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: novoDepController,
            decoration: const InputDecoration(
              labelText: 'Nome do Departamento *',
              border: OutlineInputBorder(),
              hintText: 'Ex: Financeiro, Recursos Humanos...',
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

              if (novoDepController.text.trim().isEmpty) return;

              Navigator.pop(ctx);

              final apiService = ApiService();
              final res = await apiService.criarDepartamentoAdmin(
                auth.token!,
                effectiveAdminToken,
                novoDepController.text.trim(),
              );

              messenger.showSnackBar(
                SnackBar(
                  content: Text(res.message ?? res.error ?? 'Departamento criado.'),
                  backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
                ),
              );

              if (res.success) {
                onSalvo();
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
