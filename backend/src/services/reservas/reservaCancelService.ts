import { DateTime } from 'luxon';
import pool from '../../config/db';
import { ReservaHistoryService } from '../reservaHistoryService';
import { wsManager } from '../../websocket/wsServer';
import { normalizeIsoDate } from '../../utils/workWeekUtils';

export class ReservaCancelService {
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
        r.checkin_realizado,
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

    if (reserva.checkin_realizado) {
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
}
