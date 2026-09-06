import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../models/admin_models.dart';

class TabUsuarios extends StatelessWidget {
  final List<AdminUsuarioModel> usuarios;
  final List<DepartamentoModel> departamentos;
  final int totalUsuarios;
  final TextEditingController searchController;
  final String filtroDep;
  final String filtroPerfil;
  final String filtroStatus;
  final Function(String? value) onFiltroDepChanged;
  final Function(String? value) onFiltroPerfilChanged;
  final Function(String? value) onFiltroStatusChanged;
  final VoidCallback onBuscar;
  final VoidCallback onNovoUsuario;
  final Function(AdminUsuarioModel usuario) onEditarUsuario;
  final Function(AdminUsuarioModel usuario) onResetSenha;
  final Function(AdminUsuarioModel usuario) onToggleStatus;

  const TabUsuarios({
    super.key,
    required this.usuarios,
    required this.departamentos,
    required this.totalUsuarios,
    required this.searchController,
    required this.filtroDep,
    required this.filtroPerfil,
    required this.filtroStatus,
    required this.onFiltroDepChanged,
    required this.onFiltroPerfilChanged,
    required this.onFiltroStatusChanged,
    required this.onBuscar,
    required this.onNovoUsuario,
    required this.onEditarUsuario,
    required this.onResetSenha,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: LayoutBuilder(
                    builder: (context, filterConstraints) {
                      final isMobileFilter = filterConstraints.maxWidth < 650;

                      final searchField = TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'Buscar por nome, e-mail ou matrícula...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => onBuscar(),
                      );

                      final btnBuscar = ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        icon: const Icon(Icons.search),
                        label: const Text('Buscar'),
                        onPressed: onBuscar,
                      );

                      final btnNovo = ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Novo Usuário'),
                        onPressed: onNovoUsuario,
                      );

                      final dropDepto = DropdownButtonFormField<String>(
                        initialValue: filtroDep,
                        decoration: const InputDecoration(labelText: 'Departamento', isDense: true, border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem(value: 'todos', child: Text('Todos os Departamentos', overflow: TextOverflow.ellipsis)),
                          ...departamentos.map((d) => DropdownMenuItem(value: d.id.toString(), child: Text(d.nome, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: onFiltroDepChanged,
                      );

                      final dropPerfil = DropdownButtonFormField<String>(
                        initialValue: filtroPerfil,
                        decoration: const InputDecoration(labelText: 'Perfil', isDense: true, border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'todos', child: Text('Todos os Perfis')),
                          DropdownMenuItem(value: 'COLABORADOR', child: Text('Colaborador')),
                          DropdownMenuItem(value: 'GESTAO', child: Text('Gestão')),
                          DropdownMenuItem(value: 'ADMIN_RH', child: Text('Administrador RH')),
                        ],
                        onChanged: onFiltroPerfilChanged,
                      );

                      final dropStatus = DropdownButtonFormField<String>(
                        initialValue: filtroStatus,
                        decoration: const InputDecoration(labelText: 'Status', isDense: true, border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'todos', child: Text('Todos os Status')),
                          DropdownMenuItem(value: 'true', child: Text('Apenas Ativos')),
                          DropdownMenuItem(value: 'false', child: Text('Apenas Inativos')),
                        ],
                        onChanged: onFiltroStatusChanged,
                      );

                      if (isMobileFilter) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(child: searchField),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  style: IconButton.styleFrom(backgroundColor: AppConstants.primaryColor),
                                  icon: const Icon(Icons.search, color: Colors.white),
                                  onPressed: onBuscar,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            btnNovo,
                            const SizedBox(height: 12),
                            dropDepto,
                            const SizedBox(height: 10),
                            dropPerfil,
                            const SizedBox(height: 10),
                            dropStatus,
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: searchField),
                              const SizedBox(width: 12),
                              btnBuscar,
                              const SizedBox(width: 12),
                              btnNovo,
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: dropDepto),
                              const SizedBox(width: 12),
                              Expanded(child: dropPerfil),
                              const SizedBox(width: 12),
                              Expanded(child: dropStatus),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Colaboradores Cadastrados ($totalUsuarios)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Atualizar Lista',
                    onPressed: onBuscar,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              usuarios.isEmpty
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text('Nenhum usuário encontrado com os filtros aplicados.', style: TextStyle(color: Colors.grey.shade600)),
                        ),
                      ),
                    )
                  : Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: usuarios.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final u = usuarios[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            leading: CircleAvatar(
                              backgroundColor: u.ativo ? const Color(0xFF0F172A) : Colors.grey.shade400,
                              foregroundColor: Colors.white,
                              child: Text(u.nome.isNotEmpty ? u.nome[0].toUpperCase() : 'U'),
                            ),
                            title: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  u.nome,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: u.ativo ? const Color(0xFF0F172A) : Colors.grey,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: u.perfil == 'GESTAO' ? Colors.blue.shade50 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: u.perfil == 'GESTAO' ? Colors.blue.shade300 : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    u.perfil == 'GESTAO' ? 'GESTÃO' : 'COLABORADOR',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: u.perfil == 'GESTAO' ? Colors.blue.shade700 : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                if (u.permissaoRh) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.purple.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.admin_panel_settings, size: 11, color: Colors.purple.shade700),
                                        const SizedBox(width: 3),
                                        Text(
                                          'RH ADMIN',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: u.ativo ? Colors.green.shade50 : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: u.ativo ? Colors.green.shade300 : Colors.red.shade300),
                                  ),
                                  child: Text(
                                    u.ativo ? 'ATIVO' : 'INATIVO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: u.ativo ? Colors.green.shade700 : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Matrícula: ${u.matricula} | Depto: ${u.departamentoNome ?? "Geral"}\nE-mail: ${u.email}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  tooltip: 'Editar Usuário',
                                  onPressed: () => onEditarUsuario(u),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.lock_reset, size: 18),
                                  tooltip: 'Redefinir Senha',
                                  onPressed: () => onResetSenha(u),
                                ),
                                IconButton(
                                  icon: Icon(
                                    u.ativo ? Icons.person_off_outlined : Icons.person_outline,
                                    size: 18,
                                    color: u.ativo ? Colors.red.shade600 : Colors.green.shade700,
                                  ),
                                  tooltip: u.ativo ? 'Desativar Usuário' : 'Reativar Usuário',
                                  onPressed: () => onToggleStatus(u),
                                ),
                              ],
                            ),
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

