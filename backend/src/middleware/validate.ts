import { Request, Response, NextFunction } from 'express';
import { ZodSchema, ZodError } from 'zod';

/**
 * @deprecated Utilize `validateRequest` em `middleware/validateRequest.ts` para validação declarativa unificada (body, params, query).
 */
export function validateBody(schema: ZodSchema) {
  return (req: Request, res: Response, next: NextFunction) => {
    try {
      req.body = schema.parse(req.body);
      next();
    } catch (err) {
      if (err instanceof ZodError) {
        const firstIssue = err.issues[0];
        return res.status(400).json({
          error: firstIssue ? `${firstIssue.path.join('.') ? firstIssue.path.join('.') + ': ' : ''}${firstIssue.message}` : 'Payload de requisição inválido.',
          detalhes: err.issues
        });
      }
      return res.status(400).json({ error: 'Falha na validação dos dados de entrada.' });
    }
  };
}

