import { Response } from 'express';
import { DateTime } from 'luxon';
import pool from '../../config/db';
import { AuthenticatedRequest } from '../../middleware/auth';
import { ConfigService } from '../../services/configService';
import { CronService } from '../../services/cronService';
import { wsManager } from '../../websocket/wsServer';
import { logger } from '../../utils/logger';

import { sanitizeCsvCell } from '../../utils/sanitizer';

export class AdminParametrosController {
  public static async getParametros(req: AuthenticatedRequest, res: Response) {
    try {
      const parametros = await ConfigService.getAll();
      return res.status(200).json(parametros);
    } catch (error) {
      logger.error('[AdminParametrosController.getParametros] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao buscar parâmetros do sistema.' });
    }
  }

  public static async updateParametros(req: AuthenticatedRequest, res: Response) {
    const { configuracoes } = req.body;

    if (!configuracoes) {
      return res.status(400).json({ error: 'Nenhuma configuração enviada para atualização.' });
    }

    try {
      if (Array.isArray(configuracoes)) {
        for (const item of configuracoes) {
          if (item.chave && item.valor !== undefined) {
            await ConfigService.set(item.chave, item.valor.toString(), item.descricao);
          }
        }
      } else if (typeof configuracoes === 'object') {
        for (const [chave, valor] of Object.entries(configuracoes)) {
          await ConfigService.set(chave, String(valor));
        }
      }

      const atualizadas = await ConfigService.getAll();
      const avisoAtualizado = await ConfigService.get('AVISO_GLOBAL_SISTEMA', '');
      wsManager.broadcastToAll({
        tipo: 'AVISO_GLOBAL_ATUALIZADO',
        aviso: avisoAtualizado
      });

      return res.status(200).json({
        message: 'Configurações atualizadas com sucesso.',
        parametros: atualizadas
      });
    } catch (error) {
      logger.error('[AdminParametrosController.updateParametros] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao atualizar configurações.' });
    }
  }

  public static async executarLimpezaNoShow(req: AuthenticatedRequest, res: Response) {
    const { data } = req.body;
    try {
      const resultado = await CronService.cancelExpiredNoShows(data);
      return res.status(200).json({
        message: 'Rotina de limpeza de No-Show executada com sucesso.',
        totalExpiradas: resultado.totalExpiradas,
        detalhes: resultado.reservas
      });
    } catch (error) {
      logger.error('[AdminParametrosController.executarLimpezaNoShow] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao executar limpeza de No-Show.' });
    }
  }

  public static async exportarRelatorioCsv(req: AuthenticatedRequest, res: Response) {
    const dataQuery = req.query.data as string;
    const dataAlvo = dataQuery || DateTime.now().setZone('America/Sao_Paulo').toISODate()!;

    try {
      const result = await pool.query(`
        SELECT 
          u.matricula,
          u.nome AS colaborador,
          d.nome AS departamento,
          e.nome AS escritorio,
          b.nome AS baia,
          c.identificador AS assento,
          r.data_reserva,
          r.status,
          r.checkin_realizado,
          r.checkin_em
        FROM reservas r
        JOIN usuarios u ON r.usuario_id = u.id
        LEFT JOIN departamentos d ON u.departamento_id = d.id
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        JOIN escritorios e ON b.escritorio_id = e.id
        WHERE r.data_reserva = $1
        ORDER BY e.nome ASC, b.nome ASC, c.identificador ASC
      `, [dataAlvo]);

      const headers = ['Matrícula', 'Colaborador', 'Departamento', 'Escritório', 'Baia', 'Assento', 'Data Reserva', 'Status', 'Check-in Realizado', 'Horário Check-in'];
      const csvLines = [headers.join(';')];

      for (const row of result.rows) {
        const checkinFormatado = row.checkin_em ? DateTime.fromJSDate(row.checkin_em).setZone('America/Sao_Paulo').toFormat('dd/MM/yyyy HH:mm:ss') : 'N/A';
        const dataReservaFormatada = typeof row.data_reserva === 'string'
          ? row.data_reserva
          : DateTime.fromJSDate(row.data_reserva).toFormat('dd/MM/yyyy');

        const line = [
          sanitizeCsvCell(row.matricula || ''),
          sanitizeCsvCell(row.colaborador || ''),
          sanitizeCsvCell(row.departamento || ''),
          sanitizeCsvCell(row.escritorio || ''),
          sanitizeCsvCell(row.baia || ''),
          sanitizeCsvCell(row.assento || ''),
          sanitizeCsvCell(dataReservaFormatada),
          sanitizeCsvCell(row.status),
          sanitizeCsvCell(row.checkin_realizado ? 'SIM' : 'NÃO'),
          sanitizeCsvCell(checkinFormatado)
        ];
        csvLines.push(line.join(';'));
      }

      const csvContent = '\uFEFF' + csvLines.join('\r\n');

      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename=relatorio_reservas_${dataAlvo}.csv`);
      return res.status(200).send(csvContent);
    } catch (error) {
      logger.error('[AdminParametrosController.exportarRelatorioCsv] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao gerar relatório CSV.' });
    }
  }
}
