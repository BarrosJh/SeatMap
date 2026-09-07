import { Response } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth';
import { FacilitiesService } from '../../services/facilitiesService';
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

    try {
      const result = await FacilitiesService.colocarCadeiraEmManutencao(
        cadeiraId,
        motivo,
        previsaoRetorno,
        user.userId,
        req.correlationId
      );

      if (!result.success) {
        return res.status(result.code || 400).json({ error: result.error });
      }

      return res.status(200).json({
        message: result.message,
        reservasCanceladas: result.reservasCanceladas,
        cadeira: result.cadeira
      });
    } catch (error) {
      logger.error('[FacilitiesController.colocarCadeiraEmManutencao] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao bloquear assento para manutenção.' });
    }
  }

  public static async liberarCadeiraManutencao(req: AuthenticatedRequest, res: Response) {
    const cadeiraId = parseInt(req.params.id, 10);

    if (isNaN(cadeiraId)) {
      return res.status(400).json({ error: 'ID de cadeira inválido.' });
    }

    try {
      const result = await FacilitiesService.liberarCadeiraManutencao(cadeiraId);

      if (!result) {
        return res.status(404).json({ error: 'Cadeira não encontrada.' });
      }

      return res.status(200).json(result);
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
      const historico = await FacilitiesService.getHistoricoCadeira(cadeiraId, limit, offset);
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
      const data = await FacilitiesService.getCadeirasManutencao(
        escritorioId as string | undefined,
        busca as string | undefined
      );
      return res.status(200).json(data);
    } catch (error) {
      logger.error('[FacilitiesController.getCadeirasManutencao] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao buscar assentos em manutenção.' });
    }
  }

  public static async getTodasCadeiras(req: AuthenticatedRequest, res: Response) {
    try {
      const { escritorioId } = req.query;
      const cadeiras = await FacilitiesService.getTodasCadeiras(escritorioId as string | undefined);
      return res.status(200).json(cadeiras);
    } catch (error) {
      logger.error('[FacilitiesController.getTodasCadeiras] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao listar todas as cadeiras.' });
    }
  }
}
