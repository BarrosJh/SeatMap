import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../providers/seat_map_provider.dart';

class MobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final UserModel? user;
  final int activeIndex;
  final SeatMapProvider seatProvider;
  final VoidCallback onOpenOfficeSelector;
  final VoidCallback onLogout;

  const MobileAppBar({
    super.key,
    required this.user,
    required this.activeIndex,
    required this.seatProvider,
    required this.onOpenOfficeSelector,
    required this.onLogout,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isMapa = activeIndex == 1;
    String title = 'SeatMap';
    if (isMapa) {
      final esc = seatProvider.selectedEscritorio?.nome ?? 'Berrini';
      title = 'Mapa ($esc)';
    } else if (activeIndex == 2) {
      title = 'Check-in QR';
    } else if (activeIndex == 3) {
      title = 'Minhas Reservas';
    } else if (activeIndex == 4) {
      title = 'Painel RH';
    }

    final titleContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.domain_rounded, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isMapa) ...[
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF93C5FD), size: 18),
        ],
      ],
    );

    return AppBar(
      backgroundColor: const Color(0xFF0F172A),
      elevation: 0,
      automaticallyImplyLeading: false,
      iconTheme: const IconThemeData(color: Colors.white),
      title: isMapa
          ? InkWell(
              onTap: onOpenOfficeSelector,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: titleContent,
              ),
            )
          : titleContent,
      actions: [
        if (user != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: user!.isAdmin
                      ? const Color(0xFF7C3AED)
                      : (user!.isGestao ? const Color(0xFF0F766E) : const Color(0xFF2563EB)),
                  child: Text(
                    user!.nome.isNotEmpty ? user!.nome[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
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
}

