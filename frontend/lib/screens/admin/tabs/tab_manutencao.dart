import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/admin_models.dart';
import '../../../models/seat_model.dart';
import '../../../services/api_service.dart';

class TabManutencao extends StatefulWidget {
  final String token;
  final String? adminToken;
  final List<EscritorioModel> escritorios;

  const TabManutencao({
    super.key,
    required this.token,
    this.adminToken,
    required this.escritorios,
  });

  @override
  State<TabManutencao> createState() => _TabManutencaoState();
}

class _TabManutencaoState extends State<TabManutencao> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  String _filtroEscritorio = 'todos';
  AdminManutencaoKpisModel _kpis = AdminManutencaoKpisModel(totalBloqueadas: 0, totalOperacionais: 0, totalAtrasadas: 0);
  List<AdminManutencaoModel> _manutencoes = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);

    final res = await _apiService.getCadeirasManutencao(
      widget.token,
      widget.adminToken,
      escritorioId: _filtroEscritorio,
      busca: _searchController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          _kpis = res.data!['kpis'] as AdminManutencaoKpisModel;
          _manutencoes = res.data!['manutencoes'] as List<AdminManutencaoModel>;
        }
      });
    }
  }

  Future<void> _liberarCadeira(AdminManutencaoModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A)),
            const SizedBox(width: 8),
            Text('Liberar Mesa ${item.identificador}'),
          ],
        ),
        content: Text(
          'Deseja restaurar a Mesa ${item.identificador} (${item.baiaNome} - ${item.escritorioNome}) para o status operacional Disponível?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar Liberação'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final res = await _apiService.liberarCadeiraManutencao(
        widget.token,
        widget.adminToken,
        item.id,
      );

      if (mounted) {
        if (res.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message ?? 'Mesa ${item.identificador} liberada para uso geral.'),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
          _carregarDados();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.error ?? 'Falha ao liberar cadeira.'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }
  }

  void _abrirModalBloqueio() async {
    showDialog(
      context: context,
      builder: (ctx) => _ModalNovoBloqueioManutencao(
        token: widget.token,
        adminToken: widget.adminToken,
        escritorios: widget.escritorios,
        onSucesso: () {
          _carregarDados();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _carregarDados,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. CARDS DE KPI & INDICADORES
            _buildKpisSection(),
            const SizedBox(height: 24),

            // 2. BARRA DE FERRAMENTAS & FILTROS
            _buildToolbarSection(),
            const SizedBox(height: 20),

            // 3. TABELA / LISTA DE ASSENTOS EM MANUTENÇÃO
            _buildTabelaSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildKpisSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildKpiCard(
              title: 'Assentos em Manutenção',
              value: '${_kpis.totalBloqueadas}',
              subtitle: 'Cadeiras bloqueadas por defeito',
              icon: Icons.build_rounded,
              color: const Color(0xFFD97706),
              bgColor: const Color(0xFFFFFBEB),
              width: isMobile ? double.infinity : (constraints.maxWidth - 32) / 3,
            ),
            _buildKpiCard(
              title: 'Assentos Operacionais',
              value: '${_kpis.totalOperacionais}',
              subtitle: 'Cadeiras liberadas para reserva',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF16A34A),
              bgColor: const Color(0xFFF0FDF4),
              width: isMobile ? double.infinity : (constraints.maxWidth - 32) / 3,
            ),
            _buildKpiCard(
              title: 'Previsões Atrasadas',
              value: '${_kpis.totalAtrasadas}',
              subtitle: 'Prazo de conclusão expirado',
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFDC2626),
              bgColor: const Color(0xFFFEF2F2),
              width: isMobile ? double.infinity : (constraints.maxWidth - 32) / 3,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWrap = constraints.maxWidth < 800;

          final filtroDropdown = SizedBox(
            width: isWrap ? double.infinity : 220,
            child: DropdownButtonFormField<String>(
              initialValue: _filtroEscritorio,
              decoration: const InputDecoration(
                labelText: 'Escritório',
                prefixIcon: Icon(Icons.business, size: 20),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: 'todos', child: Text('Todos Escritórios')),
                ...widget.escritorios.map((e) => DropdownMenuItem(value: e.id.toString(), child: Text(e.nome))),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _filtroEscritorio = val);
                  _carregarDados();
                }
              },
            ),
          );

          final searchInput = SizedBox(
            width: isWrap ? double.infinity : 320,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar mesa, baia, motivo...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: const OutlineInputBorder(),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _carregarDados();
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) => _carregarDados(),
            ),
          );

          final btnNovo = ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('Bloquear Assento para Manutenção', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _abrirModalBloqueio,
          );

          if (isWrap) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                filtroDropdown,
                const SizedBox(height: 12),
                searchInput,
                const SizedBox(height: 12),
                btnNovo,
              ],
            );
          }

          return Row(
            children: [
              filtroDropdown,
              const SizedBox(width: 14),
              searchInput,
              const Spacer(),
              btnNovo,
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabelaSection() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_manutencoes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF0FDF4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhum assento em manutenção no momento!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Todos os postos de trabalho estão 100% operacionais para reservas.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            horizontalMargin: 20,
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('Mesa', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Localização', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Motivo da Avaria', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Data do Bloqueio', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Previsão de Retorno', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Responsável', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _manutencoes.map((item) {
              final isAtrasada = item.isAtrasada;

              String dataBloqueioStr = 'N/A';
              if (item.dataBloqueio != null) {
                final dt = DateTime.tryParse(item.dataBloqueio!);
                if (dt != null) {
                  dataBloqueioStr = DateFormat('dd/MM/yyyy HH:mm').format(dt);
                }
              }

              String previsaoStr = 'Sem previsão';
              if (item.previsaoRetorno != null) {
                final dt = DateTime.tryParse(item.previsaoRetorno!);
                if (dt != null) {
                  previsaoStr = DateFormat('dd/MM/yyyy HH:mm').format(dt);
                }
              }

              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.build_rounded, size: 14, color: Color(0xFFD97706)),
                          const SizedBox(width: 6),
                          Text(
                            'Mesa ${item.identificador}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.escritorioNome,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          item.baiaNome,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Text(
                        item.motivoManutencao ?? 'Defeito técnico / Facilities',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(dataBloqueioStr, style: const TextStyle(fontSize: 12))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isAtrasada ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isAtrasada ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        isAtrasada ? 'Atrasada: $previsaoStr' : previsaoStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isAtrasada ? const Color(0xFFDC2626) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      item.responsavelNome ?? 'TI / Facilities',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ),
                  DataCell(
                    Tooltip(
                      message: 'Liberar Assento',
                      child: IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A)),
                        onPressed: () => _liberarCadeira(item),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _ModalNovoBloqueioManutencao extends StatefulWidget {
  final String token;
  final String? adminToken;
  final List<EscritorioModel> escritorios;
  final VoidCallback onSucesso;

  const _ModalNovoBloqueioManutencao({
    required this.token,
    this.adminToken,
    required this.escritorios,
    required this.onSucesso,
  });

  @override
  State<_ModalNovoBloqueioManutencao> createState() => _ModalNovoBloqueioManutencaoState();
}

class _ModalNovoBloqueioManutencaoState extends State<_ModalNovoBloqueioManutencao> {
  final ApiService _apiService = ApiService();
  final _motivoController = TextEditingController();

  bool _isLoadingCadeiras = true;
  bool _isSaving = false;
  String? _error;

  List<AdminCadeiraOptionModel> _todasCadeiras = [];
  int? _selectedEscritorioId;
  int? _selectedCadeiraId;
  DateTime? _previsaoRetorno;

  @override
  void initState() {
    super.initState();
    if (widget.escritorios.isNotEmpty) {
      _selectedEscritorioId = widget.escritorios.first.id;
    }
    _carregarCadeiras();
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _carregarCadeiras() async {
    setState(() => _isLoadingCadeiras = true);
    final res = await _apiService.getTodasCadeiras(
      widget.token,
      widget.adminToken,
      escritorioId: _selectedEscritorioId?.toString(),
    );

    if (mounted) {
      setState(() {
        _isLoadingCadeiras = false;
        if (res.success && res.data != null) {
          _todasCadeiras = res.data!;
          final disponiveis = _todasCadeiras.where((c) => !c.isEmManutencao).toList();
          _selectedCadeiraId = disponiveis.isNotEmpty ? disponiveis.first.id : null;
        }
      });
    }
  }

  Future<void> _salvarBloqueio() async {
    final motivo = _motivoController.text.trim();
    if (_selectedCadeiraId == null) {
      setState(() => _error = 'Selecione uma mesa física.');
      return;
    }

    if (motivo.isEmpty) {
      setState(() => _error = 'Informe o motivo detalhado da avaria/manutenção.');
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final res = await _apiService.colocarCadeiraEmManutencao(
      widget.token,
      widget.adminToken,
      _selectedCadeiraId!,
      motivo: motivo,
      previsaoRetorno: _previsaoRetorno?.toIso8601String(),
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (res.success) {
      widget.onSucesso();
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Assento colocado em manutenção com sucesso.'),
          backgroundColor: const Color(0xFFD97706),
        ),
      );
    } else {
      setState(() => _error = res.error ?? 'Falha ao colocar assento em manutenção.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cadeirasDisponiveis = _todasCadeiras.where((c) => !c.isEmManutencao).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.build_rounded, color: Color(0xFFD97706), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bloquear Assento para Manutenção', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('Facilities, Infraestrutura e Defeitos Físicos', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 14),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                ),

              // Seletor de Escritório
              DropdownButtonFormField<int>(
                initialValue: _selectedEscritorioId,
                decoration: const InputDecoration(
                  labelText: '1. Selecione o Escritório',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: widget.escritorios.map((e) => DropdownMenuItem(value: e.id, child: Text('${e.nome} (${e.cidade})'))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedEscritorioId = val);
                    _carregarCadeiras();
                  }
                },
              ),
              const SizedBox(height: 14),

              // Seletor de Cadeira
              _isLoadingCadeiras
                  ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  : DropdownButtonFormField<int>(
                      initialValue: _selectedCadeiraId,
                      decoration: const InputDecoration(
                        labelText: '2. Selecione a Mesa Física',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: cadeirasDisponiveis.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text('Mesa ${c.identificador} — ${c.baiaNome}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedCadeiraId = val);
                      },
                    ),
              const SizedBox(height: 14),

              // Motivo
              TextField(
                controller: _motivoController,
                decoration: const InputDecoration(
                  labelText: '3. Motivo da Avaria / Reparo *',
                  hintText: 'Ex: Tomada sem energia, monitor com defeito, cadeira danificada',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 14),

              // Previsão de Retorno
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _previsaoRetorno == null
                          ? 'Previsão de Liberação: Não definida'
                          : 'Previsão: ${DateFormat("dd/MM/yyyy 'às' HH:mm").format(_previsaoRetorno!)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Definir Prazo'),
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
              const SizedBox(height: 14),

              // Alerta Preventivo
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reservas futuras ativas nesta cadeira serão canceladas automaticamente e os colaboradores notificados por e-mail.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Ações
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isSaving ? null : _salvarBloqueio,
                    child: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Confirmar Bloqueio'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
