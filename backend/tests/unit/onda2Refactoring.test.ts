import { Request, Response, NextFunction } from 'express';
import { ZodError, z } from 'zod';
import { AppError } from '../../src/errors/AppError';
import { errorHandler } from '../../src/middleware/errorHandler';
import {
  criarUsuarioSchema,
  editarUsuarioSchema,
  importarLoteUsuariosSchema,
  loginSchema,
  redefinirSenhaSchema,
  colocarManutencaoSchema
} from '../../src/schemas';

describe('Onda 2: Tratamento Centralizado de Erros & Schemas Zod Modulares', () => {
  let mockReq: any;
  let mockRes: any;
  let mockNext: NextFunction;
  let statusMock: jest.Mock;
  let jsonMock: jest.Mock;

  beforeEach(() => {
    jest.clearAllMocks();
    statusMock = jest.fn().mockReturnThis();
    jsonMock = jest.fn();
    mockNext = jest.fn();

    mockReq = {
      body: {},
      query: {},
      params: {},
      path: '/api/test',
      method: 'POST',
      correlationId: 'cid-onda2-test'
    };

    mockRes = {
      status: statusMock,
      json: jsonMock,
      setHeader: jest.fn(),
      send: jest.fn(),
      end: jest.fn(),
      headersSent: false
    };
  });

  describe('1. Classe Padronizada AppError', () => {
    it('deve instanciar AppError com valores padrão e operacionais', () => {
      const err = new AppError('Acesso inválido', 400);
      expect(err.message).toBe('Acesso inválido');
      expect(err.statusCode).toBe(400);
      expect(err.isOperational).toBe(true);
      expect(err.name).toBe('AppError');
    });

    it('deve instanciar via métodos de fábrica (badRequest, unauthorized, forbidden, notFound, conflict, internal)', () => {
      const badReq = AppError.badRequest('Payload incorreto', { field: 'email' });
      expect(badReq.statusCode).toBe(400);
      expect(badReq.details).toEqual({ field: 'email' });

      const unauth = AppError.unauthorized('Token expirado');
      expect(unauth.statusCode).toBe(401);

      const forb = AppError.forbidden('Sem permissão de TI');
      expect(forb.statusCode).toBe(403);

      const notFnd = AppError.notFound('Mesa não encontrada');
      expect(notFnd.statusCode).toBe(404);

      const confl = AppError.conflict('Conflito de reserva no mesmo horário');
      expect(confl.statusCode).toBe(409);

      const unproc = AppError.unprocessableEntity('Regra de negócio violada');
      expect(unproc.statusCode).toBe(422);

      const intern = AppError.internal('Falha interna');
      expect(intern.statusCode).toBe(500);
      expect(intern.isOperational).toBe(false);
    });
  });

  describe('2. Middleware Global errorHandler', () => {
    it('deve processar AppError com status code e mensagem customizados', () => {
      const appErr = AppError.forbidden('Apenas administradores de RH podem acessar.');
      errorHandler(appErr, mockReq, mockRes, mockNext);

      expect(statusMock).toHaveBeenCalledWith(403);
      expect(jsonMock).toHaveBeenCalledWith({
        error: 'Apenas administradores de RH podem acessar.'
      });
    });

    it('deve processar ZodError com status 400 e lista de detalhes de validação', () => {
      const dummySchema = z.object({
        nome: z.string().min(3, 'Nome muito curto')
      });
      const result = dummySchema.safeParse({ nome: 'a' });
      expect(result.success).toBe(false);

      if (!result.success) {
        errorHandler(result.error, mockReq, mockRes, mockNext);
        expect(statusMock).toHaveBeenCalledWith(400);
        expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
          error: 'Nome muito curto',
          details: expect.arrayContaining([
            expect.objectContaining({ campo: 'nome', mensagem: 'Nome muito curto' })
          ])
        }));
      }
    });

    it('deve capturar SyntaxError de JSON e retornar 400 amigável', () => {
      const syntaxErr: any = new SyntaxError('Unexpected token in JSON');
      syntaxErr.status = 400;
      syntaxErr.body = '{ bad json';

      errorHandler(syntaxErr, mockReq, mockRes, mockNext);
      expect(statusMock).toHaveBeenCalledWith(400);
      expect(jsonMock).toHaveBeenCalledWith({ error: 'Payload JSON malformado.' });
    });

    it('deve mascarar erro inesperado / crash com 500 sem vazar stack trace', () => {
      const crashErr = new Error('Database connection reset by peer at /secrets/db.ts:99');
      errorHandler(crashErr, mockReq, mockRes, mockNext);

      expect(statusMock).toHaveBeenCalledWith(500);
      expect(jsonMock).toHaveBeenCalledWith({
        error: 'Erro interno do servidor.'
      });
    });

    it('não deve enviar resposta se os headers já tiverem sido enviados', () => {
      mockRes.headersSent = true;
      const err = new Error('Stream error');
      errorHandler(err, mockReq, mockRes, mockNext);

      expect(statusMock).not.toHaveBeenCalled();
      expect(jsonMock).not.toHaveBeenCalled();
    });
  });

  describe('3. Schemas Zod Modulares (src/schemas)', () => {
    it('deve validar criação e edição de usuário', () => {
      const validUser = {
        nome: 'Carlos Silva',
        email: 'carlos@empresa.com',
        matricula: 'USR0099',
        senha: 'SenhaForte@123',
        perfil: 'COLABORADOR'
      };
      expect(criarUsuarioSchema.safeParse(validUser).success).toBe(true);

      const invalidUser = {
        nome: 'C',
        email: 'invalid-email',
        matricula: '1',
        senha: '123',
        perfil: 'INVALID_ROLE'
      };
      expect(criarUsuarioSchema.safeParse(invalidUser).success).toBe(false);

      const editUser = {
        nome: 'Carlos Editado'
      };
      expect(editarUsuarioSchema.safeParse(editUser).success).toBe(true);
    });

    it('deve validar schema de importação de usuários em lote', () => {
      const validLote = {
        usuarios: [
          { nome: 'Ana Souza', email: 'ana@empresa.com', matricula: 'USR101' }
        ]
      };
      expect(importarLoteUsuariosSchema.safeParse(validLote).success).toBe(true);

      const emptyLote = { usuarios: [] };
      expect(importarLoteUsuariosSchema.safeParse(emptyLote).success).toBe(false);
    });

    it('deve validar schema de autenticação e redefinição de senha', () => {
      expect(loginSchema.safeParse({ login: 'usr01', senha: '123' }).success).toBe(true);
      expect(loginSchema.safeParse({ login: '', senha: '' }).success).toBe(false);

      expect(redefinirSenhaSchema.safeParse({ login: 'usuario@empresa.com', codigo: '123456', novaSenha: 'NovaSenha@123' }).success).toBe(true);
      expect(redefinirSenhaSchema.safeParse({ login: '', codigo: '123', novaSenha: '123' }).success).toBe(false);
    });

    it('deve validar schema de manutenção de facilities', () => {
      expect(colocarManutencaoSchema.safeParse({ motivo: 'Troca de pistão hidráulico' }).success).toBe(true);
      expect(colocarManutencaoSchema.safeParse({ motivo: '' }).success).toBe(false);
    });
  });
});
