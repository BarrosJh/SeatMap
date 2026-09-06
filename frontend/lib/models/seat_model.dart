import 'package:intl/intl.dart';

enum ReservaFiltro {
  todas,
  ativas,
  concluidas,
  canceladas,
  naoComparecidas,
}

class EscritorioModel {
  final int id;
  final String nome;
  final String cidade;

  EscritorioModel({
    required this.id,
    required this.nome,
    required this.cidade,
  });

  factory EscritorioModel.fromJson(Map<String, dynamic> json) {
    return EscritorioModel(
      id: json['id'] ?? 0,
      nome: json['nome'] ?? '',
      cidade: json['cidade'] ?? '',
    );
  }
}

class OcupanteModel {
  final int usuarioId;
  final String nome;
  final String? matricula;
  final String? perfil;
  final int? departamentoId;
  final String departamento;
  final bool checkinRealizado;
  final String? checkinEm;

  OcupanteModel({
    required this.usuarioId,
    required this.nome,
    this.matricula,
    this.perfil,
    this.departamentoId,
    required this.departamento,
    required this.checkinRealizado,
    this.checkinEm,
  });

  factory OcupanteModel.fromJson(Map<String, dynamic> json) {
    return OcupanteModel(
      usuarioId: json['usuarioId'] ?? 0,
      nome: json['nome'] ?? '',
      matricula: json['matricula'],
      perfil: json['perfil'],
      departamentoId: json['departamentoId'],
      departamento: json['departamento'] ?? '',
      checkinRealizado: json['checkinRealizado'] ?? false,
      checkinEm: json['checkinEm'],
    );
  }
}

class CadeiraModel {
  final int id;
  final String identificador;
  final int posicaoX;
  final int posicaoY;
  String status; // 'livre' | 'ocupada' | 'minha_reserva' | 'expirada'
  final int? reservaId;
  OcupanteModel? ocupante;

  CadeiraModel({
    required this.id,
    required this.identificador,
    required this.posicaoX,
    required this.posicaoY,
    required this.status,
    this.reservaId,
    this.ocupante,
  });

  bool get isLivre => status == 'livre';
  bool get isMinhaReserva => status == 'minha_reserva';
  bool get isOcupada => status == 'ocupada';
  bool get isExpirada => status == 'expirada';

  factory CadeiraModel.fromJson(Map<String, dynamic> json) {
    return CadeiraModel(
      id: json['id'] ?? 0,
      identificador: json['identificador'] ?? '',
      posicaoX: json['posicaoX'] ?? json['posicao_x'] ?? 0,
      posicaoY: json['posicaoY'] ?? json['posicao_y'] ?? 0,
      status: json['status'] ?? 'livre',
      reservaId: json['reservaId'] ?? json['reserva_id'],
      ocupante: json['ocupante'] != null ? OcupanteModel.fromJson(json['ocupante']) : null,
    );
  }
}

class BaiaModel {
  final int id;
  final String nome;
  final int totalCadeiras;
  final int totalOcupadas;
  final int totalLivres;
  final String resumoOcupacao;
  final List<CadeiraModel> cadeiras;

  BaiaModel({
    required this.id,
    required this.nome,
    required this.totalCadeiras,
    required this.totalOcupadas,
    required this.totalLivres,
    required this.resumoOcupacao,
    required this.cadeiras,
  });

  factory BaiaModel.fromJson(Map<String, dynamic> json) {
    final list = json['cadeiras'] as List? ?? [];
    return BaiaModel(
      id: json['id'] ?? 0,
      nome: json['nome'] ?? '',
      totalCadeiras: json['totalCadeiras'] ?? 0,
      totalOcupadas: json['totalOcupadas'] ?? 0,
      totalLivres: json['totalLivres'] ?? 0,
      resumoOcupacao: json['resumoOcupacao'] ?? '',
      cadeiras: list.map((c) => CadeiraModel.fromJson(c)).toList(),
    );
  }
}

class MapaDataModel {
  final EscritorioModel escritorio;
  final String data;
  final List<BaiaModel> baias;

  MapaDataModel({
    required this.escritorio,
    required this.data,
    required this.baias,
  });

  factory MapaDataModel.fromJson(Map<String, dynamic> json) {
    final list = json['baias'] as List? ?? [];
    return MapaDataModel(
      escritorio: EscritorioModel.fromJson(json['escritorio'] ?? {}),
      data: json['data'] ?? '',
      baias: list.map((b) => BaiaModel.fromJson(b)).toList(),
    );
  }
}

class ReservaModel {
  final int id;
  final String dataReserva;
  final bool checkinRealizado;
  final String? checkinEm;
  final String status;
  final String? criadoEm;
  final int cadeiraId;
  final String cadeiraIdentificador;
  final int baiaId;
  final String baiaNome;
  final int escritorioId;
  final String escritorioNome;
  final String escritorioCidade;
  final String? codigoComprovante;

