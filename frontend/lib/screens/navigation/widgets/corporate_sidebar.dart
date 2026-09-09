import 'package:flutter/material.dart';
import '../../../models/seat_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/seat_map_provider.dart';

class CorporateSidebar extends StatelessWidget {
  final UserModel? user;
  final bool isAdmin;
  final bool isTi;
  final int? adminTabIndex;
  final int? tiTabIndex;
  final int activeIndex;
  final SeatMapProvider seatProvider;
  final bool mapaExpanded;
  final bool reservasExpanded;
  final VoidCallback onToggleMapaExpanded;
  final VoidCallback onToggleReservasExpanded;
  final Function(int index) onSelectTab;
  final Function(String nomeEscritorio) onSelectEscritorio;
  final Function(ReservaFiltro filtro) onSelectFiltroReservas;
  final VoidCallback onLogout;
  final bool isDrawer;

  const CorporateSidebar({
    super.key,
    required this.user,
    required this.isAdmin,
    this.isTi = false,
    this.adminTabIndex,
    this.tiTabIndex,
    required this.activeIndex,
    required this.seatProvider,
    required this.mapaExpanded,
    required this.reservasExpanded,
    required this.onToggleMapaExpanded,
    required this.onToggleReservasExpanded,
    required this.onSelectTab,
    required this.onSelectEscritorio,
    required this.onSelectFiltroReservas,
    required this.onLogout,
    this.isDrawer = false,
  });

  @override
  Widget build(BuildContext context) {
    final escSelecionadoNome = seatProvider.selectedEscritorio?.nome.toLowerCase() ?? '';
    final isBerriniAtivo = activeIndex == 1 && escSelecionadoNome.contains('berrini');
    final isBarueriAtivo = activeIndex == 1 && escSelecionadoNome.contains('barueri');
    final filtroAtual = seatProvider.filtroReservas;

    return Column(
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
                  onTap: () => onSelectTab(0),
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
                  isExpanded: mapaExpanded,
                  onTap: () {
                    onSelectTab(1);
                    onToggleMapaExpanded();
                  },
                  onExpandToggle: onToggleMapaExpanded,
                ),

                // Submenus de Escritórios
                if (mapaExpanded) ...[
                  _buildSubmenuItem(
                    icon: Icons.business_outlined,
                    label: 'Escritório Berrini',
                    badgeText: '102 Assentos',
                    badgeColor: const Color(0xFF38BDF8),
                    isActive: isBerriniAtivo,
                    onTap: () => onSelectEscritorio('Berrini'),
                  ),
                  _buildSubmenuItem(
                    icon: Icons.apartment_outlined,
                    label: 'Escritório Barueri',
                    badgeText: '66 Assentos',
                    badgeColor: const Color(0xFF38BDF8),
                    isActive: isBarueriAtivo,
                    onTap: () => onSelectEscritorio('Barueri'),
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
                  onTap: () => onSelectTab(2),
                ),

                const SizedBox(height: 4),

                // 3. Menu Pai: Minhas Reservas
                _buildParentMenuItem(
                  icon: Icons.event_seat_rounded,
                  label: 'Minhas Reservas',
                  isActive: activeIndex == 3,
                  isExpanded: reservasExpanded,
                  count: seatProvider.minhasReservas.length,
                  onTap: () {
                    onSelectTab(3);
                    onToggleReservasExpanded();
                  },
                  onExpandToggle: onToggleReservasExpanded,
                ),

                // Submenus de Filtros de Reserva
                if (reservasExpanded) ...[
                  _buildSubmenuItem(
                    icon: Icons.check_circle_outline,
                    iconColor: const Color(0xFF16A34A),
                    label: 'Reservas Ativas',
                    count: seatProvider.totalAtivas,
                    badgeColor: const Color(0xFF16A34A),
                    isActive: activeIndex == 3 && filtroAtual == ReservaFiltro.ativas,
                    onTap: () => onSelectFiltroReservas(ReservaFiltro.ativas),
                  ),
                  _buildSubmenuItem(
                    icon: Icons.task_alt_rounded,
                    iconColor: const Color(0xFF2563EB),
                    label: 'Reservas Concluídas',
                    count: seatProvider.totalConcluidas,
                    badgeColor: const Color(0xFF2563EB),
                    isActive: activeIndex == 3 && filtroAtual == ReservaFiltro.concluidas,
                    onTap: () => onSelectFiltroReservas(ReservaFiltro.concluidas),
                  ),
                  _buildSubmenuItem(
                    icon: Icons.cancel_outlined,
                    iconColor: const Color(0xFF64748B),
                    label: 'Reservas Canceladas',
                    count: seatProvider.totalCanceladas,
                    badgeColor: const Color(0xFF64748B),
                    isActive: activeIndex == 3 && filtroAtual == ReservaFiltro.canceladas,
                    onTap: () => onSelectFiltroReservas(ReservaFiltro.canceladas),
                  ),
                  _buildSubmenuItem(
                    icon: Icons.person_off_outlined,
                    iconColor: const Color(0xFFDC2626),
                    label: 'Não Comparecidas',
                    count: seatProvider.totalNaoComparecidas,
                    badgeColor: const Color(0xFFDC2626),
                    isActive: activeIndex == 3 && filtroAtual == ReservaFiltro.naoComparecidas,
                    onTap: () => onSelectFiltroReservas(ReservaFiltro.naoComparecidas),
                  ),
                ],

                // 4. Menu de Administração RH e TI
                if (isAdmin || isTi) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Text(
                      (isAdmin && isTi)
                          ? 'ADMINISTRAÇÃO & TI'
                          : (isTi ? 'TECNOLOGIA DA INFORMAÇÃO' : 'GESTÃO & RECURSOS HUMANOS'),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (isAdmin && adminTabIndex != null)
                    _buildSidebarNavItem(
                      icon: Icons.admin_panel_settings_rounded,
                      label: 'Painel RH & Gestão',
                      isActive: activeIndex == adminTabIndex,
                      onTap: () => onSelectTab(adminTabIndex!),
                    ),
                  if (isTi && tiTabIndex != null)
                    _buildSidebarNavItem(
                      icon: Icons.terminal_rounded,
                      label: 'Painel de TI & Infra',
                      isActive: activeIndex == tiTabIndex,
                      onTap: () => onSelectTab(tiTabIndex!),
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
                  backgroundColor: user!.isAdmin
                      ? const Color(0xFF7C3AED)
                      : (user!.isGestao ? const Color(0xFF0F766E) : const Color(0xFF2563EB)),
                  child: Text(
                    user!.nome.isNotEmpty ? user!.nome[0].toUpperCase() : 'U',
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
                        user!.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        user!.perfil,
                        style: TextStyle(
                          color: user!.isAdmin
                              ? const Color(0xFFA78BFA)
                              : (user!.isGestao ? const Color(0xFF5EEAD4) : const Color(0xFF93C5FD)),
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
                  onPressed: onLogout,
                ),
              ],
            ),
          ),
      ],
    );
  }

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
}

