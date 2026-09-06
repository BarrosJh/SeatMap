import 'package:flutter/material.dart';
import '../../../models/seat_model.dart';
import '../../../models/user_model.dart';

class BaiaCardListView extends StatelessWidget {
  final List<BaiaModel> baias;
  final UserModel currentUser;
  final String token;
  final Function(CadeiraModel cadeira) onCadeiraTapped;

  const BaiaCardListView({
    super.key,
    required this.baias,
    required this.currentUser,
    required this.token,
    required this.onCadeiraTapped,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: baias.length,
      itemBuilder: (context, index) {
        final baia = baias[index];
        return _buildBaiaCard(context, baia, index);
      },
    );
  }

  Widget _buildBaiaCard(BuildContext context, BaiaModel baia, int index) {
    final rangeInicio = baia.cadeiras.isNotEmpty ? baia.cadeiras.first.identificador : '';
    final rangeFim = baia.cadeiras.isNotEmpty ? baia.cadeiras.last.identificador : '';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho da Bancada
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.table_restaurant_rounded, color: Color(0xFF2563EB), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bancada ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '${baia.cadeiras.length} assentos (Mesas $rangeInicio a $rangeFim)',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: baia.totalLivres > 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: baia.totalLivres > 0 ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                    ),
                  ),
                  child: Text(
                    '${baia.totalLivres} livres',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: baia.totalLivres > 0 ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Grade de Botões de Assentos
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: baia.cadeiras.map((cadeira) {
                return _buildCleanSeatButton(cadeira);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanSeatButton(CadeiraModel cadeira) {
    Color bgColor = const Color(0xFFF8FAFC);
    Color borderColor = const Color(0xFFCBD5E1);
    Color textColor = const Color(0xFF0F172A);
    Color statusColor = const Color(0xFF16A34A);
    String statusLabel = 'Livre';
    IconData statusIcon = Icons.event_seat;

    final isSameDept = cadeira.ocupante != null &&
        cadeira.ocupante!.departamentoId != null &&
        cadeira.ocupante!.departamentoId == currentUser.departamentoId;

    if (cadeira.isMinhaReserva) {
      bgColor = const Color(0xFFEFF6FF);
      borderColor = const Color(0xFF2563EB);
      textColor = const Color(0xFF1E3A8A);
      statusColor = const Color(0xFF2563EB);
      statusLabel = 'Você';
      statusIcon = Icons.person;
    } else if (cadeira.isOcupada) {
      if (isSameDept) {
        bgColor = const Color(0xFFFFFBEB);
        borderColor = const Color(0xFFF59E0B);
        textColor = const Color(0xFF78350F);
        statusColor = const Color(0xFFD97706);
        statusLabel = cadeira.ocupante?.nome.split(' ').first ?? 'Colega';
        statusIcon = Icons.group;
      } else {
        bgColor = const Color(0xFFFEF2F2);
        borderColor = const Color(0xFFEF4444);
        textColor = const Color(0xFF991B1B);
        statusColor = const Color(0xFFDC2626);
        statusLabel = 'Ocupada';
        statusIcon = Icons.person_outline;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onCadeiraTapped(cadeira),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 82,
          height: 72,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: (cadeira.isMinhaReserva || isSameDept) ? 2.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      cadeira.identificador,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

