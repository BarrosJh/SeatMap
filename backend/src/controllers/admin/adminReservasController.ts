import { Response } from 'express';
import { DateTime } from 'luxon';
import pool from '../../config/db';
import { AuthenticatedRequest } from '../../middleware/auth';
import { ReservaHistoryService } from '../../services/reservaHistoryService';
import { wsManager } from '../../websocket/wsServer';
import { logger } from '../../utils/logger';
import { escapeSqlWildcards } from '../../utils/sanitizer';

export class AdminReservasController {
  public static async getReservas(req: AuthenticatedRequest, res: Response) {
    try {
      const { dataInicio, dataFim, escritorioId, departamentoId, status, busca, limit = 100, offset = 0 } = req.query;

      const conditions: string[] = [];
      const values: any[] = [];
      let idx = 1;

      if (dataInicio) {
        conditions.push(`r.data_reserva >= $${idx}`);
        values.push(dataInicio);
        idx++;
      }

      if (dataFim) {
        conditions.push(`r.data_reserva <= $${idx}`);
        values.push(dataFim);
        idx++;
      }

      if (escritorioId && escritorioId !== 'todos') {
        conditions.push(`e.id = $${idx}`);
        values.push(parseInt(escritorioId as string, 10));
        idx++;
      }

      if (departamentoId && departamentoId !== 'todos') {
        conditions.push(`d.id = $${idx}`);
        values.push(parseInt(departamentoId as string, 10));
        idx++;
      }

      if (status && status !== 'todos') {
        conditions.push(`r.status = $${idx}`);
        values.push(status);
        idx++;
      }

      if (busca && typeof busca === 'string' && busca.trim().length > 0) {
        conditions.push(`(u.nome ILIKE $${idx} OR u.matricula ILIKE $${idx} OR c.identificador ILIKE $${idx} OR b.nome ILIKE $${idx})`);
        values.push(`%${escapeSqlWildcards(busca.trim())}%`);
        idx++;
      }

      const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

      const countRes = await pool.query(`
        SELECT COUNT(*) AS total
        FROM reservas r
        JOIN usuarios u ON r.usuario_id = u.id
        LEFT JOIN departamentos d ON u.departamento_id = d.id
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        JOIN escritorios e ON b.escritorio_id = e.id
        ${whereClause}
      `, values);

      const total = parseInt(countRes.rows[0].total, 10);

      const dataQuery = `
        SELECT 
          r.id,
          r.cadeira_id,
          c.identificador AS assento,
          b.nome AS baia_nome,
          e.id AS escritorio_id,
          e.nome AS escritorio_nome,
          u.id AS usuario_id,
          u.nome AS usuario_nome,
          u.matricula,
          u.email AS usuario_email,
          d.nome AS departamento_nome,
          r.data_reserva,
          r.checkin_realizado,
          r.checkin_em,
          r.status,
          r.codigo_comprovante,
          r.criado_em
        FROM reservas r
        JOIN usuarios u ON r.usuario_id = u.id
        LEFT JOIN departamentos d ON u.departamento_id = d.id
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        JOIN escritorios e ON b.escritorio_id = e.id
        ${whereClause}
        ORDER BY r.data_reserva DESC, r.criado_em DESC
        LIMIT $${idx} OFFSET $${idx + 1}
      `;

      values.push(parseInt(limit as string, 10) || 100);
      values.push(parseInt(offset as string, 10) || 0);

      const result = await pool.query(dataQuery, values);

      return res.status(200).json({
        total,
        reservas: result.rows
      });
    } catch (error) {
      logger.error('[AdminReservasController.getReservas] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao consultar reservas.' });
    }
  }

  public static async cancelarReservaAdmin(req: AuthenticatedRequest, res: Response) {
    const user = req.user!;
    try {
      const { id } = req.params;
      const { justificativa } = req.body;

      const resRes = await pool.query(`
        SELECT 
          r.id,
          r.usuario_id,
          r.cadeira_id,
          r.data_reserva,
          r.status,
          r.codigo_comprovante,
          b.escritorio_id,
          c.identificador AS cadeira_identificador,
          u.nome AS usuario_nome
        FROM reservas r
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        JOIN usuarios u ON r.usuario_id = u.id
        WHERE r.id = $1
      `, [id]);

      if (resRes.rowCount === 0) {
        return res.status(404).json({ error: 'Reserva não encontrada.' });
      }

      const reserva = resRes.rows[0];

      if (reserva.status !== 'ATIVA') {
        return res.status(400).json({ error: `Reserva não pode ser cancelada pois está com status ${reserva.status}.` });
      }

      await pool.query(`
        UPDATE reservas
        SET status = 'CANCELADA'
        WHERE id = $1
      `, [id]);

      const dataFormatada = typeof reserva.data_reserva === 'string'
        ? reserva.data_reserva
        : DateTime.fromJSDate(reserva.data_reserva).toISODate()!;

      await ReservaHistoryService.registrarEvento({
        reservaId: reserva.id,
        cadeiraId: reserva.cadeira_id,
        usuarioId: reserva.usuario_id,
        dataReserva: dataFormatada,
        tipoEvento: 'CANCELADA_GESTAO',
        executadoPorUsuarioId: user.userId,
        motivo: justificativa || 'Cancelamento administrativo realizado pelo RH/Gestor',
        detalhes: {
          comprovante: reserva.codigo_comprovante,
          cadeiraIdentificador: reserva.cadeira_identificador,
          justificativa: justificativa || 'Não informada'
        }
      });

      wsManager.broadcastSeatUpdate({
        evento: 'assento_atualizado',
        escritorioId: reserva.escritorio_id,
        cadeiraId: reserva.cadeira_id,
        data: dataFormatada,
        status: 'livre',
        ocupante: null
      });

      return res.status(200).json({
        message: 'Reserva cancelada com sucesso pela gestão/RH.',
        reservaId: id
      });
    } catch (error) {
      logger.error('[AdminReservasController.cancelarReservaAdmin] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao cancelar reserva.' });
    }
  }
}
