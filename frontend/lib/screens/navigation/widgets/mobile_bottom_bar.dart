import 'package:flutter/material.dart';
import '../../../providers/seat_map_provider.dart';

class MobileBottomBar extends StatelessWidget {
  final int activeIndex;
  final bool isAdmin;
  final bool isTi;
  final SeatMapProvider seatProvider;
  final Function(int index) onDestinationSelected;

  const MobileBottomBar({
    super.key,
    required this.activeIndex,
    required this.isAdmin,
    this.isTi = false,
    required this.seatProvider,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B), width: 1.0),
        ),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0F172A),
          indicatorColor: const Color(0xFF2563EB),
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold);
            }
            return const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.normal);
          }),
          iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Colors.white, size: 22);
            }
            return const IconThemeData(color: Color(0xFF94A3B8), size: 20);
          }),
        ),
        child: NavigationBar(
          selectedIndex: activeIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Início',
            ),
            const NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: 'Mapa',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: seatProvider.reservaHoje != null,
                backgroundColor: seatProvider.reservaHoje?.checkinRealizado == true
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFEAB308),
                child: const Icon(Icons.qr_code_scanner_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: seatProvider.reservaHoje != null,
                backgroundColor: seatProvider.reservaHoje?.checkinRealizado == true
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFEAB308),
                child: const Icon(Icons.qr_code_scanner_rounded),
              ),
              label: 'Check-in',
            ),
            NavigationDestination(
              icon: Badge(
                label: Text('${seatProvider.totalAtivas}'),
                isLabelVisible: seatProvider.totalAtivas > 0,
                backgroundColor: const Color(0xFF2563EB),
                child: const Icon(Icons.event_seat_outlined),
              ),
              selectedIcon: Badge(
                label: Text('${seatProvider.totalAtivas}'),
                isLabelVisible: seatProvider.totalAtivas > 0,
                backgroundColor: const Color(0xFF2563EB),
                child: const Icon(Icons.event_seat_rounded),
              ),
              label: 'Reservas',
            ),
            if (isAdmin)
              const NavigationDestination(
                icon: Icon(Icons.admin_panel_settings_outlined),
                selectedIcon: Icon(Icons.admin_panel_settings_rounded),
                label: 'RH',
              ),
            if (isTi)
              const NavigationDestination(
                icon: Icon(Icons.terminal_outlined),
                selectedIcon: Icon(Icons.terminal_rounded),
                label: 'TI',
              ),
          ],
        ),
      ),
    );
  }
}

