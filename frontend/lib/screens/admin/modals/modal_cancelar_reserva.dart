import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/admin_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';

class ModalCancelarReserva {
  static void show(
    BuildContext context, {
    required AdminReservaModel reserva,
    required VoidCallback onCancelado,
  }) {
    final justCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Cancelar Reserva (Gestão/RH)'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Colaborador: ${reserva.usuarioNome} (${reserva.matricula})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('Data: ${reserva.dataReserva} | Assento: ${reserva.assento} (${reserva.baiaNome})'),
              const SizedBox(height: 4),
              Text('Escritório: ${reserva.escritorioNome}'),
              const SizedBox(height: 16),
              TextField(
                controller: justCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Justificativa do Cancelamento (Opcional)',
                  hintText: 'Ex: Mudança de escala, evento corporativo...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Voltar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final messenger = ScaffoldMessenger.of(context);
              final effectiveAdminToken = auth.adminToken ?? auth.token;
              if (auth.token == null || effectiveAdminToken == null) return;

              Navigator.pop(ctx);

              final apiService = ApiService();
              final res = await apiService.cancelarReservaAdmin(
                auth.token!,
                effectiveAdminToken,
                reserva.id,
                justificativa: justCtrl.text.trim(),
              );

              messenger.showSnackBar(
                SnackBar(
                  content: Text(res.message ?? res.error ?? 'Reserva cancelada.'),
                  backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
                ),
              );

              if (res.success) {
                onCancelado();
              }
            },
            child: const Text('Confirmar Cancelamento'),
          ),
        ],
      ),
    );
  }
}

