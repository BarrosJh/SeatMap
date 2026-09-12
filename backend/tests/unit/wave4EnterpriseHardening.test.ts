import { Request, Response } from 'express';
import { UsuarioService } from '../../src/services/usuarioService';
import { ReservaService } from '../../src/services/reservaService';
import { FacilitiesService } from '../../src/services/facilitiesService';
import { AuditService } from '../../src/services/auditService';
import { CronService } from '../../src/services/cronService';
import { AdminUsuariosController } from '../../src/controllers/admin/adminUsuariosController';
import { AdminParametrosController } from '../../src/controllers/admin/adminParametrosController';
import { ParametrosService } from '../../src/services/admin/parametrosService';
import { escapeSqlWildcards } from '../../src/utils/sanitizer';
import { parseIdParam, normalizeIsoDate } from '../../src/utils/workWeekUtils';
import { validateBody } from '../../src/middleware/validate';
import { loginSchema, colocarManutencaoSchema } from '../../src/validation/schemas';
import { requirePermission, getUserPermissions } from '../../src/middleware/auth';
import pool from '../../src/config/db';
import { DateTime } from 'luxon';

describe('Onda 4: Remediação dos 14 Apontamentos Enterprise (SEC, REL, TEC)', () => {
  let mockReq: any;
  let mockRes: any;
  let statusMock: jest.Mock;
  let jsonMock: jest.Mock;

  beforeEach(() => {
    jest.clearAllMocks();
    statusMock = jest.fn().mockReturnThis();
    jsonMock = jest.fn();

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
      correlationId: 'cid-wave4-test'
    };

    mockRes = {
      status: statusMock,
      json: jsonMock,
      setHeader: jest.fn(),
      send: jest.fn(),
      end: jest.fn(),
      destroy: jest.fn(),
      headersSent: false
    };
  });

  describe('1. SEC-01: Prevenção de Escalação de Privilégios (RBAC Bypass)', () => {
    it('deve barrar criação de ADMIN_TI ou permissaoTi por operador sem privilégio de TI', async () => {
      mockReq.user = {
        userId: 2,
        nome: 'Operador RH Comum',
        perfil: 'ADMIN_RH',
        permissaoRh: true,
        permissaoTi: false
      };

      mockReq.body = {
        nome: 'Novo Hacker',
        email: 'hacker@empresa.com',
        matricula: 'HCK01',
        senha: 'SenhaForte@2026',
        perfil: 'ADMIN_TI',
        permissaoTi: true
      };

      await AdminUsuariosController.criarUsuario(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(403);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.stringContaining('Não é permitido conceder privilégios de Administrador de TI')
      }));
    });

    it('deve barrar promoção para ADMIN_TI na edição de usuário por operador sem privilégio de TI', async () => {
      mockReq.user = {
        userId: 2,
        nome: 'Operador RH Comum',
        perfil: 'ADMIN_RH',
        permissaoRh: true,
        permissaoTi: false
      };

      mockReq.params = { id: '50' };
      mockReq.body = {
        perfil: 'ADMIN_TI',
        permissaoTi: true
      };

      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async (q: any) => {
        const text = String(q);
        if (text.includes('SELECT id, perfil')) {
          return { rowCount: 1, rows: [{ id: 50, perfil: 'COLABORADOR', permissao_ti: false }] } as any;
        }
        return { rowCount: 1, rows: [] } as any;
      });

      await AdminUsuariosController.updateUsuario(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(403);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.stringContaining('Não é permitido conceder privilégios de Administrador de TI')
      }));

      querySpy.mockRestore();
    });
  });

  describe('2. SEC-04: Conversão e Validação Segura de Datas em Manutenção', () => {
    it('deve retornar HTTP 400 caso previsaoRetorno contenha formato corrompido', async () => {
      const mockClient = {
        query: jest.fn().mockImplementation(async (q: any) => {
          const text = String(q);
          if (text.includes('SELECT c.id, c.identificador')) {
            return {
              rowCount: 1,
              rows: [{ id: 10, identificador: 'MESA-10', status_operacional: 'DISPONIVEL', baia_id: 1, escritorio_id: 1 }]
            };
          }
          return { rowCount: 1, rows: [] };
        }),
        release: jest.fn()
      };

      const connectSpy = jest.spyOn(pool, 'connect').mockImplementation(async () => mockClient as any);

      const result = await FacilitiesService.colocarCadeiraEmManutencao(
        10,
        'Tomada em curto',
        'data-totalmente-invalida',
        1
      );

      expect(result.success).toBe(false);
      expect(result.code).toBe(400);
      expect(result.error).toContain('Formato de previsão de retorno inválido');

      connectSpy.mockRestore();
    });
  });

  describe('3. SEC-05: Escape de Wildcards em Buscas SQL (ILIKE)', () => {
    it('deve escapar corretamente os caracteres % e _', () => {
      const raw = 'teste%_100%_busca\\';
      const escaped = escapeSqlWildcards(raw);
      expect(escaped).toBe('teste\\%\\_100\\%\\_busca\\\\');
    });

    it('deve retornar string vazia para entradas nulas ou indefinidas', () => {
      expect(escapeSqlWildcards(null as any)).toBe('');
      expect(escapeSqlWildcards(undefined as any)).toBe('');
    });
  });

  describe('4. SEC-06: Validação Estrita de Porta TCP (SMTP_PORT)', () => {
    it('deve rejeitar portas fora do intervalo 1 a 65535 ou alfanuméricas', async () => {
      mockReq.body = {
        configuracoes: {
          SMTP_PORT: '99999' // Fora do intervalo
        }
      };

      await AdminParametrosController.updateParametros(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(400);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.stringContaining('SMTP_PORT deve ser um número de porta TCP válido entre 1 e 65535')
      }));
    });

    it('deve aceitar porta TCP legítima (587)', async () => {
      mockReq.body = {
        configuracoes: {
          SMTP_PORT: '587'
        }
      };

      const setSpy = jest.spyOn(pool, 'query').mockImplementation(async () => ({ rowCount: 1, rows: [] } as any));

      await AdminParametrosController.updateParametros(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(200);

      setSpy.mockRestore();
    });
  });

  describe('5. REL-01: Buffer e Batch Flush em AuditService', () => {
    it('deve agrupar logs em buffer e persistir no flush em lote', async () => {
      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => ({ rowCount: 2, rows: [] } as any));

      AuditService.log({
        usuarioId: 1,
        loginInformado: 'user1',
        tipoEvento: 'LOGIN_SUCESSO',
        sucesso: true
      });

      AuditService.log({
        usuarioId: 2,
        loginInformado: 'user2',
        tipoEvento: 'LOGOUT',
        sucesso: true
      });

      await AuditService.flush();

      expect(querySpy).toHaveBeenCalledTimes(1);
      const queryText = querySpy.mock.calls[0][0] as string;
      expect(queryText).toContain('INSERT INTO auditoria_acessos');

      querySpy.mockRestore();
    });
  });

  describe('6. REL-04: Graceful Shutdown com CronService.waitForCompletion', () => {
    it('deve aguardar conclusão de execução ativa do cron sem lançar exceções', async () => {
      await expect(CronService.waitForCompletion(100)).resolves.not.toThrow();
    });
  });

  describe('7. TEC-02 & TEC-03: parseIdParam e normalizeIsoDate', () => {
    it('parseIdParam deve converter strings numéricas válidas e rejeitar inválidas', () => {
      expect(parseIdParam('123')).toBe(123);
      expect(parseIdParam(456)).toBe(456);
      expect(parseIdParam('abc')).toBeNull();
      expect(parseIdParam('-5')).toBeNull();
      expect(parseIdParam(null)).toBeNull();
      expect(parseIdParam(undefined)).toBeNull();
    });

    it('normalizeIsoDate deve formatar datas corretamente', () => {
      const jsDate = new Date('2026-09-15T10:30:00Z');
      const isoStr = '2026-09-15T00:00:00.000Z';
      const simpleDate = '2026-09-15';

      expect(normalizeIsoDate(simpleDate)).toBe('2026-09-15');
      expect(normalizeIsoDate(isoStr)).toBe('2026-09-15');
      expect(normalizeIsoDate(jsDate)).toBeDefined();
    });
  });

  describe('8. SEC-03: Validação Declarativa Zod (validateBody)', () => {
    it('deve barrar requisição com payload que viole o schema', () => {
      const middleware = validateBody(loginSchema);
      const req: any = { body: { login: '' } }; // Sem senha e login vazio
      const res: any = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      };
      const next = jest.fn();

      middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(next).not.toHaveBeenCalled();
    });

    it('deve permitir requisição com payload válido', () => {
      const middleware = validateBody(loginSchema);
      const req: any = { body: { login: 'usuario@empresa.com', senha: 'SenhaValida@123' } };
      const res: any = { status: jest.fn().mockReturnThis(), json: jest.fn() };
      const next = jest.fn();

      middleware(req, res, next);

      expect(next).toHaveBeenCalled();
    });
  });

  describe('9. Bloco 1: autorização por permissão explícita', () => {
    it('deve conceder permissões de administração RH ao perfil ADMIN_RH', () => {
      const permissions = getUserPermissions({
        userId: 1,
        nome: 'RH',
        email: 'rh@empresa.com',
        matricula: 'RH001',
        perfil: 'ADMIN_RH',
        departamentoId: 1
      } as any);

      expect(permissions).toEqual(expect.arrayContaining(['config:read', 'config:write']));
    });

    it('deve bloquear acesso de colaborador a permissão de configuração', () => {
      const req: any = {
        user: {
          userId: 2,
          nome: 'Colaborador',
          email: 'c@empresa.com',
          matricula: 'C001',
          perfil: 'COLABORADOR',
          departamentoId: 1,
          permissaoRh: false,
          permissaoTi: false
        }
      };
      const res: any = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      };
      const next = jest.fn();

      const middleware = requirePermission('config:write');
      middleware(req, res, next);

      expect(res.status).toHaveBeenCalledWith(403);
      expect(next).not.toHaveBeenCalled();
    });
  });

  describe('10. Bloco 3: auditoria de ações críticas', () => {
    it('deve registrar a criação de usuário em auditoria', async () => {
      const logSpy = jest.spyOn(AuditService, 'log').mockImplementation(() => undefined);
      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async (q: any) => {
        const text = String(q);
        if (text.includes('SELECT id FROM usuarios WHERE') || text.includes('LOWER(email) = LOWER($1)')) {
          return { rowCount: 0, rows: [] } as any;
        }

        if (text.includes('INSERT INTO usuarios')) {
          return {
            rowCount: 1,
            rows: [{ id: 42, nome: 'Novo Usuário', email: 'novo@empresa.com', matricula: 'NVO01', departamento_id: null, perfil: 'COLABORADOR', permissao_rh: false, permissao_ti: false, exigir_mfa: false, ativo: true }]
          } as any;
        }

        return { rowCount: 1, rows: [] } as any;
      });

      const result = await UsuarioService.criarUsuario({
        nome: 'Novo Usuário',
        email: 'novo@empresa.com',
        matricula: 'NVO01',
        senha: 'SenhaForte@2026',
        perfil: 'COLABORADOR'
      }, true);

      expect(result.success).toBe(true);
      expect(logSpy).toHaveBeenCalledWith(expect.objectContaining({
        tipoEvento: 'USUARIO_CRIADO',
        sucesso: true
      }));

      logSpy.mockRestore();
      querySpy.mockRestore();
    });

    it('deve registrar alteração de configuração crítica em auditoria', async () => {
      const logSpy = jest.spyOn(AuditService, 'log').mockImplementation(() => undefined);
      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => ({ rowCount: 1, rows: [] } as any));

      const result = await ParametrosService.updateParametros({ SMTP_PORT: '587' });

      expect(result.success).toBe(true);
      expect(logSpy).toHaveBeenCalledWith(expect.objectContaining({
        tipoEvento: 'CONFIGURACAO_ALTERADA',
        sucesso: true,
        detalhes: expect.objectContaining({ chave: 'SMTP_PORT' })
      }));

      logSpy.mockRestore();
      querySpy.mockRestore();
    });
  });

  afterAll(async () => {
    await AuditService.shutdown();
    await pool.end();
  });
});

