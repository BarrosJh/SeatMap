import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/user_model.dart';
import '../../../providers/seat_map_provider.dart';

class MapControlHeader extends StatelessWidget {
  final UserModel? user;
  final String? token;
  final SeatMapProvider seatProvider;
  final int weekOffset;
  final bool isFloorPlanView;
  final List<DateTime> diasUteis;
  final String weekLabel;
  final int totalAssentos;
  final int totalLivres;
  final int totalOcupadas;
  final int totalMinhas;
  final bool canGoBack;
  final bool canGoForward;
  final Function(int delta) onChangeWeek;
  final VoidCallback onResetToCurrentWeek;
  final VoidCallback onPickCustomDate;
  final Function(DateTime dia) onSelectDate;
  final Function(bool isFloorPlan) onToggleView;

  const MapControlHeader({
    super.key,
    required this.user,
    required this.token,
    required this.seatProvider,
    required this.weekOffset,
    required this.isFloorPlanView,
    required this.diasUteis,
    required this.weekLabel,
    required this.totalAssentos,
    required this.totalLivres,
    required this.totalOcupadas,
    required this.totalMinhas,
    required this.canGoBack,
    required this.canGoForward,
    required this.onChangeWeek,
    required this.onResetToCurrentWeek,
    required this.onPickCustomDate,
    required this.onSelectDate,
    required this.onToggleView,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 500 ? 10 : 20,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, headerConstraints) {
          final isCompact = headerConstraints.maxWidth < 780;

          final weekSelectorWidget = Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: isCompact ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
              mainAxisSize: isCompact ? MainAxisSize.max : MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  tooltip: canGoBack ? 'Semana Anterior' : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  color: canGoBack ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                  onPressed: (canGoBack && token != null) ? () => onChangeWeek(-1) : null,
                ),
                Flexible(
                  child: InkWell(
                    onTap: token != null ? onResetToCurrentWeek : null,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.date_range_rounded, size: 13, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              weekLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      tooltip: canGoForward ? 'Próxima Semana' : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      color: canGoForward ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                      onPressed: (canGoForward && token != null) ? () => onChangeWeek(1) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_month_outlined, size: 15, color: Color(0xFF64748B)),
                      tooltip: 'Escolher Data no Calendário',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      onPressed: token != null ? onPickCustomDate : null,
                    ),
                  ],
                ),
              ],
            ),
          );

          final dayTabsWidget = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: diasUteis.map((dia) {
                final isSelected = DateFormat('yyyy-MM-dd').format(dia) == seatProvider.selectedDateIso;
                final isToday = DateFormat('yyyy-MM-dd').format(dia) == DateFormat('yyyy-MM-dd').format(DateTime.now());
                final diaSemanaNome = DateFormat('EEE', 'pt_BR').format(dia).toUpperCase();
                final diaNumero = DateFormat('dd/MM').format(dia);

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      if (token != null) {
                        onSelectDate(dia);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                diaSemanaNome,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white70 : const Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                diaNumero,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'HOJE',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : const Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );

          final viewToggleWidget = Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewToggleButton(
                  icon: Icons.map_rounded,
                  label: 'Planta',
                  isSelected: isFloorPlanView,
                  iconOnly: isCompact,
                  onTap: () => onToggleView(true),
                ),
                _buildViewToggleButton(
                  icon: Icons.view_agenda_rounded,
                  label: 'Lista',
                  isSelected: !isFloorPlanView,
                  iconOnly: isCompact,
                  onTap: () => onToggleView(false),
                ),
              ],
            ),
          );

          return Column(
            children: [
              if (isCompact) ...[
                // Mobile / Compact Layout:
                // Linha 1 = Seletor de Semana Full Width
                SizedBox(
                  width: double.infinity,
                  child: weekSelectorWidget,
                ),
                const SizedBox(height: 8),
                // Linha 2 = Dias Úteis + Alternador Planta/Lista
                Row(
                  children: [
                    Expanded(child: dayTabsWidget),
                    const SizedBox(width: 6),
                    viewToggleWidget,
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 6),
                // Linha 3 = KPIs Executivos (Total, Livres, Ocupadas, Minhas)
                Row(
                  children: [
                    Expanded(child: _buildModernKpi(label: 'Total', value: totalAssentos, color: const Color(0xFF334155))),
                    const SizedBox(width: 4),
                    Expanded(child: _buildModernKpi(label: 'Livres', value: totalLivres, color: const Color(0xFF16A34A))),
                    const SizedBox(width: 4),
                    Expanded(child: _buildModernKpi(label: 'Ocupadas', value: totalOcupadas, color: const Color(0xFFDC2626))),
                    const SizedBox(width: 4),
                    Expanded(child: _buildModernKpi(label: 'Minhas', value: totalMinhas, color: const Color(0xFF2563EB))),
                  ],
                ),
                const SizedBox(height: 8),
                // Linha 4 = Legenda direta abaixo dos KPIs (Sem necessidade de scroll)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLegendDot(const Color(0xFF22C55E), 'Livre'),
                      _buildLegendDot(const Color(0xFF2563EB), 'Sua Reserva'),
                      _buildLegendDot(const Color(0xFFDC2626), 'Ocupada'),
                      _buildLegendDot(const Color(0xFFD97706), 'Colega Depto'),
                    ],
                  ),
                ),
              ] else ...[
                // Desktop / Wide Layout
                Row(
                  children: [
                    weekSelectorWidget,
                    const SizedBox(width: 12),
                    Expanded(child: dayTabsWidget),
                    if (seatProvider.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    const SizedBox(width: 8),
                    viewToggleWidget,
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildModernKpi(label: 'Total', value: totalAssentos, color: const Color(0xFF334155)),
                      const SizedBox(width: 6),
                      _buildModernKpi(label: 'Livres', value: totalLivres, color: const Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      _buildModernKpi(label: 'Ocupadas', value: totalOcupadas, color: const Color(0xFFDC2626)),
                      const SizedBox(width: 6),
                      _buildModernKpi(label: 'Minhas', value: totalMinhas, color: const Color(0xFF2563EB)),
                      const SizedBox(width: 14),
                      Container(width: 1, height: 16, color: const Color(0xFFE2E8F0)),
                      const SizedBox(width: 14),
                      _buildLegendDot(const Color(0xFF22C55E), 'Livre'),
                      const SizedBox(width: 10),
                      _buildLegendDot(const Color(0xFF2563EB), 'Sua Reserva'),
                      const SizedBox(width: 10),
                      _buildLegendDot(const Color(0xFFDC2626), 'Ocupada'),
                      const SizedBox(width: 10),
                      _buildLegendDot(const Color(0xFFD97706), 'Colega Depto'),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool iconOnly = false,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: iconOnly ? 8 : 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
              if (!iconOnly) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernKpi({
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '$label: ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
