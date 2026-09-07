import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TabTiAuditoria extends StatelessWidget {
  final TextEditingController searchController;
  final String filterType;
  final ValueChanged<String?> onFilterTypeChanged;
  final VoidCallback onSearch;
  final bool isLoading;
  final List<dynamic> logs;
  final int page;
  final int totalPages;
  final int totalLogs;
  final VoidCallback? onPrevPage;
  final VoidCallback? onNextPage;

  const TabTiAuditoria({
    super.key,
    required this.searchController,
    required this.filterType,
    required this.onFilterTypeChanged,
    required this.onSearch,
    required this.isLoading,
    required this.logs,
    required this.page,
    required this.totalPages,
    required this.totalLogs,
    this.onPrevPage,
    this.onNextPage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Filtrar por nome, e-mail ou endereço IP...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        searchController.clear();
                        onSearch();
                      },
                    ),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: filterType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Evento',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'TODOS', child: Text('Todos os Eventos')),
                    DropdownMenuItem(value: 'LOGIN_SUCESSO', child: Text('Login Sucesso')),
                    DropdownMenuItem(value: 'LOGIN_FALHA_SENHA', child: Text('Falha de Senha')),
                    DropdownMenuItem(value: 'LOGIN_CONTA_BLOQUEADA', child: Text('Conta Bloqueada')),
                    DropdownMenuItem(value: 'TOTP_VALIDADO', child: Text('TOTP Validado')),
                    DropdownMenuItem(value: 'TOTP_FALHA', child: Text('TOTP Falha')),
                    DropdownMenuItem(value: 'MFA_VALIDADO_EMAIL', child: Text('MFA E-mail')),
                    DropdownMenuItem(value: 'SENHA_RESET_CONCLUIDO', child: Text('Senha Redefinida')),
                  ],
                  onChanged: onFilterTypeChanged,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Buscar'),
                onPressed: onSearch,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : logs.isEmpty
                  ? const Center(child: Text('Nenhum registro de auditoria encontrado.', style: TextStyle(color: Colors.blueGrey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final bool sucesso = log['sucesso'] == true;
                        final String evento = log['tipoEvento'] ?? 'ACESSO';
                        final String usuario = log['usuarioNome'] ?? log['loginInformado'] ?? 'Desconhecido';
                        final String ip = log['ip'] ?? '127.0.0.1';
                        final String userAgent = log['userAgent'] ?? 'N/A';
                        final String dataHora = log['criadoEm'] != null
                            ? DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.parse(log['criadoEm']).toLocal())
                            : 'N/A';

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: Colors.white,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: sucesso ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  sucesso ? Icons.check_circle_rounded : Icons.gpp_bad_rounded,
                                  color: sucesso ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(usuario, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: sucesso ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E8),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            evento,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: sucesso ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('IP: $ip • Dispositivo: $userAgent', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Text(dataHora, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        );
                      },
                    ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: $totalLogs eventos registrados • Página $page de $totalPages',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: 'Página Anterior',
                    onPressed: onPrevPage,
                  ),
                  Text('$page / $totalPages', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: 'Próxima Página',
                    onPressed: onNextPage,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

