import cron, { ScheduledTask } from 'node-cron';
import { DateTime } from 'luxon';
import pool from '../config/db';
import { getDbClient } from '../utils/dbClient';
import { ReservaHistoryService } from './reservaHistoryService';
import { wsManager } from '../websocket/wsServer';
import { logger } from '../utils/logger';
import { normalizeIsoDate } from '../utils/workWeekUtils';
import { ConfigService } from './configService';
import { ReservaToleranceUtils } from './reservas/reservaToleranceUtils';

export class CronService {
  private static task: ScheduledTask | null = null;
  private static activeExecutions: Set<Promise<any>> = new Set();

  public static init(): void {
    // 1. Executa verificação inicial no boot para limpar no-shows pendentes
    this.checkAndCancelNoShows().catch((err) => {
      logger.error('[Cron] Falha na verificação de No-Show no boot:', { error: err });
    });

    // 2. Agendador periódico a cada 1 minuto para checar o horário de corte configurado dinamicamente
    this.task = cron.schedule('* * * * *', async () => {
      await this.checkAndCancelNoShows();
    }, {
      timezone: 'America/Sao_Paulo'
    });

    logger.info('[Cron] Rotina de monitoramento de No-Show iniciada (verificação por minuto no fuso America/Sao_Paulo)');
  }

  public static async checkAndCancelNoShows(): Promise<void> {
    try {
      await this.cancelExpiredNoShows();
    } catch (err) {
      logger.error('[Cron] Erro ao verificar horário de No-Show:', { error: err });
    }
  }

  public static stop(): void {
    if (this.task) {
      this.task.stop();
      this.task = null;
      logger.info('[Cron] Rotina diária de No-Show interrompida.');
    }
  }

  /**
   * Aguarda o término de qualquer execução ativa do Cron durante o graceful shutdown (REL-04).
   */
  public static async waitForCompletion(timeoutMs: number = 5000): Promise<void> {
    this.stop();
    if (this.activeExecutions.size === 0) {
      return;
    }

    logger.info('[Cron] Aguardando conclusão de rotinas de No-Show em andamento...');
    let timer: NodeJS.Timeout | null = null;

    const timeoutPromise = new Promise<void>((resolve) => {
      timer = setTimeout(() => {
        logger.warn('[Cron] Timeout atingido aguardando conclusão das rotinas ativas.');
        resolve();
      }, timeoutMs);
      if (typeof timer && typeof timer.unref === 'function') {
        timer.unref();
      }
    });

    try {
      const allExecutions = Promise.allSettled(Array.from(this.activeExecutions));
      await Promise.race([allExecutions, timeoutPromise]);
    } catch (_) {
      // Falha capturada no log da própria rotina
    } finally {
      if (timer) clearTimeout(timer);
      this.activeExecutions.clear();
    }
  }

  public static async cancelExpiredNoShows(forcedDate?: string): Promise<{ totalExpiradas: number; reservas: any[] }> {
    const executionPromise = this.executeCancelExpiredNoShows(forcedDate);
    this.activeExecutions.add(executionPromise);
    try {
      return await executionPromise;
    } finally {
      this.activeExecutions.delete(executionPromise);
    }
  }

  private static async executeCancelExpiredNoShows(forcedDate?: string): Promise<{ totalExpiradas: number; reservas: any[] }> {
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
          logger.warn('[Cron No-Show] Falha ao executar ROLLBACK pós lock:', { error: rollbackErr });
        }
        logger.info('[Cron No-Show] Outra instância/processo já está executando a rotina de No-Show. Execução concorrente ignorada.');
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

      logger.info(`[Cron No-Show] ${reservasExpiradas.length} reservas foram canceladas por No-Show e assentos liberados no WebSocket.`);
      return { totalExpiradas: reservasExpiradas.length, reservas: reservasExpiradas };
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackErr) {
        logger.error('[Cron No-Show] Falha ao executar ROLLBACK:', { error: rollbackErr });
      }
      logger.error('[Cron No-Show] Erro ao executar cancelamento de no-show:', { error });
      throw error;
    } finally {
      client.release();
    }
  }
}
