import { DateTime } from 'luxon';
import pool from '../config/db';
import { EmailService } from './emailService';
import { ReservaHistoryService } from './reservaHistoryService';
import { wsManager } from '../websocket/wsServer';
import { logger } from '../utils/logger';

export class FacilitiesService {
  /**
   * Bloqueia uma cadeira para manutenção, cancelando reservas ativas futuras, notificando ocupantes e emitindo WS.
   */
  public static async colocarCadeiraEmManutencao(
    cadeiraId: number,
    motivo: string,
    previsaoRetorno: string | null | undefined,
    userId: number,
    correlationId?: string
  ) {
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
        return { success: false, code: 404, error: 'Cadeira não encontrada.' };
      }

      const cadeira = cadeiraRes.rows[0];

      let parsedPrevisao: Date | null = null;
      if (previsaoRetorno) {
        const dt = DateTime.fromISO(previsaoRetorno);
        if (!dt.isValid) {
          await client.query('ROLLBACK');
          return { success: false, code: 400, error: 'Formato de previsão de retorno inválido. Utilize uma data/hora no padrão ISO.' };
        }
        parsedPrevisao = dt.toJSDate();
      }

      await client.query(`
        UPDATE cadeiras
        SET status_operacional = 'EM_MANUTENCAO',
            motivo_manutencao = $1,
            previsao_retorno = $2,
            manutencao_por_usuario_id = $3
        WHERE id = $4
      `, [
        motivo.trim(),
        parsedPrevisao,
        userId,
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
            executadoPorUsuarioId: userId,
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
        }).catch(err => logger.error('[FacilitiesService] Erro ao despachar email de manutencao:', { correlationId, error: err }));
      }

      wsManager.broadcastToAll({
        tipo: 'STATUS_CADEIRA_ALTERADO',
        cadeiraId: cadeira.id,
        escritorioId: cadeira.escritorio_id,
        statusOperacional: 'EM_MANUTENCAO',
        motivo: motivo.trim()
      });

      return {
        success: true,
        message: `Mesa ${cadeira.identificador} colocada em manutenção com sucesso.`,
        reservasCanceladas: reservasAfetadas.length,
        cadeira: {
          id: cadeira.id,
          identificador: cadeira.identificador,
          statusOperacional: 'EM_MANUTENCAO',
          motivoManutencao: motivo.trim(),
          previsaoRetorno
        }
      };
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackErr) {
        logger.error('[FacilitiesService] Falha ao executar ROLLBACK:', { correlationId, error: rollbackErr });
      }
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Libera uma cadeira de manutenção de volta ao status DISPONIVEL
   */
  public static async liberarCadeiraManutencao(cadeiraId: number) {
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
      return null;
    }

    const cadeira = updateRes.rows[0];

    wsManager.broadcastToAll({
      tipo: 'STATUS_CADEIRA_ALTERADO',
      cadeiraId: cadeira.id,
      escritorioId: cadeira.escritorio_id,
      statusOperacional: 'DISPONIVEL'
    });

    return {
      message: `Mesa ${cadeira.identificador} liberada para reservas gerais.`,
      cadeiraId: cadeira.id,
      statusOperacional: 'DISPONIVEL'
    };
  }

  /**
   * Obtém histórico de eventos de uma cadeira
   */
  public static async getHistoricoCadeira(cadeiraId: number, limit: number = 50, offset: number = 0) {
    return ReservaHistoryService.getHistoricoCadeira(cadeiraId, limit, offset);
  }

  /**
   * Consulta assentos em manutenção e KPIs
   */
  public static async getCadeirasManutencao(escritorioId?: string, busca?: string) {
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

    return {
      kpis: {
        totalBloqueadas: kpis.total_bloqueadas,
        totalOperacionais: kpis.total_operacionais,
        totalAtrasadas: kpis.total_atrasadas
      },
      manutencoes: listRes.rows
    };
  }

  /**
   * Lista todas as cadeiras ativas por filtro de escritório
   */
  public static async getTodasCadeiras(escritorioId?: string) {
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

    return result.rows;
  }
}

