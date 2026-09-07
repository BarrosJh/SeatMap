import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/seat_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/seat_map_provider.dart';
import '../../../services/api_service.dart';

class SeatMaintenanceDialog {
  static void show({
    required BuildContext context,
    required CadeiraModel cadeira,
    required UserModel currentUser,
    required String token,
  }) {
    final isTechAdmin = currentUser.isAdmin || currentUser.permissaoTi || currentUser.isGestao;

    showDialog(
      context: context,
      builder: (ctx) {
        return _SeatMaintenanceModal(
          cadeira: cadeira,
          currentUser: currentUser,
          isTechAdmin: isTechAdmin,
          token: token,
        );
      },
    );
  }
}

class _SeatMaintenanceModal extends StatefulWidget {
  final CadeiraModel cadeira;
  final UserModel currentUser;
  final bool isTechAdmin;
  final String token;

  const _SeatMaintenanceModal({
    required this.cadeira,
    required this.currentUser,
    required this.isTechAdmin,
    required this.token,
  });

  @override
  State<_SeatMaintenanceModal> createState() => _SeatMaintenanceModalState();
}

class _SeatMaintenanceModalState extends State<_SeatMaintenanceModal> {
  final _motivoController = TextEditingController();
  DateTime? _previsaoRetorno;
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _motivoController.text = widget.cadeira.motivoManutencao ?? '';
    if (widget.cadeira.previsaoRetorno != null) {
      _previsaoRetorno = DateTime.tryParse(widget.cadeira.previsaoRetorno!);
    }
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _colocarEmManutencao() async {
    final motivo = _motivoController.text.trim();
    if (motivo.isEmpty) {
      setState(() => _error = 'Informe o motivo da manutenção.');
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    final res = await ApiService().colocarCadeiraEmManutencao(
      widget.token,
      auth.adminToken,
      widget.cadeira.id,
      motivo: motivo,
      previsaoRetorno: _previsaoRetorno?.toIso8601String(),
    );

    if (!mounted) return;

    setState(() => _isProcessing = false);

    if (res.success) {
      await seatProvider.carregarMapa(widget.token);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Mesa ${widget.cadeira.identificador} colocada em manutenção.'),
          backgroundColor: const Color(0xFFD97706),
        ),
      );
    } else {
      setState(() => _error = res.error ?? 'Falha ao colocar em manutenção.');
    }
  }

  Future<void> _liberarManutencao() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    final res = await ApiService().liberarCadeiraManutencao(
      widget.token,
      auth.adminToken,
      widget.cadeira.id,
    );

    if (!mounted) return;

    setState(() => _isProcessing = false);

    if (res.success) {
      await seatProvider.carregarMapa(widget.token);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Mesa ${widget.cadeira.identificador} liberada com sucesso.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } else {
      setState(() => _error = res.error ?? 'Falha ao liberar mesa.');
    }
  }


  @override
  Widget build(BuildContext context) {
    final isManut = widget.cadeira.isManutencao;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    backgroundColor: isManut ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE),
                    radius: 24,
                    child: Icon(
                      isManut ? Icons.build_rounded : Icons.event_seat_rounded,
                      color: isManut ? const Color(0xFFD97706) : const Color(0xFF0284C7),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mesa ${widget.cadeira.identificador}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          isManut ? 'Bloqueada para Manutenção' : 'Status Operacional Normal',
                          style: TextStyle(
                            fontSize: 13,
                            color: isManut ? const Color(0xFFB45309) : const Color(0xFF059669),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 12),

              if (isManut && !widget.isTechAdmin) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.handyman_rounded, color: Color(0xFFD97706), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Assento Temporariamente Indisponível',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Motivo: ${widget.cadeira.motivoManutencao ?? "Manutenção preventiva de infraestrutura / Facilities"}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF78350F)),
                      ),
                      if (widget.cadeira.previsaoRetorno != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Previsão de retorno: ${DateFormat("dd/MM/yyyy 'às' HH:mm").format(DateTime.parse(widget.cadeira.previsaoRetorno!))}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendido'),
                  ),
                ),
              ] else if (widget.isTechAdmin) ...[
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                  ),

                if (!isManut) ...[
                  const Text(
                    'Bloquear assento para manutenção (Facilities / TI):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _motivoController,
                    decoration: const InputDecoration(
                      labelText: 'Motivo da Manutenção *',
                      hintText: 'Ex: Tomada sem energia, monitor quebrado, cadeira com defeito',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _previsaoRetorno == null
                              ? 'Sem previsão de liberação'
                              : 'Previsão: ${DateFormat("dd/MM/yyyy HH:mm").format(_previsaoRetorno!)}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: const Text('Definir Previsão'),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 60)),
                          );
                          if (date != null && context.mounted) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: const TimeOfDay(hour: 18, minute: 0),
                            );
                            if (time != null && mounted) {
                              setState(() {
                                _previsaoRetorno = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          }

                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _isProcessing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.block_rounded, size: 18),
                      label: const Text('Bloquear Assento'),
                      onPressed: _isProcessing ? null : _colocarEmManutencao,
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Motivo Atual: ${widget.cadeira.motivoManutencao ?? "Manutenção técnica"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                        ),
                        if (widget.cadeira.previsaoRetorno != null)
                          Text(
                            'Previsão: ${DateFormat("dd/MM/yyyy HH:mm").format(DateTime.parse(widget.cadeira.previsaoRetorno!))}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _isProcessing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: const Text('Liberar Cadeira'),
                      onPressed: _isProcessing ? null : _liberarManutencao,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
