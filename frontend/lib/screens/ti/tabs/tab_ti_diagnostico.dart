import 'package:flutter/material.dart';

class TabTiDiagnostico extends StatelessWidget {
  final Map<String, dynamic>? statusSistema;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  const TabTiDiagnostico({
    super.key,
    required this.statusSistema,
    required this.isRefreshing,
    required this.onRefresh,
  });

  String _formatUptime(int seconds) {
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final parts = <String>[];
    if (d > 0) parts.add('${d}d');
    if (h > 0) parts.add('${h}h');
    if (m > 0) parts.add('${m}m');
    parts.add('${s}s');
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final db = statusSistema?['database'] ?? {};
    final ws = statusSistema?['websocket'] ?? {};
    final mem = statusSistema?['memory'] ?? {};
    final uptimeSeconds = statusSistema?['uptimeSegundos'] ?? 0;
    final server = statusSistema?['server'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Monitoramento em Tempo Real', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
                    icon: isRefreshing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Atualizar Métricas'),
                    onPressed: isRefreshing ? null : onRefresh,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.storage_rounded,
                      iconColor: const Color(0xFF2563EB),
                      title: 'Banco PostgreSQL',
                      statusText: 'OPERACIONAL',
                      statusColor: Colors.green.shade700,
                      details: [
                        'Latência: ${db['latenciaMs'] ?? 0} ms',
                        'Pool Total: ${db['pool']?['total'] ?? 0}',
                        'Conexões Livres: ${db['pool']?['idle'] ?? 0}',
                        'Em Fila: ${db['pool']?['waiting'] ?? 0}',
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.sync_alt_rounded,
                      iconColor: const Color(0xFF0D9488),
                      title: 'WebSockets Nativo',
                      statusText: 'ONLINE',
                      statusColor: Colors.green.shade700,
                      details: [
                        'Clientes Ativos: ${ws['conexoesAtivas'] ?? 0}',
                        'Engine: WebSocket Nativo (ws)',
                        'Heartbeat: 30 segundos',
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.memory_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      title: 'Memória do Processo',
                      statusText: 'ESTÁVEL',
                      statusColor: Colors.green.shade700,
                      details: [
                        'Heap Utilizado: ${mem['heapUsedMb'] ?? 0} MB',
                        'Heap Total: ${mem['heapTotalMb'] ?? 0} MB',
                        'Memória RSS: ${mem['rssMb'] ?? 0} MB',
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.timer_outlined,
                      iconColor: const Color(0xFFEA580C),
                      title: 'Servidor & Uptime',
                      statusText: 'ATIVO',
                      statusColor: Colors.green.shade700,
                      details: [
                        'Tempo Ativo: ${_formatUptime(uptimeSeconds)}',
                        'Node.js: ${server['nodeVersion'] ?? 'v20+'}',
                        'Plataforma: ${server['platform'] ?? 'win32'}',
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String statusText,
    required Color statusColor,
    required List<String> details,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: iconColor, size: 20),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(statusText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...details.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $d', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                )),
          ],
        ),
      ),
    );
  }
}

