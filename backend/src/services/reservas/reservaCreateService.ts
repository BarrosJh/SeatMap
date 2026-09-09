import { DateTime } from 'luxon';
import crypto from 'crypto';
import pool from '../../config/db';
import { ConfigService } from '../configService';
import { ReservaHistoryService } from '../reservaHistoryService';
import { wsManager } from '../../websocket/wsServer';
import { getWorkWeekDiff, isProximaSemanaLiberada } from '../../utils/workWeekUtils';
import { ReservaToleranceUtils } from './reservaToleranceUtils';
import { logger } from '../../utils/logger';

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

export class ReservaCreateService {
  /**
   * Processa a criação ou troca atômica de reserva com locks, idempotência e notificações
   */
  public static async criarReserva(input: CriarReservaInput) {
    const {
      usuarioId,
      usuarioNome,
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

      const horarioCortePadrao = await ConfigService.get('HORARIO_LIMITE_CHECKIN', '11:00');
      const horarioInicioTardia = await ConfigService.get('HORARIO_INICIO_RESERVA_TARDIA', '10:00');
      const toleranciaMinutos = await ConfigService.getNumber('TOLERANCIA_CHECKIN_RESERVA_TARDIA_MINUTOS', 120);
      const calculoLimite = ReservaToleranceUtils.calcularLimiteCheckin(
        dataAlvoIso,
        novaReserva.criado_em,
        { horarioCortePadrao, horarioInicioTardia, toleranciaMinutos }
      );

      const reservaEnriquecida = {
        ...novaReserva,
        limite_checkin: calculoLimite.limiteCheckin.toISO(),
        limite_formatado: calculoLimite.limiteFormatado,
        is_reserva_tardia: calculoLimite.isReservaTardia,
        modalidade_checkin: calculoLimite.isReservaTardia ? 'TEMPO_REMANESCENTE' : 'HORARIO_FIXO'
      };

      return {
        success: true,
        code: 201,
        message: isTroca ? 'Troca de assento realizada com sucesso!' : 'Reserva realizada com sucesso!',
        comprovante: codigoComprovante,
        reserva: reservaEnriquecida,
        trocaRealizada: isTroca
      };
    } catch (error: any) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackErr) {
        logger.error('[ReservaCreateService] Falha ao executar ROLLBACK:', { correlationId, error: rollbackErr });
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
}
