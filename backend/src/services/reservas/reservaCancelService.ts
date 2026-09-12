import { DateTime } from 'luxon';
import pool from '../../config/db';
import { getDbClient } from '../../utils/dbClient';
import { ReservaHistoryService } from '../reservaHistoryService';
import { wsManager } from '../../websocket/wsServer';
import { normalizeIsoDate } from '../../utils/workWeekUtils';

export class ReservaCancelService {
  /**
   * Cancela uma reserva ativa do usuário
   */
  public static async cancelarReserva(reservaId: number, usuarioId: number) {
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
          r.status, 
          r.codigo_comprovante, 
          b.escritorio_id, 
          c.identificador AS cadeira_identificador
        FROM reservas r
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        WHERE r.id = $1
        FOR UPDATE
      `, [reservaId]);

      if (result.rowCount === 0) {
        await client.query('ROLLBACK');
        return { success: false, code: 404, error: 'Reserva não encontrada.' };
      }

      const reserva = result.rows[0];

      if (reserva.usuario_id !== usuarioId) {
        await client.query('ROLLBACK');
        return { success: false, code: 403, error: 'Você só pode cancelar suas próprias reservas.' };
      }

      if (reserva.status !== 'ATIVA') {
        await client.query('ROLLBACK');
        return { success: false, code: 400, error: `Não é possível cancelar uma reserva com status ${reserva.status}.` };
      }

      if (reserva.checkin_realizado) {
        await client.query('ROLLBACK');
        return {
          success: false,
          code: 400,
          error: 'Esta reserva já possui presença confirmada (check-in realizado). Não é possível cancelá-la, utilize a opção Liberar Mesa.'
        };
      }

      const dataReservaIso = normalizeIsoDate(reserva.data_reserva);
      const dataReservaLuxon = DateTime.fromISO(dataReservaIso, { zone: 'America/Sao_Paulo' }).startOf('day');
      const hoje = DateTime.now().setZone('America/Sao_Paulo').startOf('day');

      if (dataReservaLuxon < hoje) {
        await client.query('ROLLBACK');
        return { success: false, code: 400, error: 'Não é possível cancelar reservas de datas passadas.' };
      }

      const updateRes = await client.query(`
        UPDATE reservas 
        SET status = 'CANCELADA' 
        WHERE id = $1 AND status = 'ATIVA'
      `, [reservaId]);

      if (updateRes.rowCount === 0) {
        await client.query('ROLLBACK');
        return { success: false, code: 400, error: 'A reserva não pôde ser cancelada pois seu status foi modificado.' };
      }

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
        message: 'Reserva cancelada com sucesso!',
        reserva: {
          id: reserva.id,
          cadeiraId: reserva.cadeira_id,
          dataReserva: dataReservaIso,
          status: 'CANCELADA',
          canceladoEm: new Date().toISOString()
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
