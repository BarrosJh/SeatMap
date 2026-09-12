import { DateTime } from 'luxon';
import pool from '../../config/db';
import { getDbClient } from '../../utils/dbClient';
import { ReservaHistoryService } from '../reservaHistoryService';
import { wsManager } from '../../websocket/wsServer';
import { normalizeIsoDate } from '../../utils/workWeekUtils';

export class ReservaCheckoutService {
  /**
   * Libera voluntariamente uma mesa que já teve o check-in confirmado,
   * atualizando o status para CONCLUIDA e desocupando o assento no mapa.
   */
  public static async liberarMesa(reservaId: number, usuarioId: number, correlationId?: string) {
    const client = await getDbClient();

    try {
      await client.query('BEGIN');

      const result = await client.query(`
        SELECT 
          r.id, 
          r.usuario_id, 
          r.cadeira_id, 
          r.data_reserva, 
          r.checkin_realizado,
          r.checkin_em,
          r.status, 
          r.codigo_comprovante, 
          b.escritorio_id, 
          c.identificador AS cadeira_identificador
        FROM reservas r
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        WHERE r.id = $1
        FOR UPDATE OF r
      `, [reservaId]);

      if (result.rowCount === 0) {
        await client.query('ROLLBACK');
        return { success: false, code: 404, error: 'Reserva não encontrada.' };
      }

      const reserva = result.rows[0];

      if (reserva.usuario_id !== usuarioId) {
        await client.query('ROLLBACK');
        return { success: false, code: 403, error: 'Você só pode liberar suas próprias reservas.' };
      }

      if (reserva.status !== 'ATIVA') {
        await client.query('ROLLBACK');
        return { success: false, code: 400, error: `Não é possível liberar uma reserva com status ${reserva.status}.` };
      }

      if (!reserva.checkin_realizado) {
        await client.query('ROLLBACK');
        return {
          success: false,
          code: 400,
          error: 'A mesa só pode ser liberada após a confirmação do check-in. Caso não vá comparecer, cancele a reserva.'
        };
      }

      const dataReservaIso = normalizeIsoDate(reserva.data_reserva);
      const checkoutTimestamp = new Date();

      const updateRes = await client.query(`
        UPDATE reservas 
        SET status = 'CONCLUIDA', checkout_em = $1 
        WHERE id = $2 AND status = 'ATIVA'
      `, [checkoutTimestamp, reservaId]);

      if (updateRes.rowCount === 0) {
        await client.query('ROLLBACK');
        return { success: false, code: 400, error: 'A reserva não pôde ser liberada pois seu status foi modificado.' };
      }

      await ReservaHistoryService.registrarEvento({
        reservaId: reserva.id,
        cadeiraId: reserva.cadeira_id,
        usuarioId,
        dataReserva: dataReservaIso,
        tipoEvento: 'MESA_LIBERADA',
        executadoPorUsuarioId: usuarioId,
        motivo: 'Mesa liberada voluntariamente pelo colaborador',
        detalhes: {
          comprovante: reserva.codigo_comprovante,
          cadeiraIdentificador: reserva.cadeira_identificador,
          checkinEm: reserva.checkin_em,
          checkoutEm: checkoutTimestamp.toISOString()
        }
      }, client);

      await client.query('COMMIT');

      // Emissão do WebSocket estritamente pós-commit
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
        message: 'Mesa liberada com sucesso! O assento agora está disponível para outros colaboradores.',
        reserva: {
          id: reserva.id,
          cadeiraId: reserva.cadeira_id,
          dataReserva: dataReservaIso,
          status: 'CONCLUIDA',
          checkoutEm: checkoutTimestamp.toISOString()
        }
      };
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {}
      throw error;
    } finally {
      client.release();
    }
  }
}

