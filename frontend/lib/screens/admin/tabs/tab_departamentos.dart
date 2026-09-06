import 'package:flutter/material.dart';
import '../../../models/admin_models.dart';

class TabDepartamentos extends StatelessWidget {
  final List<DepartamentoModel> departamentos;
  final VoidCallback onNovoDepartamento;

  const TabDepartamentos({
    super.key,
    required this.departamentos,
    required this.onNovoDepartamento,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Text('Departamentos Corporativos (${departamentos.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Novo Departamento'),
                    onPressed: onNovoDepartamento,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: departamentos.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final d = departamentos[i];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        child: Icon(Icons.corporate_fare, size: 20),
                      ),
                      title: Text(d.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('ID: ${d.id} | Total de Colaboradores Vinculados: ${d.totalUsuarios}'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

