import 'package:flutter/material.dart';
import '../../../models/seat_model.dart';
import '../../../models/user_model.dart';

class OccupantDetailsModal {
  static void show({
    required BuildContext context,
    required CadeiraModel cadeira,
    required UserModel currentUser,
  }) {
    final ocupante = cadeira.ocupante;
    final isMinha = cadeira.isMinhaReserva;
    final isSameDept = ocupante != null &&
        ocupante.departamentoId != null &&
        ocupante.departamentoId == currentUser.departamentoId;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isMinha
                            ? const Color(0xFF2563EB)
                            : (isSameDept ? Colors.amber.shade700 : const Color(0xFFDC2626)),
                        radius: 24,
                        child: Icon(
                          isMinha ? Icons.person : (isSameDept ? Icons.group : Icons.person_outline),
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMinha ? '${currentUser.nome} (Você)' : (ocupante?.nome ?? 'Colega'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              isMinha
                                  ? (currentUser.departamentoNome ?? 'Geral')
                                  : (ocupante?.departamento ?? 'Sem departamento'),
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        backgroundColor: Colors.grey.shade100,
                        label: Text(
                          'Mesa ${cadeira.identificador}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),
                  if (ocupante != null) ...[
                    if (isSameDept && !isMinha)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Colega do seu mesmo departamento!',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_outline, color: Colors.blueGrey),
                      title: const Text('Status do Check-in:'),
                      subtitle: Text(
                        ocupante.checkinRealizado ? 'Presença Confirmada' : 'Aguardando confirmação diária',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: ocupante.checkinRealizado ? Colors.green : Colors.orange.shade800,
                        ),
                      ),
                    ),
                    if (ocupante.matricula != null && (currentUser.isAdmin || currentUser.isGestao))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.badge_outlined, color: Colors.blueGrey),
                        title: const Text('Matrícula:'),
                        subtitle: Text(ocupante.matricula!),
                      ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fechar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

