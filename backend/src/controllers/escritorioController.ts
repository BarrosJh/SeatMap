import { Response } from 'express';
import { DateTime } from 'luxon';
import { AuthenticatedRequest } from '../middleware/auth';
import { EscritorioService } from '../services/escritorioService';
import { logger } from '../utils/logger';

export class EscritorioController {
  public static async listar(req: AuthenticatedRequest, res: Response) {
    try {
      const escritorios = await EscritorioService.listar();
      return res.status(200).json(escritorios);
    } catch (error) {
      logger.error('[EscritorioController.listar] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao listar escritórios.' });
    }
  }

  public static async getMapa(req: AuthenticatedRequest, res: Response) {
    const escritorioId = parseInt(req.params.id, 10);
    const dataQuery = req.query.data as string;
    const currentUserId = req.user?.userId;

    if (isNaN(escritorioId)) {
      return res.status(400).json({ error: 'ID de escritório inválido.' });
    }

    const dataReserva = dataQuery || DateTime.now().setZone('America/Sao_Paulo').toISODate()!;

    try {
      const mapa = await EscritorioService.getMapa(escritorioId, dataReserva, currentUserId);
      if (!mapa) {
        return res.status(404).json({ error: 'Escritório não encontrado ou inativo.' });
      }
      return res.status(200).json(mapa);
    } catch (error) {
      logger.error('[EscritorioController.getMapa] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao carregar mapa de assentos.' });
    }
  }

  public static async getOcupacaoSemanal(req: AuthenticatedRequest, res: Response) {
    try {
      const user = req.user || 'COLABORADOR';
      const ocupacao = await EscritorioService.getOcupacaoSemanal(user);
      return res.status(200).json(ocupacao);
    } catch (error) {
      logger.error('[EscritorioController.getOcupacaoSemanal] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao calcular ocupação semanal dos escritórios.' });
    }
  }

  public static async getAvisoGlobal(req: AuthenticatedRequest, res: Response) {
    try {
      const aviso = await EscritorioService.getAvisoGlobal();
      return res.status(200).json({ aviso });
    } catch (error) {
      logger.error('[EscritorioController.getAvisoGlobal] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao obter aviso global do sistema.' });
    }
  }
}
