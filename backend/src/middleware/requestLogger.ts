import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';
import { MetricsService } from '../services/metricsService';

export const requestLoggerMiddleware = (req: Request, res: Response, next: NextFunction) => {
  // Ignora logs ruidosos de polling de health se não estiver em debug
  const isHealth = req.path.startsWith('/api/health') || req.path === '/health';
  if (isHealth && process.env.LOG_HEALTH_PROBES !== 'true') {
    return next();
  }

  const startTime = process.hrtime();
  MetricsService.requestStarted();
  const ip = req.ip || req.socket.remoteAddress || 'unknown';
  const correlationId = req.correlationId;

  res.on('finish', () => {
    const diff = process.hrtime(startTime);
    const durationMs = Math.round((diff[0] * 1e3 + diff[1] * 1e-6) * 100) / 100;

    const logContext = {
      correlationId,
      method: req.method,
      path: req.originalUrl || req.path,
      statusCode: res.statusCode,
      durationMs,
      ip,
      userAgent: req.headers['user-agent']
    };

    const reqLogger = req.logger || logger;
    MetricsService.requestFinished(req.route?.path || req.path, res.statusCode, durationMs);

    if (res.statusCode >= 500) {
      reqLogger.error(`HTTP ${req.method} ${req.originalUrl || req.path} ${res.statusCode} (${durationMs}ms)`, logContext);
    } else if (res.statusCode >= 400) {
      reqLogger.warn(`HTTP ${req.method} ${req.originalUrl || req.path} ${res.statusCode} (${durationMs}ms)`, logContext);
    } else {
      reqLogger.info(`HTTP ${req.method} ${req.originalUrl || req.path} ${res.statusCode} (${durationMs}ms)`, logContext);
    }
  });

  next();
};

