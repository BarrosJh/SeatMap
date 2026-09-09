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
  String status; // 'livre' | 'ocupada' | 'minha_reserva' | 'expirada' | 'manutencao'
  final String statusOperacional; // 'DISPONIVEL' | 'EM_MANUTENCAO'
  final String? motivoManutencao;
  final String? previsaoRetorno;
  final int? reservaId;
  OcupanteModel? ocupante;

  CadeiraModel({
    required this.id,
    required this.identificador,
    required this.posicaoX,
    required this.posicaoY,
    required this.status,
    this.statusOperacional = 'DISPONIVEL',
    this.motivoManutencao,
    this.previsaoRetorno,
    this.reservaId,
    this.ocupante,
  });

  bool get isLivre => status == 'livre' && !isManutencao;
  bool get isMinhaReserva => status == 'minha_reserva';
  bool get isOcupada => status == 'ocupada';
  bool get isExpirada => status == 'expirada';
  bool get isManutencao => status == 'manutencao' || statusOperacional == 'EM_MANUTENCAO';

  factory CadeiraModel.fromJson(Map<String, dynamic> json) {
    return CadeiraModel(
      id: json['id'] ?? 0,
      identificador: json['identificador'] ?? '',
      posicaoX: json['posicaoX'] ?? json['posicao_x'] ?? 0,
      posicaoY: json['posicaoY'] ?? json['posicao_y'] ?? 0,
      status: json['status'] ?? 'livre',
      statusOperacional: json['statusOperacional'] ?? json['status_operacional'] ?? 'DISPONIVEL',
      motivoManutencao: json['motivoManutencao'] ?? json['motivo_manutencao'],
      previsaoRetorno: json['previsaoRetorno'] ?? json['previsao_retorno'],
      reservaId: json['reservaId'] ?? json['reserva_id'],
      ocupante: json['ocupante'] != null ? OcupanteModel.fromJson(json['ocupante']) : null,
    );
  }
}

class HistoricoReservaModel {
  final int id;
  final int? reservaId;
  final int cadeiraId;
  final int? usuarioId;
  final String dataReserva;
  final String tipoEvento;
  final int? executadoPorUsuarioId;
  final String? motivo;
  final Map<String, dynamic>? detalhes;
  final String criadoEm;
  final String? usuarioNome;
  final String? usuarioEmail;
  final String? usuarioMatricula;
  final String? departamentoNome;
  final String? executadoPorNome;
  final String? cadeiraIdentificador;
  final String? baiaNome;
  final String? escritorioNome;

  HistoricoReservaModel({
    required this.id,
    this.reservaId,
    required this.cadeiraId,
    this.usuarioId,
    required this.dataReserva,
    required this.tipoEvento,
    this.executadoPorUsuarioId,
    this.motivo,
    this.detalhes,
    required this.criadoEm,
    this.usuarioNome,
    this.usuarioEmail,
    this.usuarioMatricula,
    this.departamentoNome,
    this.executadoPorNome,
    this.cadeiraIdentificador,
    this.baiaNome,
    this.escritorioNome,
  });

