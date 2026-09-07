import { Response } from 'express';
import { DateTime } from 'luxon';
import pool from '../../config/db';
import { AuthenticatedRequest } from '../../middleware/auth';
import { EmailService } from '../../services/emailService';
import { ReservaHistoryService } from '../../services/reservaHistoryService';
import { wsManager } from '../../websocket/wsServer';
import { logger } from '../../utils/logger';

export class FacilitiesController {
  public static async colocarCadeiraEmManutencao(req: AuthenticatedRequest, res: Response) {
    const user = req.user!;
    const cadeiraId = parseInt(req.params.id, 10);
    const { motivo, previsaoRetorno } = req.body;

    if (isNaN(cadeiraId)) {
      return res.status(400).json({ error: 'ID de cadeira inválido.' });
    }

    if (!motivo || typeof motivo !== 'string' || motivo.trim().length === 0) {
      return res.status(400).json({ error: 'O motivo da manutenção é obrigatório (ex: monitor quebrado, tomada sem energia).' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const cadeiraRes = await client.query(`
        SELECT c.id, c.identificador, c.status_operacional, b.id AS baia_id, b.nome AS baia_nome, b.escritorio_id, e.nome AS escritorio_nome
        FROM cadeiras c
        JOIN baias b ON c.baia_id = b.id
        JOIN escritorios e ON b.escritorio_id = e.id
        WHERE c.id = $1
        FOR UPDATE
      `, [cadeiraId]);

      if (cadeiraRes.rowCount === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Cadeira não encontrada.' });
      }

      const cadeira = cadeiraRes.rows[0];

      await client.query(`
        UPDATE cadeiras
        SET status_operacional = 'EM_MANUTENCAO',
            motivo_manutencao = $1,
            previsao_retorno = $2,
            manutencao_por_usuario_id = $3
        WHERE id = $4
      `, [
        motivo.trim(),
        previsaoRetorno ? new Date(previsaoRetorno) : null,
        user.userId,
        cadeiraId
      ]);

      const reservasAfetadasRes = await client.query(`
        SELECT r.id, r.usuario_id, r.data_reserva, r.codigo_comprovante, u.nome AS usuario_nome, u.email AS usuario_email
        FROM reservas r
        JOIN usuarios u ON r.usuario_id = u.id
        WHERE r.cadeira_id = $1
          AND r.data_reserva >= CURRENT_DATE
          AND r.status = 'ATIVA'
        FOR UPDATE
      `, [cadeiraId]);

      const reservasAfetadas = reservasAfetadasRes.rows;

      if (reservasAfetadas.length > 0) {
        const ids = reservasAfetadas.map(r => r.id);
        await client.query(`
          UPDATE reservas
          SET status = 'CANCELADA'
          WHERE id = ANY($1::int[])
        `, [ids]);

        for (const resItem of reservasAfetadas) {
          const dataIso = typeof resItem.data_reserva === 'string'
            ? resItem.data_reserva
            : DateTime.fromJSDate(resItem.data_reserva).toISODate()!;

          await ReservaHistoryService.registrarEvento({
            reservaId: resItem.id,
            cadeiraId: cadeira.id,
            usuarioId: resItem.usuario_id,
            dataReserva: dataIso,
            tipoEvento: 'CANCELADA_MANUTENCAO',
            executadoPorUsuarioId: user.userId,
            motivo: `Bloqueio operacional de manutenção do assento: ${motivo.trim()}`,
            detalhes: {
              motivoManutencao: motivo.trim(),
              previsaoRetorno: previsaoRetorno || null,
              comprovante: resItem.codigo_comprovante,
              cadeiraIdentificador: cadeira.identificador
            }
          }, client);
        }
      }

      await client.query('COMMIT');

      for (const resItem of reservasAfetadas) {
        const dataIso = typeof resItem.data_reserva === 'string'
          ? resItem.data_reserva
          : DateTime.fromJSDate(resItem.data_reserva).toISODate()!;

        wsManager.broadcastSeatUpdate({
          evento: 'assento_atualizado',
          escritorioId: cadeira.escritorio_id,
          cadeiraId: cadeira.id,
          data: dataIso,
          status: 'manutencao',
          ocupante: null
        });

        EmailService.enviarAvisoCancelamentoManutencao(resItem.usuario_email, resItem.usuario_nome, {
          cadeiraIdentificador: cadeira.identificador,
          dataReserva: dataIso,
          escritorioNome: cadeira.escritorio_nome,
          motivo: motivo.trim(),
          previsaoRetorno: previsaoRetorno ? DateTime.fromISO(previsaoRetorno).setZone('America/Sao_Paulo').toFormat('dd/MM/yyyy HH:mm') : undefined
        }).catch(err => logger.error('[FacilitiesController] Erro ao despachar email de manutencao:', { correlationId: req.correlationId, error: err }));
      }

      wsManager.broadcastToAll({
        tipo: 'STATUS_CADEIRA_ALTERADO',
        cadeiraId: cadeira.id,
        escritorioId: cadeira.escritorio_id,
        statusOperacional: 'EM_MANUTENCAO',
        motivo: motivo.trim()
      });

      return res.status(200).json({
        message: `Mesa ${cadeira.identificador} colocada em manutenção com sucesso.`,
        reservasCanceladas: reservasAfetadas.length,
        cadeira: {
          id: cadeira.id,
          identificador: cadeira.identificador,
          statusOperacional: 'EM_MANUTENCAO',
          motivoManutencao: motivo.trim(),
          previsaoRetorno
        }
      });
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackErr) {
        logger.error('[FacilitiesController] Falha ao executar ROLLBACK:', { correlationId: req.correlationId, error: rollbackErr });
      }
      logger.error('[FacilitiesController.colocarCadeiraEmManutencao] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao bloquear assento para manutenção.' });
    } finally {
      client.release();
    }
  }