  ReservaModel({
    required this.id,
    required this.dataReserva,
    required this.checkinRealizado,
    this.checkinEm,
    required this.status,
    this.criadoEm,
    required this.cadeiraId,
    required this.cadeiraIdentificador,
    required this.baiaId,
    required this.baiaNome,
    required this.escritorioId,
    required this.escritorioNome,
    required this.escritorioCidade,
    this.codigoComprovante,
  });

  bool get isPassada {
    final hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return dataReserva.compareTo(hojeStr) < 0;
  }

  bool get isHoje {
    final hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return dataReserva == hojeStr;
  }

  bool get isAtiva => status == 'ATIVA' && !isNoShowPassado;
  bool get isCancelada => status == 'CANCELADA';
  bool get isExpirada => status == 'EXPIRADA_NOSHOW' || isNoShowPassado;
  bool get isNoShowPassado => status == 'ATIVA' && !checkinRealizado && isPassada;
  bool get isConcluida => (checkinRealizado && isPassada) || status == 'CONCLUIDA';

  factory ReservaModel.fromJson(Map<String, dynamic> json) {
    return ReservaModel(
      id: json['id'] ?? 0,
      dataReserva: json['data_reserva'] ?? json['dataReserva'] ?? '',
      checkinRealizado: json['checkin_realizado'] ?? json['checkinRealizado'] ?? false,
      checkinEm: json['checkin_em'] ?? json['checkinEm'],
      status: json['status'] ?? 'ATIVA',
      criadoEm: json['criado_em'] ?? json['criadoEm'],
      cadeiraId: json['cadeira_id'] ?? json['cadeiraId'] ?? 0,
      cadeiraIdentificador: json['cadeira_identificador'] ?? json['cadeiraIdentificador'] ?? '',
      baiaId: json['baia_id'] ?? json['baiaId'] ?? 0,
      baiaNome: json['baia_nome'] ?? json['baiaNome'] ?? '',
      escritorioId: json['escritorio_id'] ?? json['escritorioId'] ?? 0,
      escritorioNome: json['escritorio_nome'] ?? json['escritorioNome'] ?? '',
      escritorioCidade: json['escritorio_cidade'] ?? json['escritorioCidade'] ?? '',
      codigoComprovante: json['codigo_comprovante'] ?? json['codigoComprovante'],
    );
  }
}

class OcupacaoDiaModel {
  final String data;
  final String diaSemana;
  final String diaCurto;
  final String dataFormatada;
  final int totalCadeiras;
  final int totalReservas;
  final int livres;
  final int percentual;

  OcupacaoDiaModel({
    required this.data,
    required this.diaSemana,
    required this.diaCurto,
    required this.dataFormatada,
    required this.totalCadeiras,
    required this.totalReservas,
    required this.livres,
    required this.percentual,
  });

  factory OcupacaoDiaModel.fromJson(Map<String, dynamic> json) {
    return OcupacaoDiaModel(
      data: json['data'] ?? '',
      diaSemana: json['diaSemana'] ?? '',
      diaCurto: json['diaCurto'] ?? '',
      dataFormatada: json['dataFormatada'] ?? '',
      totalCadeiras: json['totalCadeiras'] ?? 0,
      totalReservas: json['totalReservas'] ?? 0,
      livres: json['livres'] ?? 0,
      percentual: json['percentual'] ?? 0,
    );
  }
}

class OcupacaoEscritorioModel {
  final int id;
  final String nome;
  final String cidade;
  final int totalCadeiras;
  final int mediaOcupacaoAtual;
  final bool proximaSemanaAberta;
  final String? mensagemBloqueioProximaSemana;
  final List<OcupacaoDiaModel> semanaAtual;
  final List<OcupacaoDiaModel> proximaSemana;

  OcupacaoEscritorioModel({
    required this.id,
    required this.nome,
    required this.cidade,
    required this.totalCadeiras,
    required this.mediaOcupacaoAtual,
    this.proximaSemanaAberta = false,
    this.mensagemBloqueioProximaSemana,
    required this.semanaAtual,
    required this.proximaSemana,
  });

  factory OcupacaoEscritorioModel.fromJson(Map<String, dynamic> json) {
    final sAtual = (json['semanaAtual'] as List<dynamic>? ?? [])
        .map((e) => OcupacaoDiaModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final sProx = (json['proximaSemana'] as List<dynamic>? ?? [])
        .map((e) => OcupacaoDiaModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return OcupacaoEscritorioModel(
      id: json['id'] ?? 0,
      nome: json['nome'] ?? '',
      cidade: json['cidade'] ?? '',
      totalCadeiras: json['totalCadeiras'] ?? 0,
      mediaOcupacaoAtual: json['mediaOcupacaoAtual'] ?? 0,
      proximaSemanaAberta: json['proximaSemanaAberta'] ?? false,
      mensagemBloqueioProximaSemana: json['mensagemBloqueioProximaSemana'],
      semanaAtual: sAtual,
      proximaSemana: sProx,
    );
  }
}


