import { Response } from 'express';
import { AuthenticatedRequest } from '../middleware/auth';
import { ReservaService } from '../services/reservaService';
import { ReservaHistoryService } from '../services/reservaHistoryService';
import { parseIdParam } from '../utils/workWeekUtils';
import { logger } from '../utils/logger';

export class ReservaController {
  public static async criarReserva(req: AuthenticatedRequest, res: Response) {
    const user = req.user!;
    const { cadeiraId, dataReserva } = req.body;
    const idempotencyKey = req.headers['x-idempotency-key'] as string | undefined;

    const numericCadeiraId = parseIdParam(cadeiraId);

    if (!numericCadeiraId || !dataReserva) {
      return res.status(400).json({ error: 'Cadeira e data de reserva são obrigatórios.' });
    }

    try {
      const result = await ReservaService.criarReserva({
        usuarioId: user.userId,
        usuarioNome: user.nome,
        usuarioEmail: user.email,
        usuarioPerfil: user.perfil,
        departamentoId: user.departamentoId,
        departamentoNome: user.departamentoNome,
        cadeiraId: numericCadeiraId,
        dataReserva,
        idempotencyKey,
        correlationId: req.correlationId
      });

      if (!result.success) {
        return res.status(result.code || 400).json({ error: result.error });
      }

      return res.status(result.code || 200).json({
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
    const isRhGlobal = user.permissaoRh === true || user.is_admin === true || user.perfil === 'ADMIN_RH';

    try {
      const result = await ReservaService.fazerCheckin({
        reservaId,
        usuarioId: user.userId,
        usuarioPerfil: user.perfil,
        usuarioDepartamentoId: user.departamentoId,
        isRhGlobal,
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
    const limit = parseInt(req.query.limit as string, 10) || 50;
    const offset = parseInt(req.query.offset as string, 10) || 0;

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
    const limit = parseInt(req.query.limit as string, 10) || 50;
    const offset = parseInt(req.query.offset as string, 10) || 0;

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
      const isRh = user.perfil === 'ADMIN_RH' || user.perfil === 'ADMIN_TI' || user.permissaoRh === true || user.permissaoTi === true || user.is_admin === true;
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
