import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';

class BiometriaDialog {
  static Future<void> showSugestao(BuildContext context, AuthProvider authProvider) async {
    bool enrolling = false;
    String? erroBio;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.fingerprint_rounded, color: Color(0xFF38BDF8), size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ativar Biometria / Face ID?',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Detectamos suporte a biometria neste dispositivo. Deseja cadastrá-lo para entrar com 1 toque nas próximas vezes, sem digitar senha?',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Segurança FIDO2/Passkey: seus dados biométricos nunca saem deste aparelho.',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (erroBio != null) ...[
                      const SizedBox(height: 12),
                      Text(erroBio!, style: TextStyle(color: Colors.red.shade300, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: enrolling ? null : () => Navigator.pop(ctx),
                  child: const Text('Agora Não', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: enrolling
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.fingerprint_rounded, size: 18),
                  label: Text(enrolling ? 'Confirmando...' : 'Ativar Agora'),
                  onPressed: enrolling
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);

                          setModalState(() {
                            enrolling = true;
                            erroBio = null;
                          });
                          final ok = await authProvider.cadastrarBiometriaAtual(deviceName: 'Dispositivo PWA');
                          if (ok) {
                            nav.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Biometria ativada com sucesso neste dispositivo!'),
                                backgroundColor: Color(0xFF16A34A),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            setModalState(() {
                              enrolling = false;
                              erroBio = 'Não foi possível registrar a biometria ou a leitura foi cancelada.';
                            });
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
