import { Request, Response } from 'express';
import { AuthenticatedRequest, userHasPermission, isRhGlobal } from '../middleware/auth';
import { ReservaService } from '../services/reservaService';
import { ReservaHistoryService } from '../services/reservaHistoryService';
import { parseIdParam } from '../utils/workWeekUtils';
import { logger } from '../utils/logger';

export class ReservaController {
  public static async criarReserva(req: AuthenticatedRequest, res: Response) {
    const user = req.user!;
    const { cadeiraId, dataReserva, idempotencyKey } = req.body;

    try {
      const result = await ReservaService.criarReserva({
        cadeiraId: Number(cadeiraId),
        usuarioId: user.userId,
        usuarioNome: user.nome,
        usuarioEmail: user.email,
        usuarioPerfil: user.perfil,
        departamentoId: user.departamentoId,
        departamentoNome: user.departamentoNome,
        dataReserva,
        idempotencyKey,
        correlationId: req.correlationId
      });

      if (!result.success) {
        return res.status(result.code || 400).json({ error: result.error });
      }

      return res.status(result.code || 201).json({
        message: result.message,
        comprovante: result.comprovante,
        reserva: result.reserva,
        trocaRealizada: result.trocaRealizada
      });
    } catch (error) {
      logger.error('[ReservaController.criarReserva] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro interno ao processar a reserva.' });
    }
  }

  public static async fazerCheckin(req: AuthenticatedRequest, res: Response) {
    const user = req.user!;
    const reservaId = parseIdParam(req.params.id);

    if (!reservaId) {
      return res.status(400).json({ error: 'ID de reserva inválido.' });
    }

    const { cadeiraId } = req.body || {};
    const cadeiraIdInformada = cadeiraId ? parseIdParam(cadeiraId) || undefined : undefined;
    const isGlobalRh = isRhGlobal(user);

    try {
      const result = await ReservaService.fazerCheckin({
        reservaId,
        usuarioId: user.userId,
        usuarioPerfil: user.perfil,
        usuarioDepartamentoId: user.departamentoId,
        isRhGlobal: isGlobalRh,
        cadeiraIdInformada,
        correlationId: req.correlationId
      });

      if (!result.success) {
        return res.status(result.code || 400).json({ error: result.error });
      }

      return res.status(result.code || 200).json({
        message: result.message,
        comprovante: result.comprovante,
        checkinEm: result.checkinEm,
        reserva: result.reserva
      });
    } catch (error) {
      logger.error('[ReservaController.fazerCheckin] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao realizar check-in.' });
    }
  }

  public static async cancelarReserva(req: AuthenticatedRequest, res: Response) {
    const user = req.user!;
    const reservaId = parseIdParam(req.params.id);

    if (!reservaId) {
      return res.status(400).json({ error: 'ID de reserva inválido.' });
    }

    try {
      const result = await ReservaService.cancelarReserva(reservaId, user.userId);

      if (!result.success) {
        return res.status(result.code || 400).json({ error: result.error });
      }

      return res.status(result.code || 200).json({
        message: result.message,
        reserva: result.reserva
      });
    } catch (error) {
      logger.error('[ReservaController.cancelarReserva] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao cancelar reserva.' });
    }
  }

  public static async liberarMesa(req: AuthenticatedRequest, res: Response) {
    const user = req.user!;
    const reservaId = parseIdParam(req.params.id);

    if (!reservaId) {
      return res.status(400).json({ error: 'ID de reserva inválido.' });
    }

    try {
      const result = await ReservaService.liberarMesa(reservaId, user.userId, req.correlationId);

      if (!result.success) {
        return res.status(result.code || 400).json({ error: result.error });
      }

      return res.status(result.code || 200).json({
        message: result.message,
        reserva: result.reserva
      });
    } catch (error) {
      logger.error('[ReservaController.liberarMesa] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao liberar mesa.' });
    }
  }

  public static async historicoMinhasReservas(req: AuthenticatedRequest, res: Response) {
    const user = req.user!;
    const rawLimit = parseInt(req.query.limit as string, 10);
    const rawOffset = parseInt(req.query.offset as string, 10);
    const limit = Math.min(Math.max(1, isNaN(rawLimit) ? 50 : rawLimit), 100);
    const offset = Math.max(0, isNaN(rawOffset) ? 0 : rawOffset);

    try {
      const historico = await ReservaHistoryService.getHistoricoUsuario(user.userId, limit, offset);
      return res.status(200).json(historico);
    } catch (error) {
      logger.error('[ReservaController.historicoMinhasReservas] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao consultar histórico de movimentações do usuário.' });
    }
  }

  public static async minhasReservas(req: AuthenticatedRequest, res: Response) {
    const user = req.user!;
    const rawLimit = parseInt(req.query.limit as string, 10);
    const rawOffset = parseInt(req.query.offset as string, 10);
    const limit = Math.min(Math.max(1, isNaN(rawLimit) ? 50 : rawLimit), 100);
    const offset = Math.max(0, isNaN(rawOffset) ? 0 : rawOffset);

    try {
      const rows = await ReservaService.minhasReservas(user.userId, limit, offset);
      return res.status(200).json(rows);
    } catch (error) {
      logger.error('[ReservaController.minhasReservas] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao listar reservas do usuário.' });
    }
  }

  public static async enviarComprovanteEmail(req: AuthenticatedRequest, res: Response) {
    const user = req.user!;
    const reservaId = parseIdParam(req.params.id);

    if (!reservaId) {
      return res.status(400).json({ error: 'ID de reserva inválido.' });
    }

    try {
      const isRh = userHasPermission(user, 'reservas:read');
      const result = await ReservaService.enviarComprovanteEmail(
        reservaId,
        user.userId,
        user.email,
        user.perfil,
        isRh,
        req.correlationId
      );

      if (!result.success) {
        return res.status(result.code || 400).json({ error: result.error });
      }

      return res.status(result.code || 200).json({
        message: result.message,
        email: result.email
      });
    } catch (error) {
      logger.error('[ReservaController.enviarComprovanteEmail] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao enviar comprovante por e-mail.' });
    }
  }
}
