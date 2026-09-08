export class AppError extends Error {
  public readonly statusCode: number;
  public readonly isOperational: boolean;
  public readonly code?: string;
  public readonly details?: any;

  constructor(message: string, statusCode = 400, details?: any, code?: string) {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
    this.isOperational = true;
    this.details = details;
    this.code = code;

    Error.captureStackTrace(this, this.constructor);
  }

  public static badRequest(message: string, details?: any, code?: string): AppError {
    return new AppError(message, 400, details, code);
  }

  public static unauthorized(message = 'Não autorizado.', details?: any, code?: string): AppError {
    return new AppError(message, 401, details, code);
  }

  public static forbidden(message = 'Acesso negado.', details?: any, code?: string): AppError {
    return new AppError(message, 403, details, code);
  }

  public static notFound(message = 'Recurso não encontrado.', details?: any, code?: string): AppError {
    return new AppError(message, 404, details, code);
  }

  public static conflict(message: string, details?: any, code?: string): AppError {
    return new AppError(message, 409, details, code);
  }

  public static unprocessableEntity(message: string, details?: any, code?: string): AppError {
    return new AppError(message, 422, details, code);
  }

  public static internal(message = 'Erro interno do servidor.', details?: any, code?: string): AppError {
    const err = new AppError(message, 500, details, code);
    (err as any).isOperational = false;
    return err;
  }
}
