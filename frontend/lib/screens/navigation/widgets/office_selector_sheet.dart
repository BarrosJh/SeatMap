import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/seat_map_provider.dart';

class OfficeSelectorSheet extends StatelessWidget {
  final Function(String nomeEscritorio) onSelectEscritorio;

  const OfficeSelectorSheet({
    super.key,
    required this.onSelectEscritorio,
  });

  static void show(BuildContext context, Function(String nomeEscritorio) onSelectEscritorio) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => OfficeSelectorSheet(onSelectEscritorio: onSelectEscritorio),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seatProvider = Provider.of<SeatMapProvider>(context);
    final escAtual = seatProvider.selectedEscritorio?.nome.toLowerCase() ?? '';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.apartment_rounded, color: Color(0xFF2563EB), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Selecione o Escritório',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Escolha a unidade para visualizar a planta e reservar:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            _buildEscritorioOptionCard(
              context: context,
              nome: 'Berrini',
              cidade: 'São Paulo - SP',
              totalMesas: '102 Assentos',
              isSelected: escAtual.contains('berrini'),
              icon: Icons.domain_rounded,
              onTap: () {
                Navigator.pop(context);
                onSelectEscritorio('Berrini');
              },
            ),
            const SizedBox(height: 10),
            _buildEscritorioOptionCard(
              context: context,
              nome: 'Barueri',
              cidade: 'Barueri - Alphaville',
              totalMesas: '66 Assentos',
              isSelected: escAtual.contains('barueri'),
              icon: Icons.apartment_rounded,
              onTap: () {
                Navigator.pop(context);
                onSelectEscritorio('Barueri');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEscritorioOptionCard({
    required BuildContext context,
    required String nome,
    required String cidade,
    required String totalMesas,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : const Color(0xFF475569), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Escritório $nome',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'ATIVO',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$cidade • $totalMesas',
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

