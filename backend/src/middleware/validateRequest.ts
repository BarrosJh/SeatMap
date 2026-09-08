import { Request, Response, NextFunction } from 'express';
import { ZodSchema, ZodError } from 'zod';
import { logger } from '../utils/logger';

export interface RequestValidationSchemas {
  body?: ZodSchema<any>;
  query?: ZodSchema<any>;
  params?: ZodSchema<any>;
}

/**
 * Middleware genérico de validação declarativa com Zod.
 * Valida body, query e/ou params antes de passar a requisição ao Controller.
 */
export function validateRequest(schemas: RequestValidationSchemas) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (schemas.params) {
        const parsedParams = await schemas.params.parseAsync(req.params);
        req.params = parsedParams;
      }

      if (schemas.query) {
        const parsedQuery = await schemas.query.parseAsync(req.query);
        req.query = parsedQuery;
      }

      if (schemas.body) {
        const parsedBody = await schemas.body.parseAsync(req.body);
        req.body = parsedBody;
      }

      return next();
    } catch (error) {
      if (error instanceof ZodError) {
        const firstIssue = error.issues[0];
        const errorMessage = firstIssue ? firstIssue.message : 'Dados da requisição inválidos.';

        logger.warn('[validateRequest] Falha de validação de payload:', {
          path: req.path,
          method: req.method,
          issues: error.issues
        });

        return res.status(400).json({
          error: errorMessage,
          details: error.issues.map(i => ({
            campo: i.path.join('.'),
            mensagem: i.message,
            codigo: i.code
          }))
        });
      }

      logger.error('[validateRequest] Erro inesperado na validação:', { error });
      return res.status(400).json({ error: 'Erro ao validar dados da requisição.' });
    }
  };
}

