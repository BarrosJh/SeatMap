import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../models/admin_models.dart';

class TabReservasGlobal extends StatelessWidget {
  final List<AdminReservaModel> reservas;
  final int totalReservas;
  final TextEditingController searchController;
  final DateTime filtroDataInicio;
  final DateTime filtroDataFim;
  final String filtroEscritorio;
  final String filtroStatus;
  final VoidCallback onBuscar;
  final Function(DateTime dataInicio) onDataInicioChanged;
  final Function(DateTime dataFim) onDataFimChanged;
  final Function(String? value) onEscritorioChanged;
  final Function(String? value) onStatusChanged;
  final Function(AdminReservaModel reserva) onCancelarReserva;

  const TabReservasGlobal({
    super.key,
    required this.reservas,
    required this.totalReservas,
    required this.searchController,
    required this.filtroDataInicio,
    required this.filtroDataFim,
    required this.filtroEscritorio,
    required this.filtroStatus,
    required this.onBuscar,
    required this.onDataInicioChanged,
    required this.onDataFimChanged,
    required this.onEscritorioChanged,
    required this.onStatusChanged,
    required this.onCancelarReserva,
  });

  String _formatarData(String isoDate) {
    try {
      final parsed = DateTime.parse(isoDate);
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: LayoutBuilder(
                    builder: (context, filterConstraints) {
                      final isMobileFilter = filterConstraints.maxWidth < 650;

                      final searchField = TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'Buscar por colaborador, matrícula ou assento...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => onBuscar(),
                      );

                      final btnFiltrar = ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        icon: const Icon(Icons.search),
                        label: const Text('Filtrar'),
                        onPressed: onBuscar,
                      );

                      final btnDataInicio = OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text('De: ${DateFormat("dd/MM/yyyy").format(filtroDataInicio)}', style: const TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: filtroDataInicio,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                            locale: const Locale('pt', 'BR'),
                            helpText: 'Selecione a Data Inicial',
                            cancelText: 'Cancelar',
                            confirmText: 'Selecionar',
                          );
                          if (p != null) {
                            onDataInicioChanged(p);
                          }
                        },
                      );

                      final btnDataFim = OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text('Até: ${DateFormat("dd/MM/yyyy").format(filtroDataFim)}', style: const TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: filtroDataFim,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                            locale: const Locale('pt', 'BR'),
                            helpText: 'Selecione a Data Final',
                            cancelText: 'Cancelar',
                            confirmText: 'Selecionar',
                          );
                          if (p != null) {
                            onDataFimChanged(p);
                          }
                        },
                      );

                      final dropEscritorio = DropdownButtonFormField<String>(
                        initialValue: filtroEscritorio,
                        decoration: const InputDecoration(labelText: 'Escritório', isDense: true, border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'todos', child: Text('Todos os Escritórios', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: '1', child: Text('Berrini')),
                          DropdownMenuItem(value: '2', child: Text('Barueri')),
                        ],
                        onChanged: onEscritorioChanged,
                      );

                      final dropStatus = DropdownButtonFormField<String>(
                        initialValue: filtroStatus,
                        decoration: const InputDecoration(labelText: 'Status', isDense: true, border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'todos', child: Text('Todos os Status')),
                          DropdownMenuItem(value: 'ATIVA', child: Text('Ativa')),
                          DropdownMenuItem(value: 'CANCELADA', child: Text('Cancelada')),
                          DropdownMenuItem(value: 'EXPIRADA_NOSHOW', child: Text('No-Show')),
                        ],
                        onChanged: onStatusChanged,
                      );

                      if (isMobileFilter) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(child: searchField),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  style: IconButton.styleFrom(backgroundColor: AppConstants.primaryColor),
                                  icon: const Icon(Icons.search, color: Colors.white),
                                  onPressed: onBuscar,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            btnDataInicio,
                            const SizedBox(height: 10),
                            btnDataFim,
                            const SizedBox(height: 10),
                            dropEscritorio,
                            const SizedBox(height: 10),
                            dropStatus,
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: searchField),
                              const SizedBox(width: 12),
                              btnFiltrar,
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: btnDataInicio),
                              const SizedBox(width: 8),
                              Expanded(child: btnDataFim),
                              const SizedBox(width: 8),
                              Expanded(child: dropEscritorio),
                              const SizedBox(width: 8),
                              Expanded(child: dropStatus),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total de Reservas Encontradas ($totalReservas)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Atualizar Lista',
                    onPressed: onBuscar,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              reservas.isEmpty
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text('Nenhuma reserva encontrada para o período selecionado.', style: TextStyle(color: Colors.grey.shade600)),
                        ),
                      ),
                    )
                  : Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: reservas.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final r = reservas[i];
                          final isAtiva = r.status == 'ATIVA';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isAtiva ? const Color(0xFF0F172A) : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                r.assento,
                                style: TextStyle(fontWeight: FontWeight.bold, color: isAtiva ? Colors.white : Colors.grey.shade700),
                              ),
                            ),
                            title: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(r.usuarioNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isAtiva
                                        ? Colors.green.shade50
                                        : (r.status == 'CANCELADA' ? Colors.red.shade50 : Colors.orange.shade50),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isAtiva
                                          ? Colors.green.shade300
                                          : (r.status == 'CANCELADA' ? Colors.red.shade300 : Colors.orange.shade300),
                                    ),
                                  ),
                                  child: Text(
                                    r.status,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isAtiva
                                          ? Colors.green.shade700
                                          : (r.status == 'CANCELADA' ? Colors.red.shade700 : Colors.orange.shade800),
                                    ),
                                  ),
                                ),
                                if (r.checkinRealizado) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.blue.shade300),
                                    ),
                                    child: Text(
                                      'CHECK-IN OK',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Data: ${_formatarData(r.dataReserva)} | Local: ${r.escritorioNome} - ${r.baiaNome}\nMatrícula: ${r.matricula} | Depto: ${r.departamentoNome ?? "Geral"}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ),
                            trailing: isAtiva
                                ? IconButton(
                                    icon: const Icon(Icons.cancel_outlined, size: 20, color: Colors.red),
                                    tooltip: 'Cancelar Reserva',
                                    onPressed: () => onCancelarReserva(r),
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

