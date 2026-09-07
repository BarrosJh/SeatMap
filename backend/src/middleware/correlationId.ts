import { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';
import { logger, Logger } from '../utils/logger';

declare global {
  namespace Express {
    interface Request {
      correlationId?: string;
      logger?: Logger;
    }
  }
}

export const correlationIdMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const headerCorrelationId = (req.headers['x-correlation-id'] || req.headers['x-request-id']) as string | undefined;

  // Sanitizar ou gerar novo UUID
  const correlationId = (headerCorrelationId && headerCorrelationId.trim().length > 0 && headerCorrelationId.length <= 128)
    ? headerCorrelationId.trim()
    : crypto.randomUUID();

  req.correlationId = correlationId;
  req.logger = logger.child({ correlationId });

  res.setHeader('X-Correlation-Id', correlationId);

  next();
};

