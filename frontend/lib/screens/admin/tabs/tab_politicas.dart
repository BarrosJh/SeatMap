import 'package:flutter/material.dart';

class TabPoliticas extends StatelessWidget {
  final TextEditingController limiteSemanalController;
  final TextEditingController horarioGestaoController;
  final TextEditingController horarioColabController;
  final TextEditingController horarioInicioCheckinController;
  final TextEditingController horarioCheckinController;
  final TextEditingController avisoGlobalController;
  final String diaGestao;
  final String diaColab;
  final bool permitirTroca;
  final bool checkinAutoGestao;
  final Function(String? value) onDiaGestaoChanged;
  final Function(String? value) onDiaColabChanged;
  final Function(bool value) onPermitirTrocaChanged;
  final Function(bool value) onCheckinAutoGestaoChanged;
  final VoidCallback onSalvarParametros;
  final VoidCallback onExecutarLimpezaNoShow;

  const TabPoliticas({
    super.key,
    required this.limiteSemanalController,
    required this.horarioGestaoController,
    required this.horarioColabController,
    required this.horarioInicioCheckinController,
    required this.horarioCheckinController,
    required this.avisoGlobalController,
    required this.diaGestao,
    required this.diaColab,
    required this.permitirTroca,
    required this.checkinAutoGestao,
    required this.onDiaGestaoChanged,
    required this.onDiaColabChanged,
    required this.onPermitirTrocaChanged,
    required this.onCheckinAutoGestaoChanged,
    required this.onSalvarParametros,
    required this.onExecutarLimpezaNoShow,
  });

  static const List<DropdownMenuItem<String>> _diasSemanaItems = [
    DropdownMenuItem(value: '1', child: Text('Segunda-feira')),
    DropdownMenuItem(value: '2', child: Text('Terça-feira')),
    DropdownMenuItem(value: '3', child: Text('Quarta-feira')),
    DropdownMenuItem(value: '4', child: Text('Quinta-feira')),
    DropdownMenuItem(value: '5', child: Text('Sexta-feira')),
    DropdownMenuItem(value: '6', child: Text('Sábado')),
    DropdownMenuItem(value: '7', child: Text('Domingo')),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. CARD: REGRAS DE ABERTURA E LIMITES
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(
                    builder: (context, polConstraints) {
                      final isMobile = polConstraints.maxWidth < 620;

                      final inputHorarioGestao = TextFormField(
                        controller: horarioGestaoController,
                        decoration: const InputDecoration(
                          labelText: 'Horário Abertura (Gestão)',
                          hintText: '08:00',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time_rounded, size: 20),
                        ),
                      );

                      final dropDiaGestao = DropdownButtonFormField<String>(
                        initialValue: diaGestao,
                        decoration: const InputDecoration(
                          labelText: 'Dia Abertura (Gestão)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
                        ),
                        items: _diasSemanaItems,
                        onChanged: onDiaGestaoChanged,
                      );

                      final inputHorarioColab = TextFormField(
                        controller: horarioColabController,
                        decoration: const InputDecoration(
                          labelText: 'Horário Abertura (Geral)',
                          hintText: '12:00',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time_rounded, size: 20),
                        ),
                      );

                      final dropDiaColab = DropdownButtonFormField<String>(
                        initialValue: diaColab,
                        decoration: const InputDecoration(
                          labelText: 'Dia Abertura (Geral)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
                        ),
                        items: _diasSemanaItems,
                        onChanged: onDiaColabChanged,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.schedule_rounded, color: Color(0xFF2563EB), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Abertura da Próxima Semana & Cotas',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: limiteSemanalController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Limite Máximo de Reservas Semanais por Colaborador',
                              hintText: '2',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.event_seat_rounded, size: 20),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (isMobile) ...[
                            dropDiaGestao,
                            const SizedBox(height: 12),
                            inputHorarioGestao,
                          ] else ...[
                            Row(
                              children: [
                                Expanded(child: dropDiaGestao),
                                const SizedBox(width: 12),
                                Expanded(child: inputHorarioGestao),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (isMobile) ...[
                            dropDiaColab,
                            const SizedBox(height: 12),
                            inputHorarioColab,
                          ] else ...[
                            Row(
                              children: [
                                Expanded(child: dropDiaColab),
                                const SizedBox(width: 12),
                                Expanded(child: inputHorarioColab),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. CARD: POLÍTICAS DE CHECK-IN E REGRAS OPERACIONAIS
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(
                    builder: (context, chkConstraints) {
                      final isMobile = chkConstraints.maxWidth < 620;

                      final inputHorarioInicio = TextFormField(
                        controller: horarioInicioCheckinController,
                        decoration: const InputDecoration(
                          labelText: 'Início do Check-in Diário',
                          hintText: '06:00',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.login_rounded, size: 20),
                        ),
                      );

                      final inputHorarioLimite = TextFormField(
                        controller: horarioCheckinController,
                        decoration: const InputDecoration(
                          labelText: 'Horário Limite / Corte (No-Show)',
                          hintText: '11:00',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.alarm_off_rounded, size: 20),
                        ),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.rule_rounded, color: Color(0xFF2563EB), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Políticas de Check-in e Regras de Reserva',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (isMobile) ...[
                            inputHorarioInicio,
                            const SizedBox(height: 12),
                            inputHorarioLimite,
                          ] else ...[
                            Row(
                              children: [
                                Expanded(child: inputHorarioInicio),
                                const SizedBox(width: 12),
                                Expanded(child: inputHorarioLimite),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Switches de Políticas
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Permitir Troca de Assento no Mesmo Dia', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: const Text('Permite ao colaborador trocar de mesa diretamente para uma mesma data já reservada.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            value: permitirTroca,
                            activeThumbColor: const Color(0xFF2563EB),
                            onChanged: onPermitirTrocaChanged,
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Check-in Automático para Gestão', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: const Text('Marca a presença como confirmada automaticamente no momento da reserva para usuários GESTAO.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            value: checkinAutoGestao,
                            activeThumbColor: const Color(0xFF2563EB),
                            onChanged: onCheckinAutoGestaoChanged,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. CARD: COMUNICAÇÃO & AVISO GLOBAL DO RH
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.campaign_rounded, color: Color(0xFFD97706), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Aviso Global / Comunicado do RH',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Deixe em branco para ocultar o banner. Quando preenchido, será exibido no topo do app para todos os colaboradores.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: avisoGlobalController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Atenção: Na próxima sexta-feira haverá evento corporativo no escritório Berrini.',
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
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Salvar Parâmetros e Políticas', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: onSalvarParametros,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 4. CARD: AÇÕES OPERACIONAIS DE EMERGÊNCIA
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.cleaning_services_rounded, color: Color(0xFFEA580C), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Ações Operacionais de Emergência',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Dispare manualmente a rotina de limpeza de No-Show para cancelar imediatamente reservas sem presença confirmada de hoje.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                        label: const Text('Executar Limpeza de No-Show Agora'),
                        onPressed: onExecutarLimpezaNoShow,
                      ),
                    ],
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

