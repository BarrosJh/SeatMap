import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { AppError } from '../errors/AppError';
import { logger } from '../utils/logger';

export function errorHandler(err: any, req: Request, res: Response, _next: NextFunction) {
  if (res.headersSent) {
    logger.warn('[errorHandler] Headers já enviados, delegando ao runtime:', { error: err });
    return;
  }

  const correlationId = (req as any).correlationId;

  // 1. Erros Operacionais (AppError)
  if (err instanceof AppError) {
    if (err.statusCode >= 500) {
      logger.error(`[AppError ${err.statusCode}]: ${err.message}`, { correlationId, error: err, details: err.details });
    } else {
      logger.warn(`[AppError ${err.statusCode}]: ${err.message}`, { correlationId, path: req.path, method: req.method });
    }

    return res.status(err.statusCode).json({
      error: err.message,
      ...(err.code ? { code: err.code } : {}),
      ...(err.details ? { details: err.details } : {})
    });
  }

  // 2. Erros de Validação Zod
  if (err instanceof ZodError) {
    const firstIssue = err.issues[0];
    const errorMessage = firstIssue ? firstIssue.message : 'Dados da requisição inválidos.';

    logger.warn('[ZodError Validation]:', {
      correlationId,
      path: req.path,
      method: req.method,
      issues: err.issues
    });

    return res.status(400).json({
      error: errorMessage,
      details: err.issues.map(i => ({
        campo: i.path.join('.'),
        mensagem: i.message,
        codigo: i.code
      }))
    });
  }

  // 3. Erro de Sintaxe JSON no Body
  if (err instanceof SyntaxError && (err as any).status === 400 && 'body' in err) {
    logger.warn('[JSON SyntaxError]: Payload JSON malformado.', { correlationId, path: req.path });
    return res.status(400).json({ error: 'Payload JSON malformado.' });
  }

  // 4. Erros Inesperados / Não-Operacionais (500)
  logger.error('[Unhandled Internal Error]:', {
    correlationId,
    path: req.path,
    method: req.method,
    error: err
  });

  return res.status(500).json({
    error: 'Erro interno do servidor.'
  });
}
