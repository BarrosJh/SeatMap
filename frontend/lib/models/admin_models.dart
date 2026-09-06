class AdminUsuarioModel {
  final int id;
  final String nome;
  final String email;
  final String matricula;
  final String perfil;
  final bool permissaoRh;
  final bool ativo;
  final int? departamentoId;
  final String? departamentoNome;
  final int totalReservasAtivas;

  AdminUsuarioModel({
    required this.id,
    required this.nome,
    required this.email,
    required this.matricula,
    required this.perfil,
    this.permissaoRh = false,
    required this.ativo,
    this.departamentoId,
    this.departamentoNome,
    this.totalReservasAtivas = 0,
  });

  bool get isAdmin => permissaoRh || perfil == 'ADMIN_RH';

  factory AdminUsuarioModel.fromJson(Map<String, dynamic> json) {
    final perfilStr = json['perfil'] as String? ?? 'COLABORADOR';
    final hasRh = json['permissao_rh'] == true || 
                  json['permissaoRh'] == true || 
                  json['is_admin'] == true || 
                  perfilStr == 'ADMIN_RH';

    return AdminUsuarioModel(
      id: json['id'] as int,
      nome: json['nome'] as String? ?? '',
      email: json['email'] as String? ?? '',
      matricula: json['matricula'] as String? ?? '',
      perfil: perfilStr,
      permissaoRh: hasRh,
      ativo: json['ativo'] == true,
      departamentoId: json['departamento_id'] as int?,
      departamentoNome: json['departamento_nome'] as String?,
      totalReservasAtivas: int.tryParse(json['total_reservas_ativas']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'email': email,
    'matricula': matricula,
    'perfil': perfil,
    'permissao_rh': permissaoRh,
    'permissaoRh': permissaoRh,
    'ativo': ativo,
    'departamento_id': departamentoId,
  };
}

class DepartamentoModel {
  final int id;
  final String nome;
  final int totalUsuarios;

  DepartamentoModel({
    required this.id,
    required this.nome,
    this.totalUsuarios = 0,
  });

  factory DepartamentoModel.fromJson(Map<String, dynamic> json) {
    return DepartamentoModel(
      id: json['id'] as int,
      nome: json['nome'] as String? ?? '',
      totalUsuarios: int.tryParse(json['total_usuarios']?.toString() ?? '0') ?? 0,
    );
  }
}

class AdminReservaModel {
  final int id;
  final int cadeiraId;
  final String assento;
  final String baiaNome;
  final int escritorioId;
  final String escritorioNome;
  final int usuarioId;
  final String usuarioNome;
  final String matricula;
  final String? usuarioEmail;
  final String? departamentoNome;
  final String dataReserva;
  final bool checkinRealizado;
  final String? checkinEm;
  final String status;
  final String? codigoComprovante;
  final String? criadoEm;

  AdminReservaModel({
    required this.id,
    required this.cadeiraId,
    required this.assento,
    required this.baiaNome,
    required this.escritorioId,
    required this.escritorioNome,
    required this.usuarioId,
    required this.usuarioNome,
    required this.matricula,
    this.usuarioEmail,
    this.departamentoNome,
    required this.dataReserva,
    required this.checkinRealizado,
    this.checkinEm,
    required this.status,
    this.codigoComprovante,
    this.criadoEm,
  });

  factory AdminReservaModel.fromJson(Map<String, dynamic> json) {
    return AdminReservaModel(
      id: json['id'] as int,
      cadeiraId: json['cadeira_id'] as int,
      assento: json['assento'] as String? ?? '',
      baiaNome: json['baia_nome'] as String? ?? '',
      escritorioId: json['escritorio_id'] as int? ?? 1,
      escritorioNome: json['escritorio_nome'] as String? ?? '',
      usuarioId: json['usuario_id'] as int,
      usuarioNome: json['usuario_nome'] as String? ?? '',
      matricula: json['matricula'] as String? ?? '',
      usuarioEmail: json['usuario_email'] as String?,
      departamentoNome: json['departamento_nome'] as String?,
      dataReserva: json['data_reserva'] as String? ?? '',
      checkinRealizado: json['checkin_realizado'] == true,
      checkinEm: json['checkin_em'] as String?,
      status: json['status'] as String? ?? 'ATIVA',
      codigoComprovante: json['codigo_comprovante'] as String?,
      criadoEm: json['criado_em'] as String?,
    );
  }
}
