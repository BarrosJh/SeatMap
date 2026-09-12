import crypto from 'crypto';
import { DateTime } from 'luxon';
import pool from '../../config/db';
import { getDbClient } from '../../utils/dbClient';
import { ConfigService } from '../configService';
import { ReservaHistoryService } from '../reservaHistoryService';
import { wsManager } from '../../websocket/wsServer';
import { getWorkWeekDiff, isProximaSemanaLiberada } from '../../utils/workWeekUtils';
import { ReservaToleranceUtils } from './reservaToleranceUtils';
import { logger } from '../../utils/logger';

export interface CriarReservaInput {
  cadeiraId: number;
  usuarioId: number;
  usuarioNome: string;
  usuarioEmail: string;
  usuarioPerfil: string;
  departamentoId?: number | null;
  departamentoNome?: string;
  dataReserva: string;
  idempotencyKey?: string;
  correlationId?: string;
}

export class ReservaCreateService {
  /**
   * Cria ou troca atomicamente uma reserva de assento com concorrência serializada
   */
  public static async criarReserva(input: CriarReservaInput) {
    const {
      cadeiraId,
      usuarioId,
      usuarioNome,
      usuarioPerfil,
      departamentoId,
      departamentoNome,
      dataReserva,
      idempotencyKey,
      correlationId
    } = input;

    const dataAlvoIso = dataReserva;
    const dataLuxon = DateTime.fromISO(dataAlvoIso, { zone: 'America/Sao_Paulo' }).startOf('day');
    const hojeLuxon = DateTime.now().setZone('America/Sao_Paulo').startOf('day');
    const dataAlvo = dataLuxon.toISODate()!;
    const hoje = hojeLuxon.toISODate()!;

    if (dataAlvo < hoje) {
      return { success: false, code: 400, error: 'Não é permitido realizar reservas para datas passadas.' };
    }

    // Bloqueio de finais de semana
    if (dataLuxon.weekday === 6 || dataLuxon.weekday === 7) {
      return { success: false, code: 400, error: 'Não há expediente aos finais de semana. Selecione um dia útil (Segunda a Sexta).' };
    }

    const diffSemanas = getWorkWeekDiff(dataLuxon, hojeLuxon);
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

    const [
      limiteAtivasStr,
      permitirTrocaStr,
      checkinAutoGestaoStr,
      horarioCortePadrao,
      horarioInicioTardia,
      toleranciaMinutosStr
    ] = await Promise.all([
      ConfigService.get('LIMITE_SEMANAL_RESERVAS', '2'),
      ConfigService.get('PERMITIR_TROCA_MESMO_DIA', 'true'),
      ConfigService.get('CHECKIN_AUTOMATICO_GESTAO', 'true'),
      ConfigService.get('HORARIO_LIMITE_CHECKIN', '11:00'),
      ConfigService.get('HORARIO_INICIO_RESERVA_TARDIA', '10:00'),
      ConfigService.get('TOLERANCIA_CHECKIN_RESERVA_TARDIA_MINUTOS', '120')
    ]);
    const limiteAtivas = parseInt(limiteAtivasStr, 10) || 2;
    const permitirTroca = permitirTrocaStr === 'true';
    const checkinAutoGestao = checkinAutoGestaoStr === 'true';
    const toleranciaMinutos = parseInt(toleranciaMinutosStr, 10) || 120;

    const client = await getDbClient();

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
        FOR UPDATE
      `, [cadeiraId, dataAlvoIso]);

      if (cadeiraOcupadaRes.rowCount! > 0 && cadeiraOcupadaRes.rows[0].usuario_id !== usuarioId) {
        await client.query('ROLLBACK');
        return { success: false, code: 409, error: 'Este assento acabou de ser reservado por outro colaborador.' };
      }

      const reservaExistenteDiaRes = await client.query(`
        SELECT r.id, r.cadeira_id, r.checkin_realizado, r.checkin_em, b.escritorio_id, c.identificador
        FROM reservas r
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        WHERE r.usuario_id = $1 AND r.data_reserva = $2 AND r.status = 'ATIVA'
        FOR UPDATE
      `, [usuarioId, dataAlvoIso]);

      const isTroca = reservaExistenteDiaRes.rowCount! > 0;
      const reservaAntiga = isTroca ? reservaExistenteDiaRes.rows[0] : null;
      const isTrocaPosCheckin = isTroca && Boolean(reservaAntiga.checkin_realizado);

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
        if (!permitirTroca) {
          await client.query('ROLLBACK');
          return { success: false, code: 400, error: 'A troca de assento no mesmo dia está desabilitada pela política de RH.' };
        }
      }

      if (!isTroca) {
        // Lock no registro do usuário para evitar concorrência bypassando o limite semanal
        await client.query('SELECT id FROM usuarios WHERE id = $1 FOR UPDATE', [usuarioId]);

        const contagemAtivasRes = await client.query(`
          SELECT COUNT(*) AS total
          FROM reservas
          WHERE usuario_id = $1
            AND status = 'ATIVA'
            AND data_reserva >= $2
        `, [usuarioId, hoje]);

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

      const isGestao = usuarioPerfil === 'GESTAO';
      const checkinRealizado = isGestao && checkinAutoGestao;
      const checkinEm = checkinRealizado ? new Date() : null;

      let novaReserva: any;
      if (isTroca && reservaAntiga) {
        if (isTrocaPosCheckin) {
          // Se o check-in já havia sido realizado na mesa anterior:
          // 1. Marca a reserva antiga como CONCLUIDA (checkout automático por troca)
          const checkoutTimestamp = new Date();
          await client.query(`
            UPDATE reservas
            SET status = 'CONCLUIDA', checkout_em = $1
            WHERE id = $2 AND status = 'ATIVA'
          `, [checkoutTimestamp, reservaAntiga.id]);

          // Registra a liberação da mesa anterior no histórico de auditoria
          await ReservaHistoryService.registrarEvento({
            reservaId: reservaAntiga.id,
            cadeiraId: reservaAntiga.cadeira_id,
            usuarioId,
            dataReserva: dataAlvoIso,
            tipoEvento: 'MESA_LIBERADA',
            executadoPorUsuarioId: usuarioId,
            motivo: `Mesa concluída automaticamente por troca de assento para a Mesa ${cadeira.identificador}`,
            detalhes: {
              codigoComprovanteAntigo: reservaAntiga.codigo_comprovante,
              cadeiraAntigaIdentificador: reservaAntiga.identificador,
              novaCadeiraId: cadeira.id,
              novaCadeiraIdentificador: cadeira.identificador,
              checkoutEm: checkoutTimestamp.toISOString()
            }
          }, client);

          // 2. Insere uma nova reserva com status ATIVA na nova mesa
          const insertRes = await client.query(`
            INSERT INTO reservas (cadeira_id, usuario_id, data_reserva, checkin_realizado, checkin_em, status, codigo_comprovante)
            VALUES ($1, $2, $3, $4, $5, 'ATIVA', $6)
            RETURNING id, cadeira_id, usuario_id, to_char(data_reserva, 'YYYY-MM-DD') AS data_reserva, checkin_realizado, checkin_em, status, codigo_comprovante, criado_em
          `, [cadeiraId, usuarioId, dataAlvoIso, checkinRealizado, checkinEm, codigoComprovante]);
          novaReserva = insertRes.rows[0];
        } else {
          // Se o check-in AINDA NÃO foi realizado: segue o fluxo normal de troca mutando a reserva atual
          const updateRes = await client.query(`
            UPDATE reservas
            SET cadeira_id = $1, checkin_realizado = $2, checkin_em = $3, status = 'ATIVA', codigo_comprovante = $4, criado_em = NOW()
            WHERE id = $5
            RETURNING id, cadeira_id, usuario_id, to_char(data_reserva, 'YYYY-MM-DD') AS data_reserva, checkin_realizado, checkin_em, status, codigo_comprovante, criado_em
          `, [cadeiraId, checkinRealizado, checkinEm, codigoComprovante, reservaAntiga.id]);
          novaReserva = updateRes.rows[0];
        }
      } else {
        const insertRes = await client.query(`
          INSERT INTO reservas (cadeira_id, usuario_id, data_reserva, checkin_realizado, checkin_em, status, codigo_comprovante)
          VALUES ($1, $2, $3, $4, $5, 'ATIVA', $6)
          RETURNING id, cadeira_id, usuario_id, to_char(data_reserva, 'YYYY-MM-DD') AS data_reserva, checkin_realizado, checkin_em, status, codigo_comprovante, criado_em
        `, [cadeiraId, usuarioId, dataAlvoIso, checkinRealizado, checkinEm, codigoComprovante]);
        novaReserva = insertRes.rows[0];
      }

      await ReservaHistoryService.registrarEvento({
        reservaId: novaReserva.id,
        cadeiraId: cadeira.id,
        usuarioId,
        dataReserva: dataAlvoIso,
        tipoEvento: (isTroca && !isTrocaPosCheckin) ? 'TROCADA' : 'CRIADA',
        executadoPorUsuarioId: usuarioId,
        motivo: isTrocaPosCheckin
          ? `Nova reserva de assento efetuada após troca pós check-in (Mesa ${reservaAntiga?.identificador} -> Mesa ${cadeira.identificador})`
          : (isTroca ? `Troca atômica de assento (Mesa ${reservaAntiga?.identificador} -> Mesa ${cadeira.identificador})` : 'Reserva de assento efetuada'),
        detalhes: {
          codigoComprovante,
          escritorioId: cadeira.escritorio_id,
          cadeiraAntigaId: reservaAntiga?.cadeira_id || null,
          cadeiraAntigaIdentificador: reservaAntiga?.identificador || null,
          checkinAutomatico: checkinRealizado,
          trocaPosCheckin: isTrocaPosCheckin
        }
      }, client);

      await client.query('COMMIT');

      // Emissão segura via WebSocket estritamente após o COMMIT bem-sucedido
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
        const constraintName = (error.constraint || '').toLowerCase();
        const detail = (error.detail || '').toLowerCase();

        if (constraintName.includes('cadeira') || detail.includes('cadeira')) {
          return {
            success: false,
            code: 409,
            error: 'Conflito de Concorrência: Este assento acabou de ser reservado por outro usuário para a mesma data.'
          };
        }
        if (constraintName.includes('usuario') || detail.includes('usuario')) {
          return {
            success: false,
            code: 409,
            error: 'Conflito: Você já possui uma reserva ativa para esta mesma data.'
          };
        }
        return {
          success: false,
          code: 409,
          error: 'Conflito de Concorrência: Registro duplicado detectado para esta data.'
        };
      }

      throw error;
    } finally {
      client.release();
    }
  }
}
