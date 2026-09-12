import { Request, Response } from 'express';
import pool from '../../src/config/db';
import { env } from '../../src/config/env';
import { JwtCryptoUtils } from '../../src/config/jwtCryptoUtils';
import { TokenService } from '../../src/services/tokenService';
import { ConfigService } from '../../src/services/configService';
import { authenticateToken, authenticateAdminMfa } from '../../src/middleware/auth';
import { isProximaSemanaLiberada } from '../../src/utils/workWeekUtils';
import { DateTime } from 'luxon';

describe('Wave 5: Enterprise Security Compliance & Hardening', () => {
  let mockReq: any;
  let mockRes: any;
  let nextMock: jest.Mock;
  let statusMock: jest.Mock;
  let jsonMock: jest.Mock;

  beforeEach(() => {
    jest.clearAllMocks();
    statusMock = jest.fn().mockReturnThis();
    jsonMock = jest.fn();
    nextMock = jest.fn();

    mockReq = {
      user: {
        userId: 1,
        nome: 'Admin RH',
        email: 'rh@empresa.com',
        matricula: 'RH001',
        perfil: 'ADMIN_RH',
        permissaoRh: true,
        permissaoTi: false,
        departamentoId: 1
      },
      params: {},
      query: {},
      body: {},
      headers: {},
      correlationId: 'cid-wave5-test'
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

  describe('1. Web Policy, Tokens & Env Hardening', () => {
    it('deve possuir JWT_EXPIRATION padronizado para 15m e JWT_ADMIN_EXPIRATION para 15m', () => {
      expect(env.JWT_EXPIRATION).toBe('15m');
      expect(env.JWT_ADMIN_EXPIRATION).toBe('15m');
    });
  });

  describe('2. Timeout Absoluto Server-Side de 60 minutos', () => {
    it('deve rejeitar rotação de refresh token se a sessão inicial tiver mais de 60 minutos (3600s)', async () => {
      const nowSeconds = Math.floor(Date.now() / 1000);
      const expiredAuthTime = nowSeconds - 3700; // 3700 segundos atrás (> 3600)

      const mockDbRow = {
        id: 100,
        usuario_id: 1,
        token_hash: 'somehash',
        family_id: 'fam-123',
        expira_em: new Date(Date.now() + 86400000),
        revogado: false,
        substituido_por: null,
        criado_em: new Date(expiredAuthTime * 1000),
        session_start: new Date(expiredAuthTime * 1000)
      };

      const originalQuery = pool.query;
      (pool.query as any) = jest.fn().mockImplementation(async (sql: string, params?: any[]) => {
        if (sql.includes('SELECT') && sql.includes('auth_refresh_tokens')) {
          return { rowCount: 1, rows: [mockDbRow] };
        }
        if (sql.includes('SELECT') && sql.includes('usuarios')) {
          return {
            rowCount: 1,
            rows: [{
              id: 1,
              nome: 'Teste',
              email: 'test@empresa.com',
              matricula: 'T01',
              perfil: 'COLABORADOR',
              permissao_rh: false,
              permissao_ti: false,
              departamento_id: 1,
              token_version: 1,
              ativo: true
            }]
          };
        }
        if (sql.includes('UPDATE auth_refresh_tokens') && sql.includes('SET revogado = true')) {
          return { rowCount: 1, rows: [] };
        }
        return { rowCount: 0, rows: [] };
      });

      try {
        const result = await TokenService.rotacionarRefreshToken('raw-refresh-token', '127.0.0.1', 'jest-agent');
        expect(result.success).toBe(false);
        expect(result.error).toContain('60 minutos');
      } finally {
        pool.query = originalQuery;
      }
    });

    it('deve bloquear requisição no authenticateToken se authTime no JWT exceder 3600 segundos', async () => {
      const pastAuthTime = Math.floor(Date.now() / 1000) - 3650; // > 1h
      const token = JwtCryptoUtils.signToken({
        userId: 1,
        nome: 'Usuario Teste',
        email: 'user@empresa.com',
        matricula: 'U001',
        perfil: 'COLABORADOR',
        tokenVersion: 1,
        authTime: pastAuthTime
      }, { expiresIn: '15m' });

      mockReq.headers['authorization'] = `Bearer ${token}`;

      const originalQuery = pool.query;
      (pool.query as any) = jest.fn().mockResolvedValue({
        rowCount: 1,
        rows: [{ ativo: true, token_version: 1 }]
      });

      try {
        await authenticateToken(mockReq, mockRes, nextMock);
        expect(statusMock).toHaveBeenCalledWith(401);
        expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
          code: 'SESSION_ABSOLUTE_TIMEOUT'
        }));
        expect(nextMock).not.toHaveBeenCalled();
      } finally {
        pool.query = originalQuery;
      }
    });

    it('deve permitir requisição no authenticateToken se authTime estiver dentro da janela de 60 minutos', async () => {
      const validAuthTime = Math.floor(Date.now() / 1000) - 300; // 5 minutos atrás
      const token = JwtCryptoUtils.signToken({
        userId: 1,
        nome: 'Usuario Teste',
        email: 'user@empresa.com',
        matricula: 'U001',
        perfil: 'COLABORADOR',
        tokenVersion: 1,
        authTime: validAuthTime
      }, { expiresIn: '15m' });

      mockReq.headers['authorization'] = `Bearer ${token}`;

      const originalQuery = pool.query;
      (pool.query as any) = jest.fn().mockResolvedValue({
        rowCount: 1,
        rows: [{ ativo: true, token_version: 1 }]
      });

      try {
        await authenticateToken(mockReq, mockRes, nextMock);
        expect(nextMock).toHaveBeenCalled();
      } finally {
        pool.query = originalQuery;
      }
    });
  });

  describe('3. Single Active Session Enforcement', () => {
    it('deve invalidar refresh tokens anteriores ao incrementar token_version', async () => {
      const originalQuery = pool.query;
      const querySpy = jest.fn().mockResolvedValue({ rowCount: 1, rows: [{ token_version: 2 }] });
      (pool.query as any) = querySpy;

      try {
        const newVersion = await TokenService.incrementarTokenVersion(1);
        expect(newVersion).toBe(2);
        expect(querySpy).toHaveBeenCalledWith(
          expect.stringContaining('UPDATE usuarios'),
          [1]
        );
        expect(querySpy).toHaveBeenCalledWith(
          expect.stringContaining('UPDATE auth_refresh_tokens SET revogado = true'),
          [1]
        );
      } finally {
        pool.query = originalQuery;
      }
    });
  });

  describe('4. Privileged MFA Enforcement', () => {
    it('authenticateAdminMfa deve exigir MFA por padrão quando política for OBRIGATORIO_RH', async () => {
      jest.spyOn(ConfigService, 'get').mockResolvedValue('OBRIGATORIO_RH');

      mockReq.headers = {}; // sem x-admin-token
      mockReq.user = { userId: 1, perfil: 'ADMIN_RH', permissaoRh: true };

      await authenticateAdminMfa(mockReq, mockRes, nextMock);

      expect(statusMock).toHaveBeenCalledWith(403);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        requiresAdminMfa: true
      }));
      expect(nextMock).not.toHaveBeenCalled();
    });

    it('authenticateAdminMfa deve permitir acesso quando x-admin-token for válido', async () => {
      jest.spyOn(ConfigService, 'get').mockResolvedValue('OBRIGATORIO_RH');

      const adminToken = JwtCryptoUtils.signToken({
        userId: 1,
        nome: 'Admin RH',
        role: 'ADMIN_STEP_UP_AUTHENTICATED'
      }, { expiresIn: '15m' });

      mockReq.headers = { 'x-admin-token': adminToken };
      mockReq.user = { userId: 1, perfil: 'ADMIN_RH', permissaoRh: true };

      await authenticateAdminMfa(mockReq, mockRes, nextMock);

      expect(nextMock).toHaveBeenCalled();
      expect(mockReq.isAdminMfaValidated).toBe(true);
    });
  });

  describe('5. Agenda da Próxima Semana para Perfis Gestão / Admin (RH e TI)', () => {
    it('deve bloquear a agenda da próxima semana para perfil ADMIN_RH e ADMIN_TI antes da abertura da Gestão', async () => {
      jest.spyOn(ConfigService, 'getNumber').mockResolvedValue(5); // Sexta
      jest.spyOn(ConfigService, 'get').mockResolvedValue('08:00');

      // Quinta-feira às 10:00 (antes da abertura padrão de sexta-feira 08:00)
      const quintaFeira = DateTime.fromISO('2026-09-10T10:00:00', { zone: 'America/Sao_Paulo' });

      const statusRh = await isProximaSemanaLiberada('ADMIN_RH', quintaFeira);
      expect(statusRh.liberada).toBe(false);
      expect(statusRh.mensagemBloqueio).toContain('Gestão e Administração');

      const statusTi = await isProximaSemanaLiberada('ADMIN_TI', quintaFeira);
      expect(statusTi.liberada).toBe(false);

      const statusUserObj = await isProximaSemanaLiberada({
        perfil: 'COLABORADOR',
        permissaoRh: true
      }, quintaFeira);
      expect(statusUserObj.liberada).toBe(false);

      // Sexta-feira às 09:00 (após a abertura de Gestão/Admin às 08:00)
      const sextaManha = DateTime.fromISO('2026-09-11T09:00:00', { zone: 'America/Sao_Paulo' });
      const statusRhAberto = await isProximaSemanaLiberada('ADMIN_RH', sextaManha);
      expect(statusRhAberto.liberada).toBe(true);
    });

    it('deve respeitar horários de abertura para perfil COLABORADOR', async () => {
      jest.spyOn(ConfigService, 'getNumber').mockResolvedValue(5); // Sexta
      jest.spyOn(ConfigService, 'get').mockResolvedValue('12:00');

      // Quinta-feira
      const quintaFeira = DateTime.fromISO('2026-09-10T10:00:00', { zone: 'America/Sao_Paulo' });
      const statusColabQuinta = await isProximaSemanaLiberada('COLABORADOR', quintaFeira);
      expect(statusColabQuinta.liberada).toBe(false);
      expect(statusColabQuinta.mensagemBloqueio).toContain('Sexta-feira às 12:00');

      // Sexta-feira 14:00 (após abertura)
      const sextaTarde = DateTime.fromISO('2026-09-11T14:00:00', { zone: 'America/Sao_Paulo' });
      const statusColabSexta = await isProximaSemanaLiberada('COLABORADOR', sextaTarde);
      expect(statusColabSexta.liberada).toBe(true);
    });
  });
});

