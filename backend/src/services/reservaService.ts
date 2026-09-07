import { DateTime } from 'luxon';
import crypto from 'crypto';
import pool from '../config/db';
import { ConfigService } from './configService';
import { EmailService } from './emailService';
import { ReservaHistoryService } from './reservaHistoryService';
import { wsManager } from '../websocket/wsServer';
import { getWorkWeekDiff, isProximaSemanaLiberada, normalizeIsoDate } from '../utils/workWeekUtils';
import { logger } from '../utils/logger';

export interface CriarReservaInput {
  usuarioId: number;
  usuarioNome: string;
  usuarioEmail: string;
  usuarioPerfil: string;
  departamentoId?: number | null;
  departamentoNome?: string | null;
  cadeiraId: number;
  dataReserva: string;
  idempotencyKey?: string;
  correlationId?: string;
}

export interface CheckinInput {
  reservaId: number;
  usuarioId: number;
  usuarioPerfil: string;
  usuarioDepartamentoId?: number | null;
  isRhGlobal?: boolean;
  cadeiraIdInformada?: number;
  correlationId?: string;
}

export class ReservaService {
  /**
   * Processa a criação ou troca atômica de reserva com locks, idempotência e notificações
   */
  public static async criarReserva(input: CriarReservaInput) {
    const {
      usuarioId,
      usuarioNome,
      usuarioEmail,
      usuarioPerfil,
      departamentoId,
      departamentoNome,
      cadeiraId,
      dataReserva,
      idempotencyKey,
      correlationId
    } = input;

    const dataLuxon = DateTime.fromISO(dataReserva, { zone: 'America/Sao_Paulo' });
    if (!dataLuxon.isValid) {
      return { success: false, code: 400, error: 'Data de reserva inválida. Utilize o formato YYYY-MM-DD.' };
    }

    const hoje = DateTime.now().setZone('America/Sao_Paulo').startOf('day');
    const dataAlvo = dataLuxon.startOf('day');
    const dataAlvoIso = dataAlvo.toISODate()!;

    if (dataAlvo < hoje) {
      return { success: false, code: 400, error: 'Não é permitido realizar reservas para datas passadas.' };
    }

    // Bloqueio de finais de semana
    if (dataLuxon.weekday === 6 || dataLuxon.weekday === 7) {
      return { success: false, code: 400, error: 'Não há expediente aos finais de semana. Selecione um dia útil (Segunda a Sexta).' };
    }

    const diffSemanas = getWorkWeekDiff(dataAlvo, hoje);
    if (diffSemanas > 1) {
      return { success: false, code: 400, error: 'Só é permitido reservar assentos para a semana corrente ou a semana seguinte.' };
    }

    if (diffSemanas === 1) {
      const statusAbertura = await isProximaSemanaLiberada(usuarioPerfil, DateTime.now().setZone('America/Sao_Paulo'));
      if (!statusAbertura.liberada) {
        return {
          success: false,
          code: 403,
          error: statusAbertura.mensagemBloqueio || 'A agenda da próxima semana ainda não foi aberta.'
        };
      }
    }

    const limiteAtivas = await ConfigService.getNumber('LIMITE_SEMANAL_RESERVAS', 2);
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      const cadeiraRes = await client.query(`
        SELECT c.id, c.identificador, c.ativa, c.status_operacional, c.motivo_manutencao, c.previsao_retorno, b.id AS baia_id, b.nome AS baia_nome, b.escritorio_id
        FROM cadeiras c
        JOIN baias b ON c.baia_id = b.id
        WHERE c.id = $1 AND c.ativa = true
        FOR UPDATE
      `, [cadeiraId]);

      if (cadeiraRes.rowCount === 0) {
        await client.query('ROLLBACK');
        return { success: false, code: 404, error: 'Cadeira selecionada não existe ou está inativa.' };
      }
      const cadeira = cadeiraRes.rows[0];

      if (cadeira.status_operacional === 'EM_MANUTENCAO') {
        await client.query('ROLLBACK');
        const prevMsg = cadeira.previsao_retorno 
          ? ` Previsão de liberação: ${DateTime.fromJSDate(new Date(cadeira.previsao_retorno)).setZone('America/Sao_Paulo').toFormat('dd/MM/yyyy HH:mm')}.` 
          : '';
        return {
          success: false,
          code: 400,
          error: `Este assento está temporariamente indisponível para manutenção (${cadeira.motivo_manutencao || 'Defeito técnico'}).${prevMsg}`
        };
      }

      const cadeiraOcupadaRes = await client.query(`
        SELECT id, usuario_id FROM reservas
        WHERE cadeira_id = $1 AND data_reserva = $2 AND status = 'ATIVA'
      `, [cadeiraId, dataAlvoIso]);

      if (cadeiraOcupadaRes.rowCount! > 0 && cadeiraOcupadaRes.rows[0].usuario_id !== usuarioId) {
        await client.query('ROLLBACK');
        return { success: false, code: 409, error: 'Este assento acabou de ser reservado por outro colaborador.' };
      }

      const reservaExistenteDiaRes = await client.query(`
        SELECT r.id, r.cadeira_id, b.escritorio_id, c.identificador
        FROM reservas r
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        WHERE r.usuario_id = $1 AND r.data_reserva = $2 AND r.status = 'ATIVA'
        FOR UPDATE
      `, [usuarioId, dataAlvoIso]);

      const isTroca = reservaExistenteDiaRes.rowCount! > 0;
      const reservaAntiga = isTroca ? reservaExistenteDiaRes.rows[0] : null;

      if (isTroca && reservaAntiga.cadeira_id === cadeiraId) {
        await client.query('COMMIT');
        return {
          success: true,
          code: 200,
          message: 'Você já possui este assento reservado.',
          reservaId: reservaAntiga.id
        };
      }

      if (isTroca) {
        const permitirTroca = (await ConfigService.get('PERMITIR_TROCA_MESMO_DIA', 'true')) === 'true';
        if (!permitirTroca) {
          await client.query('ROLLBACK');
          return { success: false, code: 400, error: 'A troca de assento no mesmo dia está desabilitada pela política de RH.' };
        }
      }

      if (!isTroca) {
        const contagemAtivasRes = await client.query(`
          SELECT COUNT(*) AS total
          FROM reservas
          WHERE usuario_id = $1
            AND status = 'ATIVA'
            AND data_reserva >= CURRENT_DATE
        `, [usuarioId]);

        const totalAtivas = parseInt(contagemAtivasRes.rows[0].total, 10);
        if (totalAtivas >= limiteAtivas) {
          await client.query('ROLLBACK');
          return {
            success: false,
            code: 400,
            error: `Limite de ${limiteAtivas} reservas ativas atingido.`
          };
        }
      }

      const timestampIso = new Date().toISOString();
      const rawPayload = `${usuarioId}-${cadeiraId}-${dataAlvoIso}-${timestampIso}-${idempotencyKey || ''}`;
      const codigoComprovante = 'RES-' + crypto.createHash('sha256').update(rawPayload).digest('hex').substring(0, 16).toUpperCase();

      const checkinAutoGestao = (await ConfigService.get('CHECKIN_AUTOMATICO_GESTAO', 'true')) === 'true';
      const isGestao = usuarioPerfil === 'GESTAO';
      const checkinRealizado = isGestao && checkinAutoGestao;
      const checkinEm = checkinRealizado ? new Date() : null;

      let novaReserva: any;
      if (isTroca && reservaAntiga) {
        const updateRes = await client.query(`
          UPDATE reservas
          SET cadeira_id = $1, checkin_realizado = $2, checkin_em = $3, status = 'ATIVA', codigo_comprovante = $4
          WHERE id = $5
          RETURNING id, cadeira_id, usuario_id, data_reserva, checkin_realizado, checkin_em, status, codigo_comprovante, criado_em
        `, [cadeiraId, checkinRealizado, checkinEm, codigoComprovante, reservaAntiga.id]);
        novaReserva = updateRes.rows[0];
      } else {
        const insertRes = await client.query(`
          INSERT INTO reservas (cadeira_id, usuario_id, data_reserva, checkin_realizado, checkin_em, status, codigo_comprovante)
          VALUES ($1, $2, $3, $4, $5, 'ATIVA', $6)
          RETURNING id, cadeira_id, usuario_id, data_reserva, checkin_realizado, checkin_em, status, codigo_comprovante, criado_em
        `, [cadeiraId, usuarioId, dataAlvoIso, checkinRealizado, checkinEm, codigoComprovante]);
        novaReserva = insertRes.rows[0];
      }

      await ReservaHistoryService.registrarEvento({
        reservaId: novaReserva.id,
        cadeiraId: cadeira.id,
        usuarioId,
        dataReserva: dataAlvoIso,
        tipoEvento: isTroca ? 'TROCADA' : 'CRIADA',
        executadoPorUsuarioId: usuarioId,
        motivo: isTroca ? `Troca atômica de assento (Mesa ${reservaAntiga?.identificador} -> Mesa ${cadeira.identificador})` : 'Reserva de assento efetuada',
        detalhes: {
          codigoComprovante,
          escritorioId: cadeira.escritorio_id,
          cadeiraAntigaId: reservaAntiga?.cadeira_id || null,
          cadeiraAntigaIdentificador: reservaAntiga?.identificador || null,
          checkinAutomatico: checkinRealizado
        }
      }, client);

      await client.query('COMMIT');

      wsManager.broadcastSeatUpdate({
        evento: 'assento_atualizado',
        escritorioId: cadeira.escritorio_id,
        cadeiraId: cadeira.id,
        data: dataAlvoIso,
        status: 'ocupada',
        ocupante: {
          nome: usuarioNome,
          departamento: departamentoNome || 'Colaborador',
          departamentoId: departamentoId || undefined
        }
      });

      if (isTroca && reservaAntiga) {
        wsManager.broadcastSeatUpdate({
          evento: 'assento_atualizado',
          escritorioId: reservaAntiga.escritorio_id,
          cadeiraId: reservaAntiga.cadeira_id,
          data: dataAlvoIso,
          status: 'livre',
          ocupante: null
        });
      }

      return {
        success: true,
        code: 201,
        message: isTroca ? 'Troca de assento realizada com sucesso!' : 'Reserva realizada com sucesso!',
        comprovante: codigoComprovante,
        reserva: novaReserva,
        trocaRealizada: isTroca
      };
    } catch (error: any) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackErr) {
        logger.error('[ReservaService] Falha ao executar ROLLBACK:', { correlationId, error: rollbackErr });
      }

      if (error.code === '23505') {
        if (error.constraint === 'unq_cadeira_data' || error.constraint === 'unq_cadeira_data_ativa') {
          return {
            success: false,
            code: 409,
            error: 'Conflito de Concorrência: Este assento acabou de ser reservado por outro usuário para a mesma data.'
          };
        }
        if (error.constraint === 'unq_usuario_data' || error.constraint === 'unq_usuario_data_ativa') {
          return {
            success: false,
            code: 409,
            error: 'Conflito: Você já possui uma reserva ativa para esta mesma data.'
          };
        }
      }

      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Processa o check-in de presença em uma reserva com validação de BOLA, horários e QR
   */
  public static async fazerCheckin(input: CheckinInput) {
    const {
      reservaId,
      usuarioId,
      usuarioPerfil,
      usuarioDepartamentoId,
      isRhGlobal,
      cadeiraIdInformada,
      correlationId
    } = input;

    const reservaRes = await pool.query(`
      SELECT 
        r.id, 
        r.usuario_id, 
        r.data_reserva, 
        r.checkin_realizado, 
        r.checkin_em, 
        r.status, 
        r.codigo_comprovante, 
        r.cadeira_id, 
        c.identificador AS cadeira_identificador, 
        b.id AS baia_id, 
        b.nome AS baia_nome, 
        e.id AS escritorio_id, 
        e.nome AS escritorio_nome, 
        e.cidade AS escritorio_cidade, 
        u.nome AS usuario_nome, 
        u.matricula AS usuario_matricula, 
        u.departamento_id AS departamento_id, 
        d.nome AS departamento_nome
      FROM reservas r
      JOIN cadeiras c ON r.cadeira_id = c.id
      JOIN baias b ON c.baia_id = b.id
      JOIN escritorios e ON b.escritorio_id = e.id
      JOIN usuarios u ON r.usuario_id = u.id
      LEFT JOIN departamentos d ON u.departamento_id = d.id
      WHERE r.id = $1
    `, [reservaId]);

    if (reservaRes.rowCount === 0) {
      return { success: false, code: 404, error: 'Reserva não encontrada.' };
    }

    const reserva = reservaRes.rows[0];

    if (cadeiraIdInformada && cadeiraIdInformada !== reserva.cadeira_id) {
      return {
        success: false,
        code: 400,
        error: `QR Code inválido: este código pertence à mesa ${cadeiraIdInformada}, mas sua reserva é na mesa ${reserva.cadeira_identificador}.`
      };
    }

    const isOwner = reserva.usuario_id === usuarioId;
    const isGestorDoMesmoDepartamento = usuarioPerfil === 'GESTAO' && usuarioDepartamentoId != null && reserva.departamento_id === usuarioDepartamentoId;

    if (!isOwner && !isRhGlobal && !isGestorDoMesmoDepartamento) {
      if (usuarioPerfil === 'GESTAO') {
        return { success: false, code: 403, error: 'Gestores só possuem permissão para realizar check-in de colaboradores do seu próprio departamento.' };
      }
      return { success: false, code: 403, error: 'Você não tem permissão para realizar check-in nesta reserva.' };
    }

    if (reserva.status !== 'ATIVA') {
      return { success: false, code: 400, error: `Não é possível realizar check-in em uma reserva com status ${reserva.status}.` };
    }

    const checkinHoraAtual = new Date().toISOString();
    const dataReservaIso = normalizeIsoDate(reserva.data_reserva);

    if (reserva.checkin_realizado) {
      return {
        success: true,
        code: 200,
        message: 'Check-in já havia sido realizado anteriormente.',
        comprovante: reserva.codigo_comprovante,
        checkinEm: reserva.checkin_em || checkinHoraAtual,
        reserva: {
          id: reserva.id,
          dataReserva: dataReservaIso,
          cadeiraId: reserva.cadeira_id,
          cadeiraIdentificador: reserva.cadeira_identificador,
          baiaNome: reserva.baia_nome,
          escritorioNome: reserva.escritorio_nome,
          escritorioCidade: reserva.escritorio_cidade,
          usuarioNome: reserva.usuario_nome,
          usuarioMatricula: reserva.usuario_matricula,
          codigoComprovante: reserva.codigo_comprovante,
          checkinEm: reserva.checkin_em || checkinHoraAtual
        }
      };
    }

    const hoje = DateTime.now().setZone('America/Sao_Paulo').startOf('day');
    const dataReservaLuxon = DateTime.fromISO(dataReservaIso, { zone: 'America/Sao_Paulo' }).startOf('day');

    if (!hoje.equals(dataReservaLuxon)) {
      return { success: false, code: 400, error: 'O check-in só pode ser realizado no dia da reserva.' };
    }

    const agora = DateTime.now().setZone('America/Sao_Paulo');
    const horarioInicio = await ConfigService.get('HORARIO_INICIO_CHECKIN', '06:00');
    const horarioLimite = await ConfigService.get('HORARIO_LIMITE_CHECKIN', '11:00');
    const [horaInicioH, horaInicioM] = horarioInicio.split(':').map(Number);
    const [horaLimiteH, horaLimiteM] = horarioLimite.split(':').map(Number);
    const inicioCheckinHoje = agora.set({ hour: horaInicioH, minute: horaInicioM, second: 0, millisecond: 0 });
    const limiteCheckinHoje = agora.set({ hour: horaLimiteH, minute: horaLimiteM, second: 0, millisecond: 0 });

    if (agora < inicioCheckinHoje) {
      return { success: false, code: 400, error: `O check-in diário só está liberado a partir das ${horarioInicio}.` };
    }

    if (agora > limiteCheckinHoje) {
      return { success: false, code: 400, error: `O horário limite para check-in encerrou às ${horarioLimite}.` };
    }

    await pool.query(`
      UPDATE reservas 
      SET checkin_realizado = true, checkin_em = $1 
      WHERE id = $2
    `, [checkinHoraAtual, reservaId]);

    await ReservaHistoryService.registrarEvento({
      reservaId: reserva.id,
      cadeiraId: reserva.cadeira_id,
      usuarioId,
      dataReserva: dataReservaIso,
      tipoEvento: 'CHECKIN',
      executadoPorUsuarioId: usuarioId,
      motivo: usuarioId === reserva.usuario_id ? 'Check-in de presença realizado pelo colaborador' : 'Check-in administrativo validado pela Gestão/RH',
      detalhes: {
        checkinEm: checkinHoraAtual,
        comprovante: reserva.codigo_comprovante
      }
    });

    wsManager.broadcastSeatUpdate({
      evento: 'assento_atualizado',
      escritorioId: reserva.escritorio_id,
      cadeiraId: reserva.cadeira_id,
      data: dataReservaIso,
      status: 'ocupada',
      ocupante: {
        nome: reserva.usuario_nome,
        departamento: reserva.departamento_nome || 'Sem Departamento'
      }
    });

    return {
      success: true,
      code: 200,
      message: 'Presença confirmada com sucesso! Bom trabalho.',
      comprovante: reserva.codigo_comprovante,
      checkinEm: checkinHoraAtual,
      reserva: {
        id: reserva.id,
        dataReserva: dataReservaIso,
        cadeiraId: reserva.cadeira_id,
        cadeiraIdentificador: reserva.cadeira_identificador,
        baiaNome: reserva.baia_nome,
        escritorioNome: reserva.escritorio_nome,
        escritorioCidade: reserva.escritorio_cidade,
        usuarioNome: reserva.usuario_nome,
        usuarioMatricula: reserva.usuario_matricula,
        codigoComprovante: reserva.codigo_comprovante,
        checkinEm: checkinHoraAtual
      }
    };
  }

  /**
   * Cancela uma reserva ativa do usuário
   */
  public static async cancelarReserva(reservaId: number, usuarioId: number) {
    const result = await pool.query(`
      SELECT 
        r.id, 
        r.usuario_id, 
        r.cadeira_id, 
        r.data_reserva, 
        r.status, 
        r.codigo_comprovante, 
        b.escritorio_id, 
        c.identificador AS cadeira_identificador
      FROM reservas r
      JOIN cadeiras c ON r.cadeira_id = c.id
      JOIN baias b ON c.baia_id = b.id
      WHERE r.id = $1
    `, [reservaId]);

    if (result.rowCount === 0) {
      return { success: false, code: 404, error: 'Reserva não encontrada.' };
    }

    const reserva = result.rows[0];

    if (reserva.usuario_id !== usuarioId) {
      return { success: false, code: 403, error: 'Você só pode cancelar suas próprias reservas.' };
    }

    if (reserva.status !== 'ATIVA') {
      return { success: false, code: 400, error: `Não é possível cancelar uma reserva com status ${reserva.status}.` };
    }

    const dataReservaIso = normalizeIsoDate(reserva.data_reserva);
    const dataReservaLuxon = DateTime.fromISO(dataReservaIso, { zone: 'America/Sao_Paulo' }).startOf('day');
    const hoje = DateTime.now().setZone('America/Sao_Paulo').startOf('day');

    if (dataReservaLuxon < hoje) {
      return { success: false, code: 400, error: 'Não é possível cancelar reservas de datas passadas.' };
    }

    await pool.query(`
      UPDATE reservas 
      SET status = 'CANCELADA' 
      WHERE id = $1
    `, [reservaId]);

    await ReservaHistoryService.registrarEvento({
      reservaId: reserva.id,
      cadeiraId: reserva.cadeira_id,
      usuarioId,
      dataReserva: dataReservaIso,
      tipoEvento: 'CANCELADA_USUARIO',
      executadoPorUsuarioId: usuarioId,
      detalhes: {
        comprovante: reserva.codigo_comprovante,
        cadeiraIdentificador: reserva.cadeira_identificador
      }
    });

    wsManager.broadcastSeatUpdate({
      evento: 'assento_atualizado',
      escritorioId: reserva.escritorio_id,
      cadeiraId: reserva.cadeira_id,
      data: dataReservaIso,
      status: 'livre',
      ocupante: null
    });

    return {
      success: true,
      code: 200,
      message: 'Reserva cancelada com sucesso!',
      reserva: {
        id: reserva.id,
        cadeiraId: reserva.cadeira_id,
        dataReserva: dataReservaIso,
        status: 'CANCELADA',
        canceladoEm: new Date().toISOString()
      }
    };
  }

  /**
   * Lista reservas ativas e históricas do usuário
   */
  public static async minhasReservas(usuarioId: number, limit = 50, offset = 0) {
    const result = await pool.query(`
      SELECT 
        r.id,
        to_char(r.data_reserva, 'YYYY-MM-DD') AS data_reserva,
        r.checkin_realizado,
        r.checkin_em,
        r.status,
        r.codigo_comprovante,
        r.criado_em,
        c.id AS cadeira_id,
        c.identificador AS cadeira_identificador,
        b.id AS baia_id,
        b.nome AS baia_nome,
        e.id AS escritorio_id,
        e.nome AS escritorio_nome,
        e.cidade AS escritorio_cidade
      FROM reservas r
      JOIN cadeiras c ON r.cadeira_id = c.id
      JOIN baias b ON c.baia_id = b.id
      JOIN escritorios e ON b.escritorio_id = e.id
      WHERE r.usuario_id = $1
      ORDER BY r.data_reserva DESC, r.id DESC
      LIMIT $2 OFFSET $3
    `, [usuarioId, limit, offset]);

    return result.rows;
  }

  /**
   * Envia comprovante por e-mail
   */
  public static async enviarComprovanteEmail(reservaId: number, userEmail: string, userPerfil: string, isRh: boolean, correlationId?: string) {
    const result = await pool.query(`
      SELECT 
        r.id,
        to_char(r.data_reserva, 'YYYY-MM-DD') AS data_reserva,
        r.codigo_comprovante,
        r.status,
        to_char(r.criado_em, 'DD/MM/YYYY HH24:MI') AS criado_em_formatado,
        c.identificador AS cadeira_identificador,
        b.nome AS baia_nome,
        e.nome AS escritorio_nome,
        e.cidade AS escritorio_cidade,
        u.nome AS usuario_nome,
        u.email AS usuario_email
      FROM reservas r
      JOIN cadeiras c ON r.cadeira_id = c.id
      JOIN baias b ON c.baia_id = b.id
      JOIN escritorios e ON b.escritorio_id = e.id
      JOIN usuarios u ON r.usuario_id = u.id
      WHERE r.id = $1
    `, [reservaId]);

    if (result.rowCount === 0) {
      return { success: false, code: 404, error: 'Reserva não encontrada.' };
    }

    const reserva = result.rows[0];
    const hasPermission = reserva.usuario_email === userEmail || userPerfil === 'ADMIN_RH' || isRh;

    if (!hasPermission) {
      return { success: false, code: 403, error: 'Você não tem permissão para acessar o comprovante desta reserva.' };
    }

    EmailService.enviarComprovanteReserva(reserva.usuario_email, reserva.usuario_nome, {
      escritorioNome: reserva.escritorio_nome,
      escritorioCidade: reserva.escritorio_cidade,
      baiaNome: reserva.baia_nome,
      cadeiraIdentificador: reserva.cadeira_identificador,
      dataReserva: reserva.data_reserva,
      codigoComprovante: reserva.codigo_comprovante,
      emitidoEm: reserva.criado_em_formatado
    }).catch(err => {
      logger.error('[ReservaService.enviarComprovanteEmail] Erro ao despachar e-mail:', { correlationId, error: err });
    });

    return {
      success: true,
      code: 200,
      message: `Comprovante enviado com sucesso para ${reserva.usuario_email}`,
      email: reserva.usuario_email
    };
  }
}

