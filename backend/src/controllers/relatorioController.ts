import { Response } from 'express';
import { AuthenticatedRequest } from '../middleware/auth';
import { RelatorioService } from '../services/relatorioService';
import { ExportService } from '../services/exportService';
import { logger } from '../utils/logger';

export class RelatorioController {
  /**
   * 1. GET /api/admin/relatorios/analytics
   * Retorna os KPIs e resumos agregados para visualização nos cards de BI
   */
  public static async getAnalytics(req: AuthenticatedRequest, res: Response) {
    try {
      const analytics = await RelatorioService.getAnalytics(req.query);
      return res.status(200).json(analytics);
    } catch (error: any) {
      if (error.statusCode === 400) {
        return res.status(400).json({ error: error.message });
      }
      logger.error('[RelatorioController.getAnalytics] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao consolidar analytics do relatório.' });
    }
  }

  /**
   * 2. GET /api/admin/relatorios/dados
   * Retorna os registros tabulares com paginação e busca para exibição em tabela
   */
  public static async getDadosRelatorio(req: AuthenticatedRequest, res: Response) {
    try {
      const dados = await RelatorioService.getDadosRelatorio(req.query);
      return res.status(200).json(dados);
    } catch (error: any) {
      if (error.statusCode === 400) {
        return res.status(400).json({ error: error.message });
      }
      logger.error('[RelatorioController.getDadosRelatorio] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao buscar dados do relatório.' });
    }
  }

  /**
   * 3. GET /api/admin/relatorios/exportar/xlsx
   * Gera uma planilha Excel formatada e profissional com exceljs
   */
  public static async exportarXlsx(req: AuthenticatedRequest, res: Response) {
    try {
      const exportData = await RelatorioService.getExportData(req.query, 10000);
      return await ExportService.exportarExcel(exportData, res);
    } catch (error: any) {
      if (error.statusCode === 400) {
        return res.status(400).json({ error: error.message });
      }
      logger.error('[RelatorioController.exportarXlsx] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao gerar planilha Excel.' });
    }
  }

  /**
   * 4. GET /api/admin/relatorios/exportar/pdf
   * Gera um relatório executivo em PDF diagramado em A4 Landscape com pdfkit
   */
  public static async exportarPdf(req: AuthenticatedRequest, res: Response) {
    try {
      const exportData = await RelatorioService.getExportData(req.query, 2000);
      return await ExportService.exportarPdf(exportData, res, req.correlationId);
    } catch (error: any) {
      if (error.statusCode === 400) {
        if (!res.headersSent) {
          return res.status(400).json({ error: error.message });
        }
      }
      logger.error('[RelatorioController.exportarPdf] Erro:', { correlationId: req.correlationId, error });
      if (!res.headersSent) {
        return res.status(500).json({ error: 'Erro ao gerar relatório em PDF.' });
      }
      res.destroy();
    }
  }
}

