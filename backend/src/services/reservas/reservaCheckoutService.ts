import { DateTime } from 'luxon';
import pool from '../../config/db';
import { ReservaHistoryService } from '../reservaHistoryService';
import { wsManager } from '../../websocket/wsServer';
import { normalizeIsoDate } from '../../utils/workWeekUtils';

export class ReservaCheckoutService {
  /**
   * Libera voluntariamente uma mesa que já teve o check-in confirmado,
   * atualizando o status para CONCLUIDA e desocupando o assento no mapa.
   */
  public static async liberarMesa(reservaId: number, usuarioId: number, correlationId?: string) {
    const result = await pool.query(`
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
    `, [reservaId]);

    if (result.rowCount === 0) {
      return { success: false, code: 404, error: 'Reserva não encontrada.' };
    }

    const reserva = result.rows[0];

    if (reserva.usuario_id !== usuarioId) {
      return { success: false, code: 403, error: 'Você só pode liberar suas próprias reservas.' };
    }

    if (reserva.status !== 'ATIVA') {
      return { success: false, code: 400, error: `Não é possível liberar uma reserva com status ${reserva.status}.` };
    }

    if (!reserva.checkin_realizado) {
      return {
        success: false,
        code: 400,
        error: 'A mesa só pode ser liberada após a confirmação do check-in. Caso não vá comparecer, cancele a reserva.'
      };
    }

    const dataReservaIso = normalizeIsoDate(reserva.data_reserva);
    const checkoutTimestamp = new Date();

    await pool.query(`
      UPDATE reservas 
      SET status = 'CONCLUIDA', checkout_em = $1 
      WHERE id = $2
    `, [checkoutTimestamp, reservaId]);

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
      message: 'Mesa liberada com sucesso! O assento agora está disponível para outros colaboradores.',
      reserva: {
        id: reserva.id,
        cadeiraId: reserva.cadeira_id,
        dataReserva: dataReservaIso,
        status: 'CONCLUIDA',
        checkoutEm: checkoutTimestamp.toISOString()
      }
    };
  }
}

