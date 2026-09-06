import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';

class TabPoliticasRelatorios extends StatelessWidget {
  final TextEditingController limiteSemanalController;
  final TextEditingController horarioGestaoController;
  final TextEditingController horarioColabController;
  final TextEditingController horarioCheckinController;
  final String diaGestao;
  final String diaColab;
  final DateTime dataRelatorio;
  final Function(String? value) onDiaGestaoChanged;
  final Function(String? value) onDiaColabChanged;
  final Function(DateTime date) onDataRelatorioChanged;
  final VoidCallback onSalvarParametros;
  final VoidCallback onExecutarLimpezaNoShow;
  final VoidCallback onExportarCsv;

  const TabPoliticasRelatorios({
    super.key,
    required this.limiteSemanalController,
    required this.horarioGestaoController,
    required this.horarioColabController,
    required this.horarioCheckinController,
    required this.diaGestao,
    required this.diaColab,
    required this.dataRelatorio,
    required this.onDiaGestaoChanged,
    required this.onDiaColabChanged,
    required this.onDataRelatorioChanged,
    required this.onSalvarParametros,
    required this.onExecutarLimpezaNoShow,
    required this.onExportarCsv,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, polConstraints) {
                      final isMobile = polConstraints.maxWidth < 600;

                      final inputHorarioGestao = TextFormField(
                        controller: horarioGestaoController,
                        decoration: const InputDecoration(
                          labelText: 'Abertura Gestão (Horário)',
                          border: OutlineInputBorder(),
                        ),
                      );

                      final dropDiaGestao = DropdownButtonFormField<String>(
                        initialValue: diaGestao,
                        decoration: const InputDecoration(
                          labelText: 'Dia da Semana (Gestão)',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: '1', child: Text('Segunda-feira')),
                          DropdownMenuItem(value: '4', child: Text('Quinta-feira')),
                          DropdownMenuItem(value: '5', child: Text('Sexta-feira')),
                        ],
                        onChanged: onDiaGestaoChanged,
                      );

                      final inputHorarioColab = TextFormField(
                        controller: horarioColabController,
                        decoration: const InputDecoration(
                          labelText: 'Abertura Geral (Horário)',
                          border: OutlineInputBorder(),
                        ),
                      );

                      final dropDiaColab = DropdownButtonFormField<String>(
                        initialValue: diaColab,
                        decoration: const InputDecoration(
                          labelText: 'Dia da Semana (Colaborador)',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: '1', child: Text('Segunda-feira')),
                          DropdownMenuItem(value: '4', child: Text('Quinta-feira')),
                          DropdownMenuItem(value: '5', child: Text('Sexta-feira')),
                        ],
                        onChanged: onDiaColabChanged,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Parâmetros Globais de Reserva',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: limiteSemanalController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Limite de Reservas Semanais por Usuário',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (isMobile) ...[
                            inputHorarioGestao,
                            const SizedBox(height: 12),
                            dropDiaGestao,
                          ] else ...[
                            Row(
                              children: [
                                Expanded(child: inputHorarioGestao),
                                const SizedBox(width: 12),
                                Expanded(child: dropDiaGestao),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (isMobile) ...[
                            inputHorarioColab,
                            const SizedBox(height: 12),
                            dropDiaColab,
                          ] else ...[
                            Row(
                              children: [
                                Expanded(child: inputHorarioColab),
                                const SizedBox(width: 12),
                                Expanded(child: dropDiaColab),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: horarioCheckinController,
                            decoration: const InputDecoration(
                              labelText: 'Horário Limite de Check-in Diário (No-Show Cutoff)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              icon: const Icon(Icons.save),
                              label: const Text('Salvar Parâmetros'),
                              onPressed: onSalvarParametros,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ações Operacionais de Emergência',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Dispare manualmente a rotina de liberação de no-show para cancelar reservas sem check-in do dia imediatamente.',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        icon: const Icon(Icons.cleaning_services),
                        label: const Text('Executar Limpeza de No-Show Agora'),
                        onPressed: onExecutarLimpezaNoShow,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, relConstraints) {
                      final isMobile = relConstraints.maxWidth < 550;

                      final btnDataRelatorio = OutlinedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text('Data: ${DateFormat("dd/MM/yyyy").format(dataRelatorio)}'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dataRelatorio,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) onDataRelatorioChanged(picked);
                        },
                      );

                      final btnExportar = ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        icon: const Icon(Icons.download),
                        label: const Text('Exportar CSV de Ocupação'),
                        onPressed: onExportarCsv,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Exportação de Relatórios de Ocupação',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          if (isMobile) ...[
                            SizedBox(width: double.infinity, child: btnDataRelatorio),
                            const SizedBox(height: 10),
                            SizedBox(width: double.infinity, child: btnExportar),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(child: btnDataRelatorio),
                                const SizedBox(width: 12),
                                btnExportar,
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

