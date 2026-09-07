import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../utils/file_saver_helper.dart';

class TabRelatorios extends StatefulWidget {
  final List<dynamic> departamentos;
  final List<dynamic> escritorios;

  const TabRelatorios({
    super.key,
    this.departamentos = const [],
    this.escritorios = const [],
  });

  @override
  State<TabRelatorios> createState() => _TabRelatoriosState();
}

class _TabRelatoriosState extends State<TabRelatorios> {
  final ApiService _apiService = ApiService();

  DateTime _dataInicio = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _dataFim = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  String _filtroEscritorio = 'todos';
  String _filtroDepartamento = 'todos';
  String _filtroCheckinStatus = 'todos';
  final String _filtroStatus = 'todos';
  final TextEditingController _buscaController = TextEditingController();

  bool _isLoading = false;
  bool _isExportingXlsx = false;
  bool _isExportingPdf = false;

  Map<String, dynamic>? _analyticsData;
  List<dynamic> _registros = [];
  int _totalRegistros = 0;
  int _currentPage = 1;
  int _totalPages = 1;
  final int _limit = 25;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarDadosCompletos();
    });
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  String get _dataInicioIso => DateFormat('yyyy-MM-dd').format(_dataInicio);
  String get _dataFimIso => DateFormat('yyyy-MM-dd').format(_dataFim);

  void _selecionarPreset(String preset) {
    final hoje = DateTime.now();
    setState(() {
      if (preset == 'hoje') {
        _dataInicio = hoje;
        _dataFim = hoje;
      } else if (preset == 'semana') {
        // Segunda-feira desta semana até hoje/sexta
        final diff = hoje.weekday - 1;
        _dataInicio = hoje.subtract(Duration(days: diff));
        _dataFim = hoje.add(Duration(days: 6 - diff));
      } else if (preset == 'mes_atual') {
        _dataInicio = DateTime(hoje.year, hoje.month, 1);
        _dataFim = DateTime(hoje.year, hoje.month + 1, 0);
      } else if (preset == 'mes_anterior') {
        _dataInicio = DateTime(hoje.year, hoje.month - 1, 1);
        _dataFim = DateTime(hoje.year, hoje.month, 0);
      }
      _currentPage = 1;
    });
    _carregarDadosCompletos();
  }

  Future<void> _carregarDadosCompletos({int? page}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    final targetPage = page ?? _currentPage;

    setState(() => _isLoading = true);

    try {
      final analyticsFuture = _apiService.getRelatoriosAnalytics(
        auth.token!,
        auth.adminToken ?? auth.token!,
        dataInicio: _dataInicioIso,
        dataFim: _dataFimIso,
        escritorioId: _filtroEscritorio,
        departamentoId: _filtroDepartamento,
        status: _filtroStatus,
        checkinStatus: _filtroCheckinStatus,
        busca: _buscaController.text.trim(),
      );

      final dadosFuture = _apiService.getRelatoriosDados(
        auth.token!,
        auth.adminToken ?? auth.token!,
        dataInicio: _dataInicioIso,
        dataFim: _dataFimIso,
        escritorioId: _filtroEscritorio,
        departamentoId: _filtroDepartamento,
        status: _filtroStatus,
        checkinStatus: _filtroCheckinStatus,
        busca: _buscaController.text.trim(),
        page: targetPage,
        limit: _limit,
      );

      final results = await Future.wait([analyticsFuture, dadosFuture]);
      final analyticsRes = results[0];
      final dadosRes = results[1];

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (analyticsRes.success && analyticsRes.data != null) {
            _analyticsData = analyticsRes.data;
          }
          if (dadosRes.success && dadosRes.data != null) {
            _registros = dadosRes.data!['registros'] as List? ?? [];
            _totalRegistros = dadosRes.data!['total'] as int? ?? 0;
            _currentPage = dadosRes.data!['page'] as int? ?? 1;
            _totalPages = dadosRes.data!['totalPages'] as int? ?? 1;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar relatórios: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportarExcel() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    setState(() => _isExportingXlsx = true);

    final res = await _apiService.downloadRelatorioXlsx(
      auth.token!,
      auth.adminToken ?? auth.token!,
      dataInicio: _dataInicioIso,
      dataFim: _dataFimIso,
      escritorioId: _filtroEscritorio,
      departamentoId: _filtroDepartamento,
      status: _filtroStatus,
      checkinStatus: _filtroCheckinStatus,
      busca: _buscaController.text.trim(),
    );

    if (mounted) {
      setState(() => _isExportingXlsx = false);
      if (res.success && res.data != null) {
        final nome = 'Relatorio_Reservas_${_dataInicioIso}_a_$_dataFimIso.xlsx';
        final salvoEm = await FileSaverHelper.salvarArquivo(bytes: res.data!, nomeArquivo: nome);
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text(salvoEm != null ? 'Excel salvo em Downloads: $nome' : 'Planilha gerada com sucesso!'),
              backgroundColor: const Color(0xFF16A34A),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              action: (salvoEm != null && !salvoEm.contains('Navegador'))
                  ? SnackBarAction(
                      label: 'Abrir Pasta',
                      textColor: Colors.white,
                      onPressed: () => FileSaverHelper.abrirArquivoOuPasta(salvoEm),
                    )
                  : null,
            ),
          );
        }
      } else {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(res.error ?? 'Erro ao exportar Excel.'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportarPdf() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    setState(() => _isExportingPdf = true);

    final res = await _apiService.downloadRelatorioPdf(
      auth.token!,
      auth.adminToken ?? auth.token!,
      dataInicio: _dataInicioIso,
      dataFim: _dataFimIso,
      escritorioId: _filtroEscritorio,
      departamentoId: _filtroDepartamento,
      status: _filtroStatus,
      checkinStatus: _filtroCheckinStatus,
      busca: _buscaController.text.trim(),
    );

    if (mounted) {
      setState(() => _isExportingPdf = false);
      if (res.success && res.data != null) {
        final nome = 'Relatorio_Reservas_${_dataInicioIso}_a_$_dataFimIso.pdf';
        final salvoEm = await FileSaverHelper.salvarArquivo(bytes: res.data!, nomeArquivo: nome);
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text(salvoEm != null ? 'PDF salvo em Downloads: $nome' : 'PDF gerado com sucesso!'),
              backgroundColor: const Color(0xFF16A34A),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              action: (salvoEm != null && !salvoEm.contains('Navegador'))
                  ? SnackBarAction(
                      label: 'Abrir Pasta',
                      textColor: Colors.white,
                      onPressed: () => FileSaverHelper.abrirArquivoOuPasta(salvoEm),
                    )
                  : null,
            ),
          );
        }
      } else {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(res.error ?? 'Erro ao exportar PDF.'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kpis = _analyticsData?['kpis'] as Map<String, dynamic>?;
    final totalReservas = kpis?['totalReservas'] ?? _totalRegistros;
    final totalCheckins = kpis?['totalCheckins'] ?? 0;
    final totalNoShows = kpis?['totalNoShows'] ?? 0;
    final totalCanceladas = kpis?['totalCanceladas'] ?? 0;
    final taxaPresenca = kpis?['taxaPresenca'] ?? (totalReservas > 0 ? ((totalCheckins / totalReservas) * 100).toStringAsFixed(1) : 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. CABEÇALHO & ATALHOS DE PERÍODO
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics_rounded, color: Color(0xFF2563EB), size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Central de Relatórios & BI de Frequência',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const Spacer(),
                      // Botões de Exportação
                      Wrap(
                        spacing: 8,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: _isExportingXlsx
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.table_view_rounded, size: 16),
                            label: Text(_isExportingXlsx ? 'Gerando...' : 'Exportar Excel (.xlsx)', style: const TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _isExportingXlsx ? null : _exportarExcel,
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: _isExportingPdf
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.picture_as_pdf_rounded, size: 16),
                            label: Text(_isExportingPdf ? 'Gerando...' : 'Exportar PDF (.pdf)', style: const TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _isExportingPdf ? null : _exportarPdf,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Atalhos rápidos de data
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Atalhos de Período:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      _buildPresetChip('Hoje', 'hoje'),
                      _buildPresetChip('Esta Semana', 'semana'),
                      _buildPresetChip('Este Mês', 'mes_atual'),
                      _buildPresetChip('Mês Anterior', 'mes_anterior'),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range_rounded, size: 16),
                        label: Text(
                          '${DateFormat("dd/MM/yyyy").format(_dataInicio)} até ${DateFormat("dd/MM/yyyy").format(_dataFim)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                            initialDateRange: DateTimeRange(start: _dataInicio, end: _dataFim),
                            locale: const Locale('pt', 'BR'),
                            helpText: 'Selecione o Período do Relatório',
                            cancelText: 'Cancelar',
                            confirmText: 'Aplicar',
                            saveText: 'Aplicar',
                          );
                          if (picked != null) {
                            setState(() {
                              _dataInicio = picked.start;
                              _dataFim = picked.end;
                              _currentPage = 1;
                            });
                            _carregarDadosCompletos();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 2. FILTROS AVANÇADOS
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filtros Multifatoriais', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 750;
                      return isMobile
                          ? Column(
                              children: [
                                _buildFiltroEscritorio(),
                                const SizedBox(height: 8),
                                _buildFiltroDepartamento(),
                                const SizedBox(height: 8),
                                _buildFiltroPresenca(),
                                const SizedBox(height: 8),
                                _buildCampoBusca(),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: _buildFiltroEscritorio()),
                                const SizedBox(width: 8),
                                Expanded(child: _buildFiltroDepartamento()),
                                const SizedBox(width: 8),
                                Expanded(child: _buildFiltroPresenca()),
                                const SizedBox(width: 8),
                                Expanded(flex: 2, child: _buildCampoBusca()),
                              ],
                            );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 3. CARDS DE KPIS
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              final width = isMobile ? (constraints.maxWidth - 8) / 2 : (constraints.maxWidth - 36) / 4;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildKpiCard(
                    width: width,
                    titulo: 'TOTAL DE RESERVAS',
                    valor: '$totalReservas',
                    subtitulo: 'No período selecionado',
                    icone: Icons.event_seat_rounded,
                    cor: const Color(0xFF2563EB),
                    bgCor: const Color(0xFFEFF6FF),
                  ),
                  _buildKpiCard(
                    width: width,
                    titulo: 'PRESENÇAS CONFIRMADAS',
                    valor: '$totalCheckins',
                    subtitulo: '$taxaPresenca% de aderência',
                    icone: Icons.check_circle_rounded,
                    cor: const Color(0xFF16A34A),
                    bgCor: const Color(0xFFF0FDF4),
                  ),
                  _buildKpiCard(
                    width: width,
                    titulo: 'NÃO COMPARECEU (NO-SHOW)',
                    valor: '$totalNoShows',
                    subtitulo: 'Assentos sem check-in',
                    icone: Icons.alarm_off_rounded,
                    cor: const Color(0xFFDC2626),
                    bgCor: const Color(0xFFFEF2F2),
                  ),
                  _buildKpiCard(
                    width: width,
                    titulo: 'CANCELAMENTOS',
                    valor: '$totalCanceladas',
                    subtitulo: 'Liberadas antes do corte',
                    icone: Icons.cancel_outlined,
                    cor: const Color(0xFF475569),
                    bgCor: const Color(0xFFF8FAFC),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // 4. TABELA ANALÍTICA DE REGISTROS
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.table_rows_rounded, color: Color(0xFF334155), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Detalhamento de Registros ($_totalRegistros no total)',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      if (_isLoading)
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tabela de Dados
                  _registros.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: const Text('Nenhum registro encontrado para os filtros selecionados.', style: TextStyle(color: Color(0xFF64748B))),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 900),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                              columnSpacing: 18,
                              horizontalMargin: 12,
                              columns: const [
                                DataColumn(label: Text('Data', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Matrícula', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Colaborador', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Departamento', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Escritório', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Mesa', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Situação / Presença', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Horário Check-in', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Comprovante', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _registros.map((item) {
                                final usuario = item['usuario'] as Map<String, dynamic>? ?? {};
                                final escritorio = item['escritorio'] as Map<String, dynamic>? ?? {};
                                final assento = item['assento'] as Map<String, dynamic>? ?? {};
                                final situacao = item['situacaoPresenca'] as String? ?? 'Pendente';
                                final dataIso = item['dataReserva'] as String? ?? '';
                                final checkinEm = item['checkinEm'] as String?;

                                String dataFormatada = dataIso;
                                try {
                                  final dt = DateTime.parse(dataIso);
                                  dataFormatada = DateFormat('dd/MM/yyyy').format(dt);
                                } catch (_) {}

                                String horaCheckinFormatada = '-';
                                if (checkinEm != null) {
                                  try {
                                    final dt = DateTime.parse(checkinEm);
                                    horaCheckinFormatada = DateFormat('HH:mm:ss').format(dt.toLocal());
                                  } catch (_) {}
                                }

                                Color statusBg = const Color(0xFFF1F5F9);
                                Color statusFg = const Color(0xFF475569);

                                if (situacao.contains('Confirmada')) {
                                  statusBg = const Color(0xFFDCFCE7);
                                  statusFg = const Color(0xFF15803D);
                                } else if (situacao.contains('No-Show') || situacao == 'Cancelada') {
                                  statusBg = const Color(0xFFFEE2E2);
                                  statusFg = const Color(0xFFB91C1C);
                                }

                                return DataRow(
                                  cells: [
                                    DataCell(Text(dataFormatada, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                                    DataCell(Text(usuario['matricula']?.toString() ?? '-', style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                                    DataCell(
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(usuario['nome']?.toString() ?? '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          Text(usuario['email']?.toString() ?? '', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(usuario['departamento']?.toString() ?? '-', style: const TextStyle(fontSize: 12))),
                                    DataCell(Text(escritorio['nome']?.toString() ?? '-', style: const TextStyle(fontSize: 12))),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                        child: Text(assento['identificador']?.toString() ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                                        child: Text(situacao, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusFg)),
                                      ),
                                    ),
                                    DataCell(Text(horaCheckinFormatada, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
                                    DataCell(Text(item['codigoComprovante']?.toString() ?? '-', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF64748B)))),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),

                  const SizedBox(height: 12),

                  // Paginação
                  if (_totalPages > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Página $_currentPage de $_totalPages', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded),
                              onPressed: _currentPage > 1 ? () => _carregarDadosCompletos(page: _currentPage - 1) : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded),
                              onPressed: _currentPage < _totalPages ? () => _carregarDadosCompletos(page: _currentPage + 1) : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, String presetKey) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: const Color(0xFFF1F5F9),
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onPressed: () => _selecionarPreset(presetKey),
    );
  }

  Widget _buildFiltroEscritorio() {
    return DropdownButtonFormField<String>(
      initialValue: _filtroEscritorio,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Escritório', border: OutlineInputBorder(), isDense: true),
      items: [
        const DropdownMenuItem(value: 'todos', child: Text('Todos Escritórios')),
        ...widget.escritorios.map((e) {
          final id = (e is Map) ? (e['id']?.toString() ?? '') : e.id.toString();
          final nome = (e is Map) ? (e['nome']?.toString() ?? 'Escritório') : e.nome.toString();
          return DropdownMenuItem(
            value: id,
            child: Text(nome),
          );
        }),
      ],
      onChanged: (v) {
        setState(() {
          _filtroEscritorio = v ?? 'todos';
          _currentPage = 1;
        });
        _carregarDadosCompletos();
      },
    );
  }

  Widget _buildFiltroDepartamento() {
    return DropdownButtonFormField<String>(
      initialValue: _filtroDepartamento,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Departamento', border: OutlineInputBorder(), isDense: true),
      items: [
        const DropdownMenuItem(value: 'todos', child: Text('Todos Departamentos')),
        ...widget.departamentos.map((d) => DropdownMenuItem(
              value: d.id.toString(),
              child: Text(d.nome),
            )),
      ],
      onChanged: (v) {
        setState(() {
          _filtroDepartamento = v ?? 'todos';
          _currentPage = 1;
        });
        _carregarDadosCompletos();
      },
    );
  }

  Widget _buildFiltroPresenca() {
    return DropdownButtonFormField<String>(
      initialValue: _filtroCheckinStatus,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Situação / Check-in', border: OutlineInputBorder(), isDense: true),
      items: const [
        DropdownMenuItem(value: 'todos', child: Text('Todas Situações')),
        DropdownMenuItem(value: 'confirmado', child: Text('Presença Confirmada')),
        DropdownMenuItem(value: 'pendente', child: Text('Check-in Pendente')),
        DropdownMenuItem(value: 'noshow', child: Text('Não Compareceu (No-Show)')),
      ],
      onChanged: (v) {
        setState(() {
          _filtroCheckinStatus = v ?? 'todos';
          _currentPage = 1;
        });
        _carregarDadosCompletos();
      },
    );
  }

  Widget _buildCampoBusca() {
    return TextField(
      controller: _buscaController,
      decoration: InputDecoration(
        labelText: 'Buscar colaborador, matrícula ou mesa',
        border: const OutlineInputBorder(),
        isDense: true,
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        suffixIcon: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          onPressed: () {
            setState(() => _currentPage = 1);
            _carregarDadosCompletos();
          },
        ),
      ),
      onSubmitted: (_) {
        setState(() => _currentPage = 1);
        _carregarDadosCompletos();
      },
    );
  }

  Widget _buildKpiCard({
    required double width,
    required String titulo,
    required String valor,
    required String subtitulo,
    required IconData icone,
    required Color cor,
    required Color bgCor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgCor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(titulo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cor), overflow: TextOverflow.ellipsis)),
              Icon(icone, size: 18, color: cor),
            ],
          ),
          const SizedBox(height: 8),
          Text(valor, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cor)),
          const SizedBox(height: 2),
          Text(subtitulo, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}
