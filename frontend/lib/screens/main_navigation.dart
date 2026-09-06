import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/seat_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/seat_map_provider.dart';
import 'home_dashboard_screen.dart';
import 'login_screen.dart';
import 'mapa_screen.dart';
import 'checkin_screen.dart';
import 'minhas_reservas_screen.dart';
import 'admin_panel_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0; // 0 = Início, 1 = Mapa, 2 = Check-in, 3 = Minhas Reservas, 4 = Admin
  bool _mapaExpanded = true;
  bool _reservasExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
      if (auth.token != null && auth.user != null) {
        seatProvider.carregarInicial(auth.token!, auth.user!);
      }
    });
  }

  void _onTabSelected(int index, bool isAdmin) {
    setState(() => _currentIndex = index);
  }

  void _selecionarEscritorio(String nomeEscritorio) {
    setState(() => _currentIndex = 1);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
    if (auth.token != null) {
      seatProvider.selecionarEscritorioPorNome(auth.token!, nomeEscritorio);
    }
  }

  void _navegarParaMapaComData(String nomeEscritorio, DateTime? data) {
    setState(() => _currentIndex = 1);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
    if (auth.token != null) {
      final match = seatProvider.escritorios.firstWhere(
        (e) => e.nome.toLowerCase().contains(nomeEscritorio.toLowerCase()),
        orElse: () => seatProvider.escritorios.isNotEmpty
            ? seatProvider.escritorios.first
            : EscritorioModel(id: 1, nome: nomeEscritorio, cidade: ''),
      );
      if (data != null) {
        seatProvider.selecionarEscritorioEData(auth.token!, match, data);
      } else {
        seatProvider.selecionarEscritorio(auth.token!, match);
      }
    }
  }

  void _selecionarFiltroReservas(ReservaFiltro filtro) {
    setState(() => _currentIndex = 3);
    final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
    seatProvider.setFiltroReservas(filtro);
  }



  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair do Sistema'),
        content: const Text('Deseja realmente encerrar sua sessão corporativa?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final navigator = Navigator.of(context);
              await auth.logout();
              if (mounted) {
                navigator.pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            child: const Text('Sair', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final isAdmin = user?.isAdmin ?? false;
    final seatProvider = Provider.of<SeatMapProvider>(context);
    final totalTabs = 4 + (isAdmin ? 1 : 0);
    final activeIndex = _currentIndex >= totalTabs ? 0 : _currentIndex;

    final List<Widget> screens = [
      HomeDashboardScreen(
        onNavegarParaCheckin: () => setState(() => _currentIndex = 2),
        onNavegarParaMinhasReservas: () => setState(() => _currentIndex = 3),
        onNavegarParaMapa: (nomeEscritorio, data) => _navegarParaMapaComData(nomeEscritorio, data),
      ),
      const MapaScreen(),
      CheckinScreen(
        isActive: activeIndex == 2,
        onNavegarParaMapa: () => setState(() => _currentIndex = 1),
      ),
      const MinhasReservasScreen(),
      if (isAdmin) const AdminPanelScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // 1. Sidebar Corporativa com Submenus
          _buildCorporateSidebar(context, user, isAdmin, activeIndex, seatProvider),

          // 2. Área Principal de Conteúdo
          Expanded(
            child: Column(
              children: [
                // Top Header Corporativo (oculto na Home e no Painel do RH que possuem banner azul/navy próprio)
                if (activeIndex != 0 && activeIndex != 4)
                  _buildCorporateTopBar(context, user, activeIndex, seatProvider),

                // Conteúdo da Tela
                Expanded(
                  child: IndexedStack(
                    index: activeIndex,
                    children: screens,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sidebar Corporativa Desktop com Submenus
  Widget _buildCorporateSidebar(
    BuildContext context,
    UserModel? user,
    bool isAdmin,
    int activeIndex,
    SeatMapProvider seatProvider,
  ) {
    final escSelecionadoNome = seatProvider.selectedEscritorio?.nome.toLowerCase() ?? '';
    final isBerriniAtivo = activeIndex == 1 && escSelecionadoNome.contains('berrini');
    final isBarueriAtivo = activeIndex == 1 && escSelecionadoNome.contains('barueri');
    final filtroAtual = seatProvider.filtroReservas;

    return Container(
      width: 270,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Deep Navy Slate Corporativo
        border: Border(
          right: BorderSide(color: Color(0xFF1E293B), width: 1.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header da Sidebar (Logo & Marca)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.domain_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SeatMap',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'WORKSPACE SUITE',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Text(
                      'PRINCIPAL',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  // 0. Menu Item: Início (Visão Geral)
                  _buildSidebarNavItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Início (Visão Geral)',
                    isActive: activeIndex == 0,
                    onTap: () => _onTabSelected(0, isAdmin),
                  ),

                  const SizedBox(height: 12),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Text(
                      'ESPAÇOS DE TRABALHO',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  // 1. Menu Pai: Mapa de Assentos
                  _buildParentMenuItem(
                    icon: Icons.map_rounded,
                    label: 'Mapa de Assentos',
                    isActive: activeIndex == 1,
                    isExpanded: _mapaExpanded,
                    onTap: () {
                      _onTabSelected(1, isAdmin);
                      setState(() => _mapaExpanded = !_mapaExpanded);
                    },
                    onExpandToggle: () => setState(() => _mapaExpanded = !_mapaExpanded),
                  ),

                  // Submenus de Escritórios
                  if (_mapaExpanded) ...[
                    _buildSubmenuItem(
                      icon: Icons.business_outlined,
                      label: 'Escritório Berrini',
                      badgeText: '102 Assentos',
                      badgeColor: const Color(0xFF38BDF8),
                      isActive: isBerriniAtivo,
                      onTap: () => _selecionarEscritorio('Berrini'),
                    ),
                    _buildSubmenuItem(
                      icon: Icons.apartment_outlined,
                      label: 'Escritório Barueri',
                      badgeText: '66 Assentos',
                      badgeColor: const Color(0xFF38BDF8),
                      isActive: isBarueriAtivo,
                      onTap: () => _selecionarEscritorio('Barueri'),
                    ),
                  ],

                  const SizedBox(height: 12),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Text(
                      'MINHA JORNADA',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  // 2. Menu Item: Check-in QR Code
                  _buildSidebarNavItem(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Check-in QR Code',
                    badgeText: seatProvider.reservaHoje != null
                        ? (seatProvider.reservaHoje!.checkinRealizado ? 'Confirmado' : 'Hoje')
                        : null,
                    badgeColor: seatProvider.reservaHoje != null
                        ? (seatProvider.reservaHoje!.checkinRealizado ? const Color(0xFF16A34A) : const Color(0xFFEAB308))
                        : null,
                    isActive: activeIndex == 2,
                    onTap: () => _onTabSelected(2, isAdmin),
                  ),

                  const SizedBox(height: 4),

                  // 3. Menu Pai: Minhas Reservas
                  _buildParentMenuItem(
                    icon: Icons.event_seat_rounded,
                    label: 'Minhas Reservas',
                    isActive: activeIndex == 3,
                    isExpanded: _reservasExpanded,
                    count: seatProvider.minhasReservas.length,
                    onTap: () {
                      _onTabSelected(3, isAdmin);
                      setState(() => _reservasExpanded = !_reservasExpanded);
                    },
                    onExpandToggle: () => setState(() => _reservasExpanded = !_reservasExpanded),
                  ),

                  // Submenus de Filtros de Reserva
                  if (_reservasExpanded) ...[
                    _buildSubmenuItem(
                      icon: Icons.check_circle_outline,
                      iconColor: const Color(0xFF16A34A),
                      label: 'Reservas Ativas',
                      count: seatProvider.totalAtivas,
                      badgeColor: const Color(0xFF16A34A),
                      isActive: activeIndex == 3 && filtroAtual == ReservaFiltro.ativas,
                      onTap: () => _selecionarFiltroReservas(ReservaFiltro.ativas),
                    ),
                    _buildSubmenuItem(
                      icon: Icons.task_alt_rounded,
                      iconColor: const Color(0xFF2563EB),
                      label: 'Reservas Concluídas',
                      count: seatProvider.totalConcluidas,
                      badgeColor: const Color(0xFF2563EB),
                      isActive: activeIndex == 3 && filtroAtual == ReservaFiltro.concluidas,
                      onTap: () => _selecionarFiltroReservas(ReservaFiltro.concluidas),
                    ),
                    _buildSubmenuItem(
                      icon: Icons.cancel_outlined,
                      iconColor: const Color(0xFF64748B),
                      label: 'Reservas Canceladas',
                      count: seatProvider.totalCanceladas,
                      badgeColor: const Color(0xFF64748B),
                      isActive: activeIndex == 3 && filtroAtual == ReservaFiltro.canceladas,
                      onTap: () => _selecionarFiltroReservas(ReservaFiltro.canceladas),
                    ),
                    _buildSubmenuItem(
                      icon: Icons.person_off_outlined,
                      iconColor: const Color(0xFFDC2626),
                      label: 'Não Comparecidas',
                      count: seatProvider.totalNaoComparecidas,
                      badgeColor: const Color(0xFFDC2626),
                      isActive: activeIndex == 3 && filtroAtual == ReservaFiltro.naoComparecidas,
                      onTap: () => _selecionarFiltroReservas(ReservaFiltro.naoComparecidas),
                    ),
                  ],

                  // 4. Menu de Administração RH
                  if (isAdmin) ...[
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Text(
                        'ADMINISTRAÇÃO',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    _buildSidebarNavItem(
                      icon: Icons.admin_panel_settings_rounded,
                      label: 'Painel RH & Gestão',
                      isActive: activeIndex == 4,
                      onTap: () => _onTabSelected(4, isAdmin),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Card do Usuário Logado no Rodapé da Sidebar
          if (user != null)
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: user.isAdmin
                        ? const Color(0xFF7C3AED)
                        : (user.isGestao ? const Color(0xFF0F766E) : const Color(0xFF2563EB)),
                    child: Text(
                      user.nome.isNotEmpty ? user.nome[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          user.perfil,
                          style: TextStyle(
                            color: user.isAdmin
                                ? const Color(0xFFA78BFA)
                                : (user.isGestao ? const Color(0xFF5EEAD4) : const Color(0xFF93C5FD)),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFF94A3B8), size: 18),
                    tooltip: 'Encerrar Sessão',
                    onPressed: _confirmLogout,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Menu Pai com Toggle de Expansão
  Widget _buildParentMenuItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isExpanded,
    int? count,
    required VoidCallback onTap,
    required VoidCallback onExpandToggle,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1E293B) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFFE2E8F0),
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
              if (count != null)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              InkWell(
                onTap: onExpandToggle,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Submenu Item Indentado
  Widget _buildSubmenuItem({
    required IconData icon,
    Color? iconColor,
    required String label,
    String? badgeText,
    int? count,
    Color? badgeColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final effectiveBadgeColor = badgeColor ?? const Color(0xFF38BDF8);

    return Container(
      margin: const EdgeInsets.only(left: 28, right: 12, top: 2, bottom: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1E293B) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: isActive ? effectiveBadgeColor : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: isActive
                    ? Colors.white
                    : (iconColor ?? const Color(0xFF64748B)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: effectiveBadgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: effectiveBadgeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (count != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: effectiveBadgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: effectiveBadgeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Item de Navegação Simples da Sidebar
  Widget _buildSidebarNavItem({
    required IconData icon,
    required String label,
    String? badgeText,
    Color? badgeColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1E293B) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: isActive ? const Color(0xFF38BDF8) : Colors.transparent,
                width: 3.0,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFFE2E8F0),
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? const Color(0xFF7C3AED)).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (badgeColor ?? const Color(0xFF7C3AED)).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor ?? const Color(0xFF7C3AED),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Top Bar Corporativa Superior Contextual
  Widget _buildCorporateTopBar(
    BuildContext context,
    UserModel? user,
    int activeIndex,
    SeatMapProvider seatProvider,
  ) {
    String sectionTitle;
    String sectionSubtitle;

    if (activeIndex == 0) {
      sectionTitle = '';
      sectionSubtitle = '';
    } else if (activeIndex == 1) {
      final escNome = seatProvider.selectedEscritorio?.nome ?? 'Berrini';
      final isBerrini = escNome.toLowerCase().contains('berrini');
      sectionTitle = 'Mapa de Assentos — Escritório $escNome';
      sectionSubtitle = isBerrini
          ? 'Planta Baixa Interativa 2D • 102 Estações de Trabalho'
          : 'Planta Baixa Interativa 2D • 66 Assentos Disponíveis';
    } else if (activeIndex == 2) {
      sectionTitle = 'Check-in por QR Code — Validação de Presença';
      sectionSubtitle = 'Escaneie o código fixado na sua estação de trabalho até as 11h30';
    } else if (activeIndex == 3) {
      String filtroNome;
      switch (seatProvider.filtroReservas) {
        case ReservaFiltro.ativas:
          filtroNome = 'Reservas Ativas';
          break;
        case ReservaFiltro.concluidas:
          filtroNome = 'Reservas Concluídas';
          break;
        case ReservaFiltro.canceladas:
          filtroNome = 'Reservas Canceladas';
          break;
        case ReservaFiltro.naoComparecidas:
          filtroNome = 'Reservas Não Comparecidas (No-Show)';
          break;
        case ReservaFiltro.todas:
          filtroNome = 'Todas as Reservas';
          break;
      }
      sectionTitle = 'Minhas Reservas — $filtroNome';
      sectionSubtitle = 'Histórico e confirmações de presença do usuário';
    } else {
      sectionTitle = 'Painel Administrativo RH & Gestão';
      sectionSubtitle = 'Gestão de assentos, relatórios de ocupação e políticas de presença';
    }

    final todayFormatted = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now());

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          if (sectionTitle.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  sectionTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  sectionSubtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          const Spacer(),

          // Badge de Data no Canto Direito
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.today_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  todayFormatted,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
