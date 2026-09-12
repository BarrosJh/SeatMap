import { DateTime } from 'luxon';
import { getDbClient } from '../../../utils/dbClient';
import { ReservaHistoryService } from '../../reservaHistoryService';
import { wsManager } from '../../../websocket/wsServer';
import { logger } from '../../../utils/logger';
import { normalizeIsoDate } from '../../../utils/workWeekUtils';
import { ConfigService } from '../../configService';
import { ReservaToleranceUtils } from '../../reservas/reservaToleranceUtils';
import { NoShowExecutionResult } from '../types';

export class NoShowJobService {
  /**
   * Executa o cancelamento em lote de reservas sem check-in expiradas (No-Show).
   */
  public static async execute(forcedDate?: string): Promise<NoShowExecutionResult> {
    const dataAlvo = forcedDate || DateTime.now().setZone('America/Sao_Paulo').toISODate()!;
    const agora = DateTime.now().setZone('America/Sao_Paulo');
    const horarioCortePadrao = await ConfigService.get('HORARIO_LIMITE_CHECKIN', '11:00');
    const horarioInicioTardia = await ConfigService.get('HORARIO_INICIO_RESERVA_TARDIA', '10:00');
    const toleranciaMinutos = await ConfigService.getNumber('TOLERANCIA_CHECKIN_RESERVA_TARDIA_MINUTOS', 120);

    const client = await getDbClient();

    try {
      await client.query('BEGIN');

      // Lock no PostgreSQL para evitar execução concorrente em ambientes multi-instância
      const lockRes = await client.query(`
        SELECT pg_try_advisory_xact_lock(hashtext('seatmap_cron_noshow_lock')) AS obtido;
      `);

      if (!lockRes.rows[0]?.obtido) {
        try {
          await client.query('ROLLBACK');
        } catch (rollbackErr) {
          logger.warn('[NoShowJob] Falha ao executar ROLLBACK pós lock:', { error: rollbackErr });
        }
        logger.info('[NoShowJob] Outra instância/processo já está executando a rotina de No-Show. Execução concorrente ignorada.');
        return { totalExpiradas: 0, reservas: [] };
      }

      // Buscar reservas ativas sem checkin com data igual ou anterior à data alvo
      const selectRes = await client.query(`
        SELECT r.id, r.cadeira_id, r.usuario_id, to_char(r.data_reserva, 'YYYY-MM-DD') AS data_reserva, r.criado_em, b.escritorio_id, c.identificador
        FROM reservas r
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        WHERE r.data_reserva <= $1
          AND r.status = 'ATIVA'
          AND r.checkin_realizado = false
        FOR UPDATE;
      `, [dataAlvo]);

      if (selectRes.rowCount === 0) {
        await client.query('COMMIT');
        return { totalExpiradas: 0, reservas: [] };
      }

      // Filtrar apenas reservas cujo limite individual de tolerância já foi atingido
      const reservasExpiradas: any[] = [];

      for (const row of selectRes.rows) {
        const calculo = ReservaToleranceUtils.calcularLimiteCheckin(
          row.data_reserva,
          row.criado_em,
          {
            horarioCortePadrao,
            horarioInicioTardia,
            toleranciaMinutos
          },
          agora
        );

        if (calculo.isExpirada) {
          reservasExpiradas.push({
            ...row,
            limiteFormatado: calculo.limiteFormatado,
            isReservaTardia: calculo.isReservaTardia
          });
        }
      }

      if (reservasExpiradas.length === 0) {
        await client.query('COMMIT');
        return { totalExpiradas: 0, reservas: [] };
      }

      const ids = reservasExpiradas.map((r: any) => r.id);

      // Atualizar status para EXPIRADA_NOSHOW
      await client.query(`
        UPDATE reservas
        SET status = 'EXPIRADA_NOSHOW'
        WHERE id = ANY($1::int[]);
      `, [ids]);

      // Registrar evento de No-Show na Linha do Tempo forense
      for (const row of reservasExpiradas) {
        await ReservaHistoryService.registrarEvento({
          reservaId: row.id,
          cadeiraId: row.cadeira_id,
          usuarioId: row.usuario_id,
          dataReserva: row.data_reserva,
          tipoEvento: 'EXPIRADA_NOSHOW',
          executadoPorUsuarioId: null,
          motivo: row.isReservaTardia
            ? `Cancelamento automático por ausência de check-in diário até o limite de tolerância estendida (${row.limiteFormatado})`
            : `Cancelamento automático por ausência de check-in diário até o horário limite (${row.limiteFormatado})`,
          detalhes: {
            identificadorCadeira: row.identificador,
            escritorioId: row.escritorio_id,
            limiteCheckin: row.limiteFormatado,
            isReservaTardia: row.isReservaTardia
          }
        }, client);
      }

      await client.query('COMMIT');

      // Emitir broadcast WebSocket liberando as cadeiras instantaneamente
      for (const row of reservasExpiradas) {
        wsManager.broadcastSeatUpdate({
          evento: 'assento_atualizado',
          escritorioId: row.escritorio_id,
          cadeiraId: row.cadeira_id,
          data: normalizeIsoDate(row.data_reserva),
          status: 'livre',
          ocupante: null
        });
      }

      logger.info(`[NoShowJob] ${reservasExpiradas.length} reservas foram canceladas por No-Show e assentos liberados no WebSocket.`);
      return { totalExpiradas: reservasExpiradas.length, reservas: reservasExpiradas };
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackErr) {
        logger.error('[NoShowJob] Falha ao executar ROLLBACK:', { error: rollbackErr });
      }
      logger.error('[NoShowJob] Erro ao executar cancelamento de no-show:', { error });
      throw error;
    } finally {
      client.release();
    }
  }
}

