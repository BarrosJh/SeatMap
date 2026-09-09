class AdminUsuarioModel {
  final int id;
  final String nome;
  final String email;
  final String matricula;
  final String perfil;
  final bool permissaoRh;
  final bool permissaoTi;
  final bool exigirMfa;
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
    this.permissaoTi = false,
    this.exigirMfa = false,
    required this.ativo,
    this.departamentoId,
    this.departamentoNome,
    this.totalReservasAtivas = 0,
  });

  bool get isAdmin => permissaoRh || perfil == 'ADMIN_RH';
  bool get isTi => permissaoTi || perfil == 'ADMIN_TI';

  factory AdminUsuarioModel.fromJson(Map<String, dynamic> json) {
    final perfilStr = json['perfil']?.toString() ?? 'COLABORADOR';
    final hasRh = json['permissao_rh'] == true || 
                  json['permissaoRh'] == true || 
                  perfilStr == 'ADMIN_RH';
    final hasTi = json['permissao_ti'] == true ||
                  json['permissaoTi'] == true ||
                  perfilStr == 'ADMIN_TI';
    final needsMfa = json['exigir_mfa'] == true || json['exigirMfa'] == true;

    return AdminUsuarioModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nome: json['nome']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      matricula: json['matricula']?.toString() ?? '',
      perfil: perfilStr,
      permissaoRh: hasRh,
      permissaoTi: hasTi,
      exigirMfa: needsMfa,
      ativo: json['ativo'] == true || json['ativo'] == 1 || json['ativo']?.toString() == 'true',
      departamentoId: json['departamento_id'] != null ? int.tryParse(json['departamento_id'].toString()) : null,
      departamentoNome: json['departamento_nome']?.toString(),
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
    'permissao_ti': permissaoTi,
    'permissaoTi': permissaoTi,
    'exigir_mfa': exigirMfa,
    'exigirMfa': exigirMfa,
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
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nome: json['nome']?.toString() ?? '',
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
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      cadeiraId: int.tryParse(json['cadeira_id']?.toString() ?? '0') ?? 0,
      assento: json['assento']?.toString() ?? '',
      baiaNome: json['baia_nome']?.toString() ?? '',
      escritorioId: int.tryParse(json['escritorio_id']?.toString() ?? '1') ?? 1,
      escritorioNome: json['escritorio_nome']?.toString() ?? '',
      usuarioId: int.tryParse(json['usuario_id']?.toString() ?? '0') ?? 0,
      usuarioNome: json['usuario_nome']?.toString() ?? '',
      matricula: json['matricula']?.toString() ?? '',
      usuarioEmail: json['usuario_email']?.toString(),
      departamentoNome: json['departamento_nome']?.toString(),
      dataReserva: json['data_reserva']?.toString() ?? '',
      checkinRealizado: json['checkin_realizado'] == true || json['checkin_realizado'] == 1 || json['checkin_realizado']?.toString() == 'true',
      checkinEm: json['checkin_em']?.toString(),
      status: json['status']?.toString() ?? 'ATIVA',
      codigoComprovante: json['codigo_comprovante']?.toString(),
      criadoEm: json['criado_em']?.toString(),
    );
  }
}

class AdminManutencaoKpisModel {
  final int totalBloqueadas;
  final int totalOperacionais;
  final int totalAtrasadas;

  AdminManutencaoKpisModel({
    required this.totalBloqueadas,
    required this.totalOperacionais,
    required this.totalAtrasadas,
  });

  factory AdminManutencaoKpisModel.fromJson(Map<String, dynamic> json) {
    return AdminManutencaoKpisModel(
      totalBloqueadas: json['totalBloqueadas'] ?? json['total_bloqueadas'] ?? 0,
      totalOperacionais: json['totalOperacionais'] ?? json['total_operacionais'] ?? 0,
      totalAtrasadas: json['totalAtrasadas'] ?? json['total_atrasadas'] ?? 0,
    );
  }
}

class AdminManutencaoModel {
  final int id;
  final String identificador;
  final String statusOperacional;
  final String? motivoManutencao;
  final String? previsaoRetorno;
  final int? manutencaoPorUsuarioId;
  final int baiaId;
  final String baiaNome;
  final int escritorioId;
  final String escritorioNome;
  final String escritorioCidade;
  final String? responsavelNome;
  final String? responsavelEmail;
  final String? dataBloqueio;

  AdminManutencaoModel({
    required this.id,
    required this.identificador,
    required this.statusOperacional,
    this.motivoManutencao,
    this.previsaoRetorno,
    this.manutencaoPorUsuarioId,
    required this.baiaId,
    required this.baiaNome,
    required this.escritorioId,
    required this.escritorioNome,
    required this.escritorioCidade,
    this.responsavelNome,
    this.responsavelEmail,
    this.dataBloqueio,
  });

  bool get isAtrasada {
    if (previsaoRetorno == null) return false;
    final dt = DateTime.tryParse(previsaoRetorno!);
    if (dt == null) return false;
    return dt.isBefore(DateTime.now());
  }

  factory AdminManutencaoModel.fromJson(Map<String, dynamic> json) {
    return AdminManutencaoModel(
      id: json['id'] as int,
      identificador: json['identificador'] as String? ?? '',
      statusOperacional: json['status_operacional'] as String? ?? 'DISPONIVEL',
      motivoManutencao: json['motivo_manutencao'] as String?,
      previsaoRetorno: json['previsao_retorno'] as String?,
      manutencaoPorUsuarioId: json['manutencao_por_usuario_id'] as int?,
      baiaId: json['baia_id'] as int? ?? 0,
      baiaNome: json['baia_nome'] as String? ?? '',
      escritorioId: json['escritorio_id'] as int? ?? 0,
      escritorioNome: json['escritorio_nome'] as String? ?? '',
      escritorioCidade: json['escritorio_cidade'] as String? ?? '',
      responsavelNome: json['responsavel_nome'] as String?,
      responsavelEmail: json['responsavel_email'] as String?,
      dataBloqueio: json['data_bloqueio'] as String?,
    );
  }
}

class AdminCadeiraOptionModel {
  final int id;
  final String identificador;
  final String statusOperacional;
  final String? motivoManutencao;
  final String? previsaoRetorno;
  final int baiaId;
  final String baiaNome;
  final int escritorioId;
  final String escritorioNome;
  final String escritorioCidade;

  AdminCadeiraOptionModel({
    required this.id,
    required this.identificador,
    required this.statusOperacional,
    this.motivoManutencao,
    this.previsaoRetorno,
    required this.baiaId,
    required this.baiaNome,
    required this.escritorioId,
    required this.escritorioNome,
    required this.escritorioCidade,
  });

  bool get isEmManutencao => statusOperacional == 'EM_MANUTENCAO';

  factory AdminCadeiraOptionModel.fromJson(Map<String, dynamic> json) {
    return AdminCadeiraOptionModel(
      id: json['id'] as int,
      identificador: json['identificador'] as String? ?? '',
      statusOperacional: json['status_operacional'] as String? ?? 'DISPONIVEL',
      motivoManutencao: json['motivo_manutencao'] as String?,
      previsaoRetorno: json['previsao_retorno'] as String?,
      baiaId: json['baia_id'] as int? ?? 0,
      baiaNome: json['baia_nome'] as String? ?? '',
      escritorioId: json['escritorio_id'] as int? ?? 0,
      escritorioNome: json['escritorio_nome'] as String? ?? '',
      escritorioCidade: json['escritorio_cidade'] as String? ?? '',
    );
  }
}

