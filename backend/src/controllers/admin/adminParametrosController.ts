import { Response } from 'express';
import { DateTime } from 'luxon';
import { AuthenticatedRequest } from '../../middleware/auth';
import { ParametrosService } from '../../services/admin/parametrosService';
import { CronService } from '../../services/cronService';
import { ExportService } from '../../services/exportService';
import { logger } from '../../utils/logger';

export class AdminParametrosController {
  public static async getParametros(req: AuthenticatedRequest, res: Response) {
    try {
      const parametros = await ParametrosService.getParametros();
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
      const resultado = await ParametrosService.updateParametros(configuracoes);
      if (!resultado.success) {
        return res.status(resultado.code || 400).json({ error: resultado.error });
      }

      return res.status(200).json({
        message: resultado.message,
        parametros: resultado.parametros
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
      return await ExportService.exportarCsvParametros(dataAlvo, res);
    } catch (error) {
      logger.error('[AdminParametrosController.exportarRelatorioCsv] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao gerar relatório CSV.' });
    }
  }
}
