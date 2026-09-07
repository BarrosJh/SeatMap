import { Request, Response } from 'express';
import { ReservaController } from '../../src/controllers/reservaController';
import { AdminUsuariosController } from '../../src/controllers/admin/adminUsuariosController';
import { MfaController } from '../../src/controllers/auth/mfaController';
import { AdminParametrosController } from '../../src/controllers/admin/adminParametrosController';
import { RelatorioController } from '../../src/controllers/relatorioController';
import pool from '../../src/config/db';
import { ConfigService } from '../../src/services/configService';
import { DateTime } from 'luxon';

describe('Onda 2: Correções de Negócio, RBAC, BOLA & Validações de Entrada', () => {
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
        userId: 10,
        nome: 'Usuario Teste',
        email: 'user@empresa.com',
        matricula: 'USR001',
        perfil: 'COLABORADOR',
        departamentoId: 1
      },
      body: {},
      query: {},
      headers: {},
      correlationId: 'cid-test-wave2'
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

  describe('1. BOLA no Check-in por Gestão (reservaController)', () => {
    it('deve barrar check-in de gestor para reserva de outro departamento (BOLA)', async () => {
      mockReq.user = {
        userId: 20,
        nome: 'Gestor Financeiro',
        perfil: 'GESTAO',
        departamentoId: 1, // Departamento Financeiro
        permissaoRh: false,
        permissaoTi: false
      };
      mockReq.params = { id: '100' };

      const hojeIso = DateTime.now().setZone('America/Sao_Paulo').toISODate()!;

      // Reserva de colaborador do Departamento de TI (departamento_id: 2)
      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => ({
        rowCount: 1,
        rows: [{
          id: 100,
          usuario_id: 99,
          data_reserva: hojeIso,
          status: 'ATIVA',
          checkin_realizado: false,
          departamento_id: 2 // Outro departamento
        }]
      } as any));

      await ReservaController.fazerCheckin(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(403);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.stringContaining('Gestores só possuem permissão para realizar check-in de colaboradores do seu próprio departamento')
      }));

      querySpy.mockRestore();
    });

    it('deve autorizar check-in de gestor para reserva do mesmo departamento', async () => {
      mockReq.user = {
        userId: 20,
        nome: 'Gestor Financeiro',
        perfil: 'GESTAO',
        departamentoId: 1, // Departamento Financeiro
        permissaoRh: false
      };
      mockReq.params = { id: '101' };

      const hojeIso = DateTime.now().setZone('America/Sao_Paulo').toISODate()!;

      const configSpy = jest.spyOn(ConfigService, 'get').mockImplementation(async (key: string, def?: any) => {
        if (key === 'HORARIO_INICIO_CHECKIN') return '00:00';
        if (key === 'HORARIO_LIMITE_CHECKIN') return '23:59';
        return def;
      });

      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async (query: any) => {
        const text = String(query);
        if (text.includes('FROM reservas')) {
          return {
            rowCount: 1,
            rows: [{
              id: 101,
              usuario_id: 30,
              data_reserva: hojeIso,
              status: 'ATIVA',
              checkin_realizado: false,
              departamento_id: 1, // Mesmo departamento!
              codigo_comprovante: 'COMP-101'
            }]
          } as any;
        }
        if (text.includes('UPDATE reservas')) {
          return { rowCount: 1 } as any;
        }
        return { rowCount: 0, rows: [] } as any;
      });

      await ReservaController.fazerCheckin(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(200);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        message: expect.stringContaining('confirmada')
      }));

      querySpy.mockRestore();
      configSpy.mockRestore();
    });
  });

  describe('2. Prevenção de Escalação de Privilégios na Importação (adminUsuariosController)', () => {
    it('deve barrar atribuição de permissao_ti quando o operador não possui privilégios de TI', async () => {
      mockReq.user = {
        userId: 5,
        nome: 'Operador RH',
        perfil: 'ADMIN_RH',
        permissaoRh: true,
        permissaoTi: false // Sem permissão de TI!
      };

      mockReq.body = {
        usuarios: [
          {
            nome: 'Tentativa Hacking TI',
            email: 'hacker@empresa.com',
            matricula: 'HCK01',
            perfil: 'ADMIN_TI',
            permissao_ti: true,
            departamento: 'TI'
          }
        ]
      };

      const mockClient = {
        query: jest.fn().mockImplementation(async (q: any) => {
          const text = String(q);
          if (text.includes('SELECT id, nome FROM departamentos')) {
            return { rows: [{ id: 1, nome: 'TI' }], rowCount: 1 };
          }
          return { rows: [{ id: 1 }], rowCount: 1 };
        }),
        release: jest.fn()
      };
      const connectSpy = jest.spyOn(pool, 'connect').mockImplementation(async () => mockClient as any);

      await AdminUsuariosController.importarLoteUsuarios(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(200);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        erros: expect.arrayContaining([
          expect.objectContaining({
            erro: expect.stringContaining('Não é permitido conceder privilégios de Administrador de TI sem possuir a permissão correspondente')
          })
        ])
      }));

      connectSpy.mockRestore();
    });
  });

  describe('3. Step-Up MFA para Administradores de TI (mfaController)', () => {
    it('deve autorizar solicitação de MFA para perfil ADMIN_TI e permissaoTi', async () => {
      mockReq.user = {
        userId: 8,
        nome: 'Admin Infraestrutura',
        email: 'infra@empresa.com',
        perfil: 'ADMIN_TI',
        permissaoTi: true,
        permissaoRh: false
      };

      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => ({ rowCount: 1, rows: [] } as any));

      await MfaController.solicitarMfa(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(200);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        message: expect.stringContaining('Código de autenticação MFA gerado')
      }));

      querySpy.mockRestore();
    });

    it('deve barrar solicitação de Step-Up MFA para colaborador comum', async () => {
      mockReq.user = {
        userId: 50,
        nome: 'Colaborador Comum',
        perfil: 'COLABORADOR',
        permissaoRh: false,
        permissaoTi: false
      };

      await MfaController.solicitarMfa(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(403);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.stringContaining('Apenas administradores com permissão de RH ou TI podem solicitar código MFA')
      }));
    });
  });

  describe('4. Whitelist e Schema de Parâmetros (adminParametrosController)', () => {
    it('deve rejeitar chaves de configuração fora da whitelist', async () => {
      mockReq.body = {
        configuracoes: {
          PARAMETRO_ARBITRARIO_INJETADO: 'hack'
        }
      };

      await AdminParametrosController.updateParametros(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(400);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.stringContaining('não é permitida ou não existe na whitelist')
      }));
    });

    it('deve rejeitar valor de horário inválido para HORARIO_CORTE_NOSHOW', async () => {
      mockReq.body = {
        configuracoes: {
          HORARIO_CORTE_NOSHOW: '25:99' // Horário inválido!
        }
      };

      await AdminParametrosController.updateParametros(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(400);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.stringContaining('deve estar no formato de horário HH:mm')
      }));
    });

    it('deve aceitar parâmetros legítimos em conformidade com o schema', async () => {
      mockReq.body = {
        configuracoes: {
          LIMITE_SEMANAL_RESERVAS: '3',
          HORARIO_CORTE_NOSHOW: '11:30',
          AUTO_LOCK_ATIVO: 'true'
        }
      };

      const setSpy = jest.spyOn(ConfigService, 'set').mockImplementation(async () => undefined as any);
      const getAllSpy = jest.spyOn(ConfigService, 'getAll').mockImplementation(async () => ({
        LIMITE_SEMANAL_RESERVAS: '3',
        HORARIO_CORTE_NOSHOW: '11:30'
      } as any));

      await AdminParametrosController.updateParametros(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(200);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        message: 'Configurações atualizadas com sucesso.'
      }));

      setSpy.mockRestore();
      getAllSpy.mockRestore();
    });
  });

  describe('5. Validação de Formato de Datas em Relatórios (relatorioController)', () => {
    it('deve rejeitar requisição com dataInicio malformada', async () => {
      mockReq.query = {
        dataInicio: 'data-invalida',
        dataFim: '2026-09-10'
      };

      await RelatorioController.getAnalytics(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(400);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.stringContaining('Parâmetro dataInicio inválido')
      }));
    });

    it('deve processar relatório quando as datas ISO forem válidas', async () => {
      mockReq.query = {
        dataInicio: '2026-09-01',
        dataFim: '2026-09-30'
      };

      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => ({
        rowCount: 1,
        rows: [{
          total_reservas: 10,
          total_checkins: 8,
          total_canceladas: 1,
          total_noshows: 1,
          total_pendentes: 0
        }]
      } as any));

      await RelatorioController.getAnalytics(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(200);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        kpis: expect.objectContaining({
          totalReservas: 10,
          taxaPresenca: 80
        })
      }));

      querySpy.mockRestore();
    });
  });

  afterAll(async () => {
    await pool.end();
  });
});
