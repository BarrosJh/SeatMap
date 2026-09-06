import 'package:flutter/material.dart';

class TabImportacaoLote extends StatelessWidget {
  final TextEditingController loteTextController;
  final TextEditingController loteDefaultSenhaController;
  final List<Map<String, dynamic>> lotePreview;
  final Map<String, dynamic>? loteResultado;
  final VoidCallback onProcessarPrevia;
  final VoidCallback onCarregarExemplo;
  final VoidCallback onExecutarImportacao;

  const TabImportacaoLote({
    super.key,
    required this.loteTextController,
    required this.loteDefaultSenhaController,
    required this.lotePreview,
    required this.loteResultado,
    required this.onProcessarPrevia,
    required this.onCarregarExemplo,
    required this.onExecutarImportacao,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, boxConstraints) {
                      final isMobile = boxConstraints.maxWidth < 650;

                      final inputSenha = TextField(
                        controller: loteDefaultSenhaController,
                        decoration: const InputDecoration(
                          labelText: 'Senha Padrão Inicial (se não informada)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      );

                      final btnExemplo = OutlinedButton.icon(
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Carregar Exemplo'),
                        onPressed: onCarregarExemplo,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Importação em Lote de Colaboradores',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Cole os dados de colaboradores em formato CSV (delimitado por ponto e vírgula ou vírgula). O sistema criará automaticamente departamentos que não existirem e gerará as credenciais de acesso.',
                            style: TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: const Text(
                              'Formato esperado das colunas:\nNome;Email;Matricula;Departamento;Perfil;Senha (opcional)',
                              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (isMobile) ...[
                            inputSenha,
                            const SizedBox(height: 10),
                            SizedBox(width: double.infinity, child: btnExemplo),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(child: inputSenha),
                                const SizedBox(width: 12),
                                btnExemplo,
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextField(
                            controller: loteTextController,
                            maxLines: 8,
                            onChanged: (_) => onProcessarPrevia(),
                            decoration: const InputDecoration(
                              hintText: 'Cole aqui os registros CSV...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (isMobile) ...[
                            Text('Linhas identificadas: ${lotePreview.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                icon: const Icon(Icons.cloud_upload_outlined),
                                label: Text('Importar ${lotePreview.length} Usuários'),
                                onPressed: lotePreview.isEmpty ? null : onExecutarImportacao,
                              ),
                            ),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Linhas identificadas: ${lotePreview.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                  icon: const Icon(Icons.cloud_upload_outlined),
                                  label: Text('Importar ${lotePreview.length} Usuários'),
                                  onPressed: lotePreview.isEmpty ? null : onExecutarImportacao,
                                ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (loteResultado != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.green.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.green.shade300)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Resultado da Importação:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                        const SizedBox(height: 6),
                        Text(
                          'Total: ${loteResultado!["totalProcessados"]} | Novos Criados: ${loteResultado!["criados"]} | Atualizados: ${loteResultado!["atualizados"]} | Erros: ${loteResultado!["totalErros"]}',
                          style: TextStyle(color: Colors.green.shade900),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (lotePreview.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pré-visualização dos Dados:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Nome')),
                              DataColumn(label: Text('E-mail')),
                              DataColumn(label: Text('Matrícula')),
                              DataColumn(label: Text('Departamento')),
                              DataColumn(label: Text('Perfil')),
                            ],
                            rows: lotePreview.map((item) {
                              return DataRow(cells: [
                                DataCell(Text(item['nome'] ?? '')),
                                DataCell(Text(item['email'] ?? '')),
                                DataCell(Text(item['matricula'] ?? '')),
                                DataCell(Text(item['departamento'] ?? '')),
                                DataCell(Text(item['perfil'] ?? '')),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

