import { Request, Response } from 'express';
import { EscritorioService } from '../../src/services/escritorioService';
import { FacilitiesService } from '../../src/services/facilitiesService';
import { EscritorioController } from '../../src/controllers/escritorioController';
import { FacilitiesController } from '../../src/controllers/admin/facilitiesController';
import { TiController } from '../../src/controllers/tiController';
import { RelatorioController } from '../../src/controllers/relatorioController';
import { toUserResponseDto } from '../../src/utils/userDtoMapper';
import pool from '../../src/config/db';
import { EmailService } from '../../src/services/emailService';

describe('Onda 3: Refatoração de Serviços, DTO Unificado & Resiliência Operacional', () => {
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
        nome: 'Admin Teste',
        email: 'admin@empresa.com',
        matricula: 'ADM001',
        perfil: 'ADMIN_TI',
        permissaoTi: true,
        permissaoRh: true,
        departamentoId: 1
      },
      params: {},
      query: {},
      body: {},
      headers: {},
      correlationId: 'cid-wave3-test'
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

  describe('1. EscritorioService & EscritorioController', () => {
    it('deve listar escritórios ativos através do EscritorioService', async () => {
      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => ({
        rowCount: 2,
        rows: [
          { id: 1, nome: 'Sede SP', cidade: 'São Paulo', ativo: true },
          { id: 2, nome: 'Filial RJ', cidade: 'Rio de Janeiro', ativo: true }
        ]
      } as any));

      await EscritorioController.listar(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(200);
      expect(jsonMock).toHaveBeenCalledWith([
        { id: 1, nome: 'Sede SP', cidade: 'São Paulo', ativo: true },
        { id: 2, nome: 'Filial RJ', cidade: 'Rio de Janeiro', ativo: true }
      ]);

      querySpy.mockRestore();
    });

    it('deve formatar mapa com resumo percentual de ocupação departmental', async () => {
      mockReq.params = { id: '1' };
      mockReq.query = { data: '2026-09-10' };

      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async (q: any) => {
        const text = String(q);
        if (text.includes('FROM escritorios')) {
          return { rowCount: 1, rows: [{ id: 1, nome: 'Sede SP', cidade: 'São Paulo' }] } as any;
        }
        if (text.includes('FROM baias')) {
          return { rowCount: 1, rows: [{ id: 10, nome: 'Baia TI' }] } as any;
        }
        if (text.includes('FROM cadeiras c')) {
          return {
            rowCount: 2,
            rows: [
              {
                cadeira_id: 101,
                baia_id: 10,
                identificador: 'MESA-01',
                status_operacional: 'DISPONIVEL',
                reserva_id: 50,
                reserva_status: 'ATIVA',
                usuario_id: 1,
                ocupante_nome: 'Admin Teste',
                ocupante_departamento_nome: 'Tecnologia da Informação'
              },
              {
                cadeira_id: 102,
                baia_id: 10,
                identificador: 'MESA-02',
                status_operacional: 'DISPONIVEL',
                reserva_id: null,
                reserva_status: null
              }
            ]
          } as any;
        }
        return { rowCount: 0, rows: [] } as any;
      });

      await EscritorioController.getMapa(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(200);
      const resData = jsonMock.mock.calls[0][0];
      expect(resData.escritorio.nome).toBe('Sede SP');
      expect(resData.baias[0].totalCadeiras).toBe(2);
      expect(resData.baias[0].totalOcupadas).toBe(1);
      expect(resData.baias[0].totalLivres).toBe(1);
      expect(resData.baias[0].resumoOcupacao).toContain('50% Tecnologia da Informação | 50% Livre');

      querySpy.mockRestore();
    });
  });

  describe('2. FacilitiesService & FacilitiesController', () => {
    it('deve colocar cadeira em manutenção e cancelar reservas ativas', async () => {
      mockReq.params = { id: '101' };
      mockReq.body = {
        motivo: 'Monitor queimado',
        previsaoRetorno: '2026-09-12T18:00:00Z'
      };

      const mockClient = {
        query: jest.fn().mockImplementation(async (q: any) => {
          const text = String(q);
          if (text.includes('SELECT c.id, c.identificador')) {
            return {
              rowCount: 1,
              rows: [{ id: 101, identificador: 'MESA-01', status_operacional: 'DISPONIVEL', baia_id: 10, escritorio_id: 1, escritorio_nome: 'Sede SP' }]
            };
          }
          if (text.includes('FROM reservas r')) {
            return {
              rowCount: 1,
              rows: [{ id: 50, usuario_id: 2, data_reserva: '2026-09-10', codigo_comprovante: 'COMP-50', usuario_nome: 'User 2', usuario_email: 'user2@empresa.com' }]
            };
          }
          return { rowCount: 1, rows: [] };
        }),
        release: jest.fn()
      };

      const connectSpy = jest.spyOn(pool, 'connect').mockImplementation(async () => mockClient as any);
      const emailSpy = jest.spyOn(EmailService, 'enviarAvisoCancelamentoManutencao').mockImplementation(async () => true);

      await FacilitiesController.colocarCadeiraEmManutencao(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(200);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        message: expect.stringContaining('colocada em manutenção'),
        reservasCanceladas: 1
      }));

      connectSpy.mockRestore();
      emailSpy.mockRestore();
    });

    it('deve liberar cadeira de manutenção', async () => {
      mockReq.params = { id: '101' };

      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => ({
        rowCount: 1,
        rows: [{ id: 101, identificador: 'MESA-01', escritorio_id: 1 }]
      } as any));

      await FacilitiesController.liberarCadeiraManutencao(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(200);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        statusOperacional: 'DISPONIVEL'
      }));

      querySpy.mockRestore();
    });
  });

  describe('3. DTO Unificado (toUserResponseDto)', () => {
    it('deve sanitizar e normalizar objeto de usuário sem vazar senha ou segredos', () => {
      const rawUserFromDb = {
        id: 42,
        nome: 'Carlos Silva',
        email: 'carlos@empresa.com',
        matricula: 'CAR042',
        senha_hash: '$2b$10$supersecretcryptohashnotforclient',
        totp_secret: 'AES256_SECRET_STRING_SHOULD_NOT_LEAK',
        totp_backup_codes: 'AES256_BACKUP_CODES_SHOULD_NOT_LEAK',
        perfil: 'GESTAO',
        permissao_rh: false,
        permissao_ti: false,
        departamento_id: 3,
        departamento_nome: 'Controladoria',
        ativo: true,
        totp_ativo: true,
        exigir_mfa: true,
        ultimo_login: '2026-09-07T12:00:00Z'
      };

      const dto = toUserResponseDto(rawUserFromDb);

      expect(dto.id).toBe(42);
      expect(dto.nome).toBe('Carlos Silva');
      expect(dto.email).toBe('carlos@empresa.com');
      expect(dto.matricula).toBe('CAR042');
      expect(dto.perfil).toBe('GESTAO');
      expect(dto.departamentoId).toBe(3);
      expect(dto.departamentoNome).toBe('Controladoria');
      expect(dto.permissaoRh).toBe(false);
      expect(dto.permissaoTi).toBe(false);
      expect(dto.is_admin).toBe(false);
      expect(dto.ativo).toBe(true);
      expect(dto.totpAtivo).toBe(true);
      expect(dto.exigirMfa).toBe(true);
      expect((dto as any).senha_hash).toBeUndefined();
      expect((dto as any).totp_secret).toBeUndefined();
      expect((dto as any).totp_backup_codes).toBeUndefined();
    });

    it('deve inferir flags administrativas para perfil ADMIN_TI e ADMIN_RH', () => {
      const tiUser = {
        userId: 9,
        nome: 'Admin TI',
        email: 'ti@empresa.com',
        matricula: 'TI001',
        perfil: 'ADMIN_TI',
        permissaoTi: true
      };

      const dtoTi = toUserResponseDto(tiUser);
      expect(dtoTi.permissaoTi).toBe(true);
      expect(dtoTi.permissaoRh).toBe(false);

      const rhUser = {
        userId: 10,
        nome: 'Admin RH',
        email: 'rh@empresa.com',
        matricula: 'RH001',
        perfil: 'ADMIN_RH',
        is_admin: true
      };

      const dtoRh = toUserResponseDto(rhUser);
      expect(dtoRh.permissaoRh).toBe(true);
      expect(dtoRh.is_admin).toBe(true);
    });
  });

  describe('4. Sanitização de Erros & Resiliência (tiController / relatorioController)', () => {
    it('deve mascarar erro interno e não vazar stack trace no teste de SMTP', async () => {
      mockReq.body = { emailDestino: 'teste@empresa.com' };

      const emailSpy = jest.spyOn(EmailService, 'enviarEmailGenerico').mockImplementation(async () => {
        throw new Error('EAUTH: Invalid login: 535-5.7.8 Username and Password not accepted at line 149 /internal/secret/path');
      });

      await TiController.testarConexaoEmail(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(500);
      expect(jsonMock).toHaveBeenCalledWith({
        success: false,
        error: 'Erro ao testar conexão SMTP. Verifique as credenciais e tente novamente.'
      });

      emailSpy.mockRestore();
    });

    it('deve destruir socket TCP quando ocorrer erro após envio de headers no PDF', async () => {
      mockReq.query = {
        dataInicio: '2026-09-01',
        dataFim: '2026-09-30'
      };

      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => {
        throw new Error('Simulated DB/Stream Failure');
      });

      mockRes.headersSent = true;

      await RelatorioController.exportarPdf(mockReq, mockRes);

      expect(mockRes.destroy).toHaveBeenCalled();

      querySpy.mockRestore();
    });
  });

  afterAll(async () => {
    await pool.end();
  });
});

