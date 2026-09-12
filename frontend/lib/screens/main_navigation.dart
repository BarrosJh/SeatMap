import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/responsive_utils.dart';
import '../models/seat_model.dart';
import '../providers/auth_provider.dart';
import '../providers/seat_map_provider.dart';
import 'home_dashboard_screen.dart';
import 'mapa_screen.dart';
import 'checkin_screen.dart';
import 'minhas_reservas_screen.dart';
import 'admin_panel_screen.dart';
import 'ti_panel_screen.dart';
import 'navigation/widgets/corporate_sidebar.dart';
import 'navigation/widgets/corporate_top_bar.dart';
import 'navigation/widgets/mobile_app_bar.dart';
import 'navigation/widgets/mobile_bottom_bar.dart';
import 'navigation/widgets/office_selector_sheet.dart';
import '../widgets/biometria_dialog.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0; // 0 = Início, 1 = Mapa, 2 = Check-in, 3 = Minhas Reservas, 4 = Admin/TI
  bool _mapaExpanded = true;
  bool _reservasExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
      if (auth.token != null && auth.user != null) {
        seatProvider.carregarInicial(auth.token!, auth.user!);
      }
      if (auth.shouldSuggestBiometrics && mounted) {
        auth.clearShouldSuggestBiometrics();
        await BiometriaDialog.showSugestao(context, auth);
      }
    });
  }

  void _onTabSelected(int index, {bool isDrawer = false}) {
    if (isDrawer && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    setState(() => _currentIndex = index);
  }

  void _selecionarEscritorio(String nomeEscritorio, {bool isDrawer = false}) {
    if (isDrawer && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final seatProvider = Provider.of<SeatMapProvider>(context, listen: false);
    seatProvider.prepararTrocaEscritorioPorNome(nomeEscritorio);
    setState(() => _currentIndex = 1);
    if (auth.token != null) {
      seatProvider.selecionarEscritorioPorNome(auth.token!, nomeEscritorio);
    }
  }

  void _navegarParaMapaComData(String nomeEscritorio, DateTime? data) {
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
    setState(() => _currentIndex = 1);
  }

  void _selecionarFiltroReservas(ReservaFiltro filtro, {bool isDrawer = false}) {
    if (isDrawer && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
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
              await auth.logout();
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
    final isTi = user?.isTi ?? false;
    final seatProvider = Provider.of<SeatMapProvider>(context);

    int? adminTabIndex;
    int? tiTabIndex;
    int nextTab = 4;
    if (isAdmin) {
      adminTabIndex = nextTab++;
    }
    if (isTi) {
      tiTabIndex = nextTab++;
    }

    final totalTabs = nextTab;
    final activeIndex = _currentIndex >= totalTabs ? 0 : _currentIndex;

    final List<Widget> screens = [
      HomeDashboardScreen(
        onNavegarParaCheckin: () => setState(() => _currentIndex = 2),
        onNavegarParaMinhasReservas: () => setState(() => _currentIndex = 3),
        onNavegarParaMapa: (nomeEscritorio, data) => _navegarParaMapaComData(nomeEscritorio, data),
      ),
      MapaScreen(
        onNavegarParaCheckin: () => setState(() => _currentIndex = 2),
      ),
      CheckinScreen(
        isActive: activeIndex == 2,
        onNavegarParaMapa: () => setState(() => _currentIndex = 1),
      ),
      MinhasReservasScreen(
        onNavegarParaCheckin: () => setState(() => _currentIndex = 2),
      ),
      if (isAdmin) const AdminPanelScreen(),
      if (isTi) const TiPanelScreen(),
    ];

    final isSpecialPanel = (adminTabIndex != null && activeIndex == adminTabIndex) ||
                           (tiTabIndex != null && activeIndex == tiTabIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveUtils.isMobileWidth(constraints.maxWidth);

        if (isMobile) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: MobileAppBar(
              user: user,
              activeIndex: activeIndex,
              seatProvider: seatProvider,
              onOpenOfficeSelector: () => OfficeSelectorSheet.show(context, _selecionarEscritorio),
              onLogout: _confirmLogout,
            ),
            body: IndexedStack(
              index: activeIndex,
              children: screens,
            ),
            bottomNavigationBar: MobileBottomBar(
              activeIndex: activeIndex,
              isAdmin: isAdmin,
              isTi: isTi,
              seatProvider: seatProvider,
              onDestinationSelected: (index) {
                _onTabSelected(index);
                if (index == 1) {
                  OfficeSelectorSheet.show(context, _selecionarEscritorio);
                }
              },
            ),
          );
        }

        // Layout Desktop / Tablet Grande (>= 850px)
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Row(
            children: [
              // 1. Sidebar Corporativa Fixa com Submenus
              Container(
                width: 270,
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  border: Border(
                    right: BorderSide(color: Color(0xFF1E293B), width: 1.0),
                  ),
                ),
                child: CorporateSidebar(
                  user: user,
                  isAdmin: isAdmin,
                  isTi: isTi,
                  adminTabIndex: adminTabIndex,
                  tiTabIndex: tiTabIndex,
                  activeIndex: activeIndex,
                  seatProvider: seatProvider,
                  mapaExpanded: _mapaExpanded,
                  reservasExpanded: _reservasExpanded,
                  onToggleMapaExpanded: () => setState(() => _mapaExpanded = !_mapaExpanded),
                  onToggleReservasExpanded: () => setState(() => _reservasExpanded = !_reservasExpanded),
                  onSelectTab: (idx) => _onTabSelected(idx),
                  onSelectEscritorio: (nome) => _selecionarEscritorio(nome),
                  onSelectFiltroReservas: (filtro) => _selecionarFiltroReservas(filtro),
                  onLogout: _confirmLogout,
                  isDrawer: false,
                ),
              ),

              // 2. Área Principal de Conteúdo
              Expanded(
                child: Column(
                  children: [
                    // Top Header Corporativo (oculto na Home e nos Painéis de Gestão/TI)
                    if (activeIndex != 0 && !isSpecialPanel)
                      CorporateTopBar(
                        user: user,
                        activeIndex: activeIndex,
                        seatProvider: seatProvider,
                      ),

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
      },
    );
  }
}
