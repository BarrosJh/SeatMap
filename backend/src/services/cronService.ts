import cron from 'node-cron';
import { DateTime } from 'luxon';
import pool from '../config/db';
import { wsManager } from '../websocket/wsServer';

export class CronService {
  private static task: cron.ScheduledTask | null = null;

  public static init(): void {
    // Agendador executado diariamente às 11:00:00 no fuso de São Paulo
    this.task = cron.schedule('0 11 * * *', async () => {
      console.log(`[Cron No-Show] [${DateTime.now().setZone('America/Sao_Paulo').toFormat('yyyy-MM-dd HH:mm:ss')}] Iniciando rotina de limpeza de No-Show...`);
      await this.cancelExpiredNoShows();
    }, {
      timezone: 'America/Sao_Paulo'
    });

    console.log('[Cron] Rotina diária de No-Show agendada para às 11h00 (America/Sao_Paulo)');
  }

  public static async cancelExpiredNoShows(forcedDate?: string): Promise<{ totalExpiradas: number; reservas: any[] }> {
    const dataAlvo = forcedDate || DateTime.now().setZone('America/Sao_Paulo').toISODate()!;
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      // Buscar reservas ativas sem checkin na data especificada com dados de escritório e cadeira
      const selectRes = await client.query(`
        SELECT r.id, r.cadeira_id, r.usuario_id, r.data_reserva, b.escritorio_id, c.identificador
        FROM reservas r
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        WHERE r.data_reserva = $1
          AND r.status = 'ATIVA'
          AND r.checkin_realizado = false
        FOR UPDATE;
      `, [dataAlvo]);

      if (selectRes.rowCount === 0) {
        await client.query('COMMIT');
        console.log(`[Cron No-Show] Nenhuma reserva pendente de check-in encontrada para a data ${dataAlvo}.`);
        return { totalExpiradas: 0, reservas: [] };
      }

      const ids = selectRes.rows.map((r: any) => r.id);

      // Atualizar status para EXPIRADA_NOSHOW
      await client.query(`
        UPDATE reservas
        SET status = 'EXPIRADA_NOSHOW'
        WHERE id = ANY($1::int[]);
      `, [ids]);

      await client.query('COMMIT');

      // Emitir broadcast WebSocket liberando as cadeiras instantaneamente
      for (const row of selectRes.rows) {
        wsManager.broadcastSeatUpdate({
          evento: 'assento_atualizado',
          escritorioId: row.escritorio_id,
          cadeiraId: row.cadeira_id,
          data: typeof row.data_reserva === 'string' ? row.data_reserva : DateTime.fromJSDate(row.data_reserva).toISODate()!,
          status: 'livre',
          ocupante: null
        });
      }

      console.log(`[Cron No-Show] ${selectRes.rowCount} reservas foram canceladas por No-Show e assentos liberados no WebSocket.`);
      return { totalExpiradas: selectRes.rowCount || 0, reservas: selectRes.rows };
    } catch (error) {
      await client.query('ROLLBACK');
      console.error('[Cron No-Show] Erro ao executar cancelamento de no-show:', error);
      throw error;
    } finally {
      client.release();
    }
  }
}