  public static async liberarCadeiraManutencao(req: AuthenticatedRequest, res: Response) {
    const cadeiraId = parseInt(req.params.id, 10);

    if (isNaN(cadeiraId)) {
      return res.status(400).json({ error: 'ID de cadeira inválido.' });
    }

    try {
      const updateRes = await pool.query(`
        UPDATE cadeiras c
        SET status_operacional = 'DISPONIVEL',
            motivo_manutencao = NULL,
            previsao_retorno = NULL,
            manutencao_por_usuario_id = NULL
        FROM baias b
        WHERE c.id = $1 AND c.baia_id = b.id
        RETURNING c.id, c.identificador, b.escritorio_id
      `, [cadeiraId]);

      if (updateRes.rowCount === 0) {
        return res.status(404).json({ error: 'Cadeira não encontrada.' });
      }

      const cadeira = updateRes.rows[0];

      wsManager.broadcastToAll({
        tipo: 'STATUS_CADEIRA_ALTERADO',
        cadeiraId: cadeira.id,
        escritorioId: cadeira.escritorio_id,
        statusOperacional: 'DISPONIVEL'
      });

      return res.status(200).json({
        message: `Mesa ${cadeira.identificador} liberada para reservas gerais.`,
        cadeiraId: cadeira.id,
        statusOperacional: 'DISPONIVEL'
      });
    } catch (error) {
      logger.error('[FacilitiesController.liberarCadeiraManutencao] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao liberar cadeira de manutenção.' });
    }
  }

  public static async getHistoricoCadeira(req: AuthenticatedRequest, res: Response) {
    const cadeiraId = parseInt(req.params.id, 10);
    const limit = parseInt(req.query.limit as string, 10) || 50;
    const offset = parseInt(req.query.offset as string, 10) || 0;

    if (isNaN(cadeiraId)) {
      return res.status(400).json({ error: 'ID de cadeira inválido.' });
    }

    try {
      const historico = await ReservaHistoryService.getHistoricoCadeira(cadeiraId, limit, offset);
      return res.status(200).json({
        cadeiraId,
        total: historico.length,
        historico
      });
    } catch (error) {
      logger.error('[FacilitiesController.getHistoricoCadeira] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao consultar linha do tempo do assento.' });
    }
  }

  public static async getCadeirasManutencao(req: AuthenticatedRequest, res: Response) {
    try {
      const { escritorioId, busca } = req.query;

      const conditions: string[] = ["c.ativa = true"];
      const values: any[] = [];
      let idx = 1;

      if (escritorioId && escritorioId !== 'todos') {
        conditions.push(`b.escritorio_id = $${idx}`);
        values.push(parseInt(escritorioId as string, 10));
        idx++;
      }

      if (busca && typeof busca === 'string' && busca.trim().length > 0) {
        conditions.push(`(c.identificador ILIKE $${idx} OR b.nome ILIKE $${idx} OR c.motivo_manutencao ILIKE $${idx} OR u.nome ILIKE $${idx})`);
        values.push(`%${busca.trim()}%`);
        idx++;
      }

      const kpiRes = await pool.query(`
        SELECT 
          COUNT(CASE WHEN c.status_operacional = 'EM_MANUTENCAO' THEN 1 END)::int AS total_bloqueadas,
          COUNT(CASE WHEN c.status_operacional = 'DISPONIVEL' OR c.status_operacional IS NULL THEN 1 END)::int AS total_operacionais,
          COUNT(CASE WHEN c.status_operacional = 'EM_MANUTENCAO' AND c.previsao_retorno IS NOT NULL AND c.previsao_retorno < NOW() THEN 1 END)::int AS total_atrasadas
        FROM cadeiras c
        JOIN baias b ON c.baia_id = b.id
        WHERE c.ativa = true
      `);

      const kpis = kpiRes.rows[0] || { total_bloqueadas: 0, total_operacionais: 0, total_atrasadas: 0 };

      const listQuery = `
        SELECT 
          c.id,
          c.identificador,
          c.status_operacional,
          c.motivo_manutencao,
          c.previsao_retorno,
          c.manutencao_por_usuario_id,
          b.id AS baia_id,
          b.nome AS baia_nome,
          e.id AS escritorio_id,
          e.nome AS escritorio_nome,
          e.cidade AS escritorio_cidade,
          u.nome AS responsavel_nome,
          u.email AS responsavel_email,
          (
            SELECT MAX(h.criado_em) 
            FROM historico_reservas h 
            WHERE h.cadeira_id = c.id AND h.tipo_evento = 'CANCELADA_MANUTENCAO'
          ) AS data_bloqueio
        FROM cadeiras c
        JOIN baias b ON c.baia_id = b.id
        JOIN escritorios e ON b.escritorio_id = e.id
        LEFT JOIN usuarios u ON c.manutencao_por_usuario_id = u.id
        WHERE c.status_operacional = 'EM_MANUTENCAO' AND ${conditions.join(' AND ')}
        ORDER BY c.previsao_retorno ASC NULLS LAST, e.nome ASC, b.nome ASC, c.identificador ASC
      `;

      const listRes = await pool.query(listQuery, values);

      return res.status(200).json({
        kpis: {
          totalBloqueadas: kpis.total_bloqueadas,
          totalOperacionais: kpis.total_operacionais,
          totalAtrasadas: kpis.total_atrasadas
        },
        manutencoes: listRes.rows
      });
    } catch (error) {
      logger.error('[FacilitiesController.getCadeirasManutencao] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao buscar assentos em manutenção.' });
    }
  }

  public static async getTodasCadeiras(req: AuthenticatedRequest, res: Response) {
    try {
      const { escritorioId } = req.query;
      const conditions: string[] = ["c.ativa = true"];
      const values: any[] = [];

      if (escritorioId && escritorioId !== 'todos') {
        conditions.push(`b.escritorio_id = $1`);
        values.push(parseInt(escritorioId as string, 10));
      }

      const result = await pool.query(`
        SELECT 
          c.id,
          c.identificador,
          c.status_operacional,
          c.motivo_manutencao,
          c.previsao_retorno,
          b.id AS baia_id,
          b.nome AS baia_nome,
          e.id AS escritorio_id,
          e.nome AS escritorio_nome,
          e.cidade AS escritorio_cidade
        FROM cadeiras c
        JOIN baias b ON c.baia_id = b.id
        JOIN escritorios e ON b.escritorio_id = e.id
        WHERE ${conditions.join(' AND ')}
        ORDER BY e.nome ASC, b.nome ASC, c.identificador ASC
      `, values);

      return res.status(200).json(result.rows);
    } catch (error) {
      logger.error('[FacilitiesController.getTodasCadeiras] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao listar todas as cadeiras.' });
    }
  }
}
