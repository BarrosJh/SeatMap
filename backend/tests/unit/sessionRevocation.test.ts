import jwt from 'jsonwebtoken';
import { Request, Response } from 'express';
import pool from '../../src/config/db';
import { authenticateToken, authenticateAdminMfa, AuthenticatedRequest } from '../../src/middleware/auth';
import { TokenService } from '../../src/services/tokenService';
import { ConfigService } from '../../src/services/configService';
import { env } from '../../src/config/env';

const JWT_SECRET = env.JWT_SECRET;
const JWT_ADMIN_SECRET = env.JWT_ADMIN_SECRET;

describe('Instant Session Revocation & Token Versioning (BACEN Compliance)', () => {
  afterAll(async () => {
    // Cleanup if needed
  });

  describe('TokenService.incrementarTokenVersion', () => {
    it('deve executar query de incremento e revogação de refresh tokens', async () => {
      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async (text: any) => {
        const queryStr = String(text).toLowerCase();
        if (queryStr.includes('update usuarios')) {
          return { rows: [{ token_version: 3 }], rowCount: 1 } as any;
        }
        if (queryStr.includes('update auth_refresh_tokens')) {
          return { rows: [], rowCount: 1 } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const newVersion = await TokenService.incrementarTokenVersion(42);
      expect(newVersion).toBe(3);
      expect(querySpy).toHaveBeenCalledWith(expect.stringContaining('UPDATE usuarios'), [42]);
      expect(querySpy).toHaveBeenCalledWith(expect.stringContaining('UPDATE auth_refresh_tokens'), [42]);

      querySpy.mockRestore();
    });
  });

  describe('authenticateToken with token_version validation', () => {
    it('deve rejeitar token quando o usuário estiver inativo no banco', async () => {
      const token = jwt.sign(
        { userId: 10, email: 'inativo@banco.com', tokenVersion: 1 },
        JWT_SECRET
      );

      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => ({
        rowCount: 1,
        rows: [{ ativo: false, token_version: 1 }]
      } as any));

      const req = {
        headers: { authorization: `Bearer ${token}` }
      } as unknown as AuthenticatedRequest;

      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;

      const next = jest.fn();

      await authenticateToken(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.stringContaining('desativada ou inexistente')
      }));
      expect(next).not.toHaveBeenCalled();

      querySpy.mockRestore();
    });

    it('deve rejeitar token com tokenVersion defasada (sessão revogada)', async () => {
      const tokenAntigo = jwt.sign(
        { userId: 10, email: 'colaborador@banco.com', tokenVersion: 1 },
        JWT_SECRET
      );

      // Banco já está na versão 2 (após demissão, reset de senha ou logout global)
      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => ({
        rowCount: 1,
        rows: [{ ativo: true, token_version: 2 }]
      } as any));

      const req = {
        headers: { authorization: `Bearer ${tokenAntigo}` }
      } as unknown as AuthenticatedRequest;

      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;

      const next = jest.fn();

      await authenticateToken(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.stringContaining('Sessão revogada ou credenciais alteradas')
      }));
      expect(next).not.toHaveBeenCalled();

      querySpy.mockRestore();
    });

    it('deve autorizar token com tokenVersion válida e usuário ativo', async () => {
      const tokenValido = jwt.sign(
        { userId: 10, email: 'colaborador@banco.com', tokenVersion: 2, perfil: 'COLABORADOR' },
        JWT_SECRET
      );

      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => ({
        rowCount: 1,
        rows: [{ ativo: true, token_version: 2 }]
      } as any));

      const req = {
        headers: { authorization: `Bearer ${tokenValido}` }
      } as unknown as AuthenticatedRequest;

      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;

      const next = jest.fn();

      await authenticateToken(req, res, next);

      expect(next).toHaveBeenCalled();
      expect(req.user?.userId).toBe(10);
      expect(res.status).not.toHaveBeenCalled();

      querySpy.mockRestore();
    });

    it('deve rejeitar com 503 (Fail-Close) se o banco de dados falhar durante a validação de credenciais', async () => {
      const tokenValido = jwt.sign(
        { userId: 10, email: 'colaborador@banco.com', tokenVersion: 1 },
        JWT_SECRET
      );

      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => {
        throw new Error('Connection failure');
      });

      const req = {
        headers: { authorization: `Bearer ${tokenValido}` }
      } as unknown as AuthenticatedRequest;

      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;

      const next = jest.fn();

      await authenticateToken(req, res, next);

      expect(res.status).toHaveBeenCalledWith(503);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.stringContaining('Serviço temporariamente indisponível')
      }));
      expect(next).not.toHaveBeenCalled();

      querySpy.mockRestore();
    });
  });

  describe('authenticateAdminMfa Fail-Close & Enforcement', () => {
    it('deve retornar HTTP 500 (Fail-Close) se ocorrer erro inesperado no banco ao verificar política de MFA', async () => {
      jest.spyOn(ConfigService, 'get').mockRejectedValue(new Error('PostgreSQL Pool Connection Timeout'));

      const req = {
        headers: {},
        user: { userId: 1, perfil: 'ADMIN_RH', permissaoRh: true }
      } as unknown as AuthenticatedRequest;

      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;

      const next = jest.fn();

      await authenticateAdminMfa(req, res, next);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.stringContaining('Erro de segurança ao validar autenticação em duas etapas')
      }));
      expect(next).not.toHaveBeenCalled();
      expect(req.isAdminMfaValidated).toBeUndefined();
    });

    it('deve barrar acesso com HTTP 403 se MFA for obrigatório e cabeçalho x-admin-token estiver ausente', async () => {
      jest.spyOn(ConfigService, 'get').mockResolvedValue('OBRIGATORIO_RH');

      const req = {
        headers: {},
        user: { userId: 1, perfil: 'ADMIN_RH', permissaoRh: true }
      } as unknown as AuthenticatedRequest;

      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;

      const next = jest.fn();

      await authenticateAdminMfa(req, res, next);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        requiresAdminMfa: true
      }));
      expect(next).not.toHaveBeenCalled();
    });

    it('deve autorizar acesso quando x-admin-token for um JWT válido do mesmo usuário', async () => {
      jest.spyOn(ConfigService, 'get').mockResolvedValue('OBRIGATORIO_RH');

      const adminToken = jwt.sign({ userId: 99, tipo: 'ADMIN_STEP_UP' }, JWT_ADMIN_SECRET);

      const req = {
        headers: { 'x-admin-token': adminToken },
        user: { userId: 99, perfil: 'ADMIN_RH', permissaoRh: true }
      } as unknown as AuthenticatedRequest;

      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;

      const next = jest.fn();

      await authenticateAdminMfa(req, res, next);

      expect(req.isAdminMfaValidated).toBe(true);
      expect(next).toHaveBeenCalled();
    });
  });
});



