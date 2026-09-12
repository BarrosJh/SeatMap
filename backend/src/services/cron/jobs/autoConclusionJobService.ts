import { DateTime } from 'luxon';
import { getDbClient } from '../../../utils/dbClient';
import { ReservaHistoryService } from '../../reservaHistoryService';
import { logger } from '../../../utils/logger';
import { AutoConclusionExecutionResult } from '../types';

export class AutoConclusionJobService {
  /**
   * Executa a conclusão automática em lote de reservas confirmadas (com check-in) de datas anteriores.
   * Transiciona o status de 'ATIVA' para 'CONCLUIDA' e preenche 'checkout_em' caso não esteja definido.
   */
  public static async execute(forcedDate?: string): Promise<AutoConclusionExecutionResult> {
    const dataAlvo = forcedDate || DateTime.now().setZone('America/Sao_Paulo').toISODate()!;
    const client = await getDbClient();

    try {
      await client.query('BEGIN');

      // Lock no PostgreSQL para garantir execução única em ambientes distribuídos/clusterizados
      const lockRes = await client.query(`
        SELECT pg_try_advisory_xact_lock(hashtext('seatmap_cron_conclusion_lock')) AS obtido;
      `);

      if (!lockRes.rows[0]?.obtido) {
        try {
          await client.query('ROLLBACK');
        } catch (rollbackErr) {
          logger.warn('[AutoConclusionJob] Falha ao executar ROLLBACK pós lock:', { error: rollbackErr });
        }
        logger.info('[AutoConclusionJob] Outra instância/processo já está executando a conclusão automática. Execução ignorada.');
        return { totalConcluidas: 0, reservas: [] };
      }

      // Buscar reservas confirmadas (com check-in) de datas estritamente anteriores à data alvo que continuam como ATIVA
      const selectRes = await client.query(`
        SELECT 
          r.id, 
          r.cadeira_id, 
          r.usuario_id, 
          to_char(r.data_reserva, 'YYYY-MM-DD') AS data_reserva, 
          r.checkin_em,
          r.checkout_em,
          r.codigo_comprovante,
          b.escritorio_id, 
          c.identificador AS cadeira_identificador
        FROM reservas r
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        WHERE r.data_reserva < $1
          AND r.status = 'ATIVA'
          AND r.checkin_realizado = true
        FOR UPDATE OF r;
      `, [dataAlvo]);

      if (selectRes.rowCount === 0) {
        await client.query('COMMIT');
        return { totalConcluidas: 0, reservas: [] };
      }

      const reservasParaConcluir = selectRes.rows;
      const ids = reservasParaConcluir.map((r: any) => r.id);

      // Atualiza o status para CONCLUIDA e preenche checkout_em se nulo (assumindo encerramento às 23:59:59 da data da reserva)
      await client.query(`
        UPDATE reservas
        SET status = 'CONCLUIDA',
            checkout_em = COALESCE(checkout_em, (data_reserva + TIME '23:59:59'))
        WHERE id = ANY($1::int[]);
      `, [ids]);

      // Registrar histórico forense de conclusão
      for (const row of reservasParaConcluir) {
        await ReservaHistoryService.registrarEvento({
          reservaId: row.id,
          cadeiraId: row.cadeira_id,
          usuarioId: row.usuario_id,
          dataReserva: row.data_reserva,
          tipoEvento: 'MESA_LIBERADA',
          executadoPorUsuarioId: null,
          motivo: 'Conclusão automática no encerramento do dia para reserva confirmada com check-in',
          detalhes: {
            comprovante: row.codigo_comprovante,
            cadeiraIdentificador: row.cadeira_identificador,
            escritorioId: row.escritorio_id,
            checkinEm: row.checkin_em,
            tipoEncerramento: 'AUTOMATICO_FIM_DO_DIA'
          }
        }, client);
      }

      await client.query('COMMIT');

      logger.info(`[AutoConclusionJob] ${reservasParaConcluir.length} reservas confirmadas de datas anteriores foram concluídas automaticamente.`);
      return { totalConcluidas: reservasParaConcluir.length, reservas: reservasParaConcluir };
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackErr) {
        logger.error('[AutoConclusionJob] Falha ao executar ROLLBACK:', { error: rollbackErr });
      }
      logger.error('[AutoConclusionJob] Erro ao executar conclusão automática:', { error });
      throw error;
    } finally {
      client.release();
    }
  }
}