  factory HistoricoReservaModel.fromJson(Map<String, dynamic> json) {
    return HistoricoReservaModel(
      id: json['id'] ?? 0,
      reservaId: json['reserva_id'] ?? json['reservaId'],
      cadeiraId: json['cadeira_id'] ?? json['cadeiraId'] ?? 0,
      usuarioId: json['usuario_id'] ?? json['usuarioId'],
      dataReserva: json['data_reserva'] ?? json['dataReserva'] ?? '',
      tipoEvento: json['tipo_evento'] ?? json['tipoEvento'] ?? '',
      executadoPorUsuarioId: json['executado_por_usuario_id'] ?? json['executadoPorUsuarioId'],
      motivo: json['motivo'],
      detalhes: json['detalhes'] is Map<String, dynamic> ? json['detalhes'] : null,
      criadoEm: json['criado_em'] ?? json['criadoEm'] ?? '',
      usuarioNome: json['usuario_nome'] ?? json['usuarioNome'],
      usuarioEmail: json['usuario_email'] ?? json['usuarioEmail'],
      usuarioMatricula: json['usuario_matricula'] ?? json['usuarioMatricula'],
      departamentoNome: json['departamento_nome'] ?? json['departamentoNome'],
      executadoPorNome: json['executado_por_nome'] ?? json['executadoPorNome'],
      cadeiraIdentificador: json['cadeira_identificador'] ?? json['cadeiraIdentificador'],
      baiaNome: json['baia_nome'] ?? json['baiaNome'],
      escritorioNome: json['escritorio_nome'] ?? json['escritorioNome'],
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
  final String? checkoutEm;
  final String? limiteCheckin;
  final String? limiteFormatado;
  final bool? isReservaTardiaBackend;
  final String? modalidadeCheckinBackend;

  ReservaModel({
    required this.id,
    required this.dataReserva,
    required this.checkinRealizado,
    this.checkinEm,
    this.checkoutEm,
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
    this.limiteCheckin,
    this.limiteFormatado,
    this.isReservaTardiaBackend,
    this.modalidadeCheckinBackend,
  });

  String get dataReservaIso => dataReserva.contains('T') ? dataReserva.split('T')[0] : dataReserva;

  DateTime? get dataReservaDateTime => DateTime.tryParse(dataReservaIso);

  DateTime? get criadoEmDateTime {
    if (criadoEm == null || criadoEm!.isEmpty) return null;
    return DateTime.tryParse(criadoEm!)?.toLocal();
  }

  /// Identifica se a reserva entrou como Reserva Tardia (Tempo Remanescente de 2h)
  /// ou como Horário Fixo (limite às 11h00).
  bool get isReservaTardia {
    if (isReservaTardiaBackend != null) return isReservaTardiaBackend!;
    if (!isHoje) return false;
    final dtCriado = criadoEmDateTime;
    if (dtCriado == null) return false;
    // Ponto de início de reserva tardia no mesmo dia: >= 10:00
    return dtCriado.hour >= 10;
  }

  String get modalidadeCheckin {
    if (modalidadeCheckinBackend != null && modalidadeCheckinBackend!.isNotEmpty) {
      if (modalidadeCheckinBackend == 'TEMPO_REMANESCENTE' || modalidadeCheckinBackend == 'RESERVA_TARDIA') {
        return 'Tempo Remanescente';
      }
      if (modalidadeCheckinBackend == 'HORARIO_FIXO') {
        return 'Horário Fixo';
      }
      return modalidadeCheckinBackend!;
    }
    return isReservaTardia ? 'Tempo Remanescente' : 'Horário Fixo';
  }

  String get modalidadeCheckinDescricao {
    if (isReservaTardia) {
      return 'Tolerância dinâmica de 2h a partir da reserva';
    }
    return 'Horário de corte padrão às 11h00';
  }

  DateTime get limiteCheckinDateTime {
    if (limiteCheckin != null && limiteCheckin!.isNotEmpty) {
      final parsed = DateTime.tryParse(limiteCheckin!);
      if (parsed != null) return parsed.toLocal();
    }

    final dtRes = dataReservaDateTime ?? DateTime.now();

    if (isReservaTardia) {
      final dtCriado = criadoEmDateTime ?? DateTime.now();
      final limiteEstendido = dtCriado.add(const Duration(minutes: 120));
      final limitePadrao = DateTime(dtRes.year, dtRes.month, dtRes.day, 11, 0, 0);
      final fimDoDia = DateTime(dtRes.year, dtRes.month, dtRes.day, 23, 59, 59);
      final limiteFinal = limiteEstendido.isAfter(limitePadrao) ? limiteEstendido : limitePadrao;
      return limiteFinal.isAfter(fimDoDia) ? fimDoDia : limiteFinal;
    }

    return DateTime(dtRes.year, dtRes.month, dtRes.day, 11, 0, 0);
  }

  String get limiteCheckinFormatado {
    if (limiteFormatado != null && limiteFormatado!.isNotEmpty) {
      return limiteFormatado!;
    }
    return DateFormat('HH:mm').format(limiteCheckinDateTime);
  }

  Duration get tempoRestanteCheckin {
    final agora = DateTime.now();
    final limite = limiteCheckinDateTime;
    return limite.difference(agora);
  }

  String get tempoRestanteFormatado {
    if (checkinRealizado) return 'Confirmado';
    final diff = tempoRestanteCheckin;
    if (diff.isNegative) return 'Expirado';
    if (diff.inHours > 0) {
      final mins = diff.inMinutes.remainder(60);
      return '${diff.inHours}h ${mins > 0 ? '${mins}min' : ''}'.trim();
    }
    return '${diff.inMinutes} min';
  }

  String get dataFormatadaExtenso {
    final dt = dataReservaDateTime;
    if (dt == null) return dataReserva;
    final formatado = DateFormat("EEEE, d 'de' MMMM 'de' yyyy", 'pt_BR').format(dt);
    if (formatado.isEmpty) return dataReserva;
    return formatado[0].toUpperCase() + formatado.substring(1);
  }

  String get dataFormatadaCurta {
    final dt = dataReservaDateTime;
    if (dt == null) return dataReserva;
    return DateFormat('dd/MM/yyyy', 'pt_BR').format(dt);
  }

  String get diaSemanaExtenso {
    final dt = dataReservaDateTime;
    if (dt == null) return '';
    final formatado = DateFormat('EEEE', 'pt_BR').format(dt);
    return formatado.isNotEmpty ? formatado[0].toUpperCase() + formatado.substring(1) : '';
  }

  String get diaSemanaCurto {
    final dt = dataReservaDateTime;
    if (dt == null) return '';
    return DateFormat('E', 'pt_BR').format(dt).toUpperCase();
  }

  bool get isPassada {
    final hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return dataReservaIso.compareTo(hojeStr) < 0;
  }

  bool get isHoje {
    final hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return dataReservaIso == hojeStr;
  }

  bool get isAmanha {
    final amanhaStr = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)));
    return dataReservaIso == amanhaStr;
  }

  bool get isOntem {
    final ontemStr = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
    return dataReservaIso == ontemStr;
  }

  String get tagRelativa {
    if (isHoje) return 'Hoje';
    if (isAmanha) return 'Amanhã';
    if (isOntem) return 'Ontem';
    if (isPassada) return 'Passada';
    return 'Futura';
  }

  bool get isAtiva => status == 'ATIVA' && !isNoShowPassado;
  bool get isCancelada => status == 'CANCELADA';
  bool get isExpirada => status == 'EXPIRADA_NOSHOW' || isNoShowPassado;
  bool get isNoShowPassado => status == 'ATIVA' && !checkinRealizado && isPassada;
  bool get isConcluida => status == 'CONCLUIDA' || (checkinRealizado && isPassada);

  factory ReservaModel.fromJson(Map<String, dynamic> json) {
    final rawData = json['data_reserva'] ?? json['dataReserva'] ?? '';
    final cleanData = rawData.toString().contains('T')
        ? rawData.toString().split('T')[0]
        : rawData.toString();

    return ReservaModel(
      id: json['id'] ?? 0,
      dataReserva: cleanData,
      checkinRealizado: json['checkin_realizado'] ?? json['checkinRealizado'] ?? false,
      checkinEm: json['checkin_em'] ?? json['checkinEm'],
      checkoutEm: json['checkout_em'] ?? json['checkoutEm'],
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
      limiteCheckin: json['limite_checkin'] ?? json['limiteCheckin'],
      limiteFormatado: json['limite_formatado'] ?? json['limiteFormatado'],
      isReservaTardiaBackend: json['is_reserva_tardia'] ?? json['isReservaTardia'],
      modalidadeCheckinBackend: json['modalidade_checkin'] ?? json['modalidadeCheckin'],
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


