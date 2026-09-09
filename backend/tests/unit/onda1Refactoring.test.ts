import { Request, Response, NextFunction } from 'express';
import { ParametrosService } from '../../src/services/admin/parametrosService';
import { RelatorioService } from '../../src/services/relatorioService';
import { ExportService } from '../../src/services/exportService';
import { validateRequest } from '../../src/middleware/validateRequest';
import { relatorioFiltrosSchema } from '../../src/schemas/relatorioSchemas';
import { updateParametrosSchema, validateSingleParam } from '../../src/schemas/parametrosSchemas';
import { ConfigService } from '../../src/services/configService';
import { AdminParametrosController } from '../../src/controllers/admin/adminParametrosController';
import { RelatorioController } from '../../src/controllers/relatorioController';
import pool from '../../src/config/db';

jest.mock('../../src/services/configService');
jest.mock('../../src/websocket/wsServer', () => ({
  wsManager: {
    broadcastToAll: jest.fn()
  }
}));
jest.mock('../../src/config/db', () => ({
  __esModule: true,
  default: {
    query: jest.fn()
  }
}));

describe('Onda 1: Desacoplamento de Controllers e Validação Declarativa com Zod', () => {
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
      correlationId: 'cid-onda1-test'
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

  describe('1. Validação Declarativa de Parâmetros e Whitelist (parametrosSchemas)', () => {
    it('deve validar parâmetros válidos na whitelist', () => {
      expect(validateSingleParam('LIMITE_SEMANAL_RESERVAS', '3').valid).toBe(true);
      expect(validateSingleParam('HORARIO_INICIO_CHECKIN', '08:00').valid).toBe(true);
      expect(validateSingleParam('AUTO_LOCK_ATIVO', 'true').valid).toBe(true);
      expect(validateSingleParam('SMTP_PORT', '587').valid).toBe(true);
    });

    it('deve rejeitar chaves fora da whitelist', () => {
      const res = validateSingleParam('CHAVE_INEXISTENTE', '123');
      expect(res.valid).toBe(false);
      expect(res.error).toContain('não é permitida ou não existe na whitelist');
    });

    it('deve rejeitar formatos inválidos de horário', () => {
      const res = validateSingleParam('HORARIO_INICIO_CHECKIN', '25:00');
      expect(res.valid).toBe(false);
      expect(res.error).toContain('deve estar no formato de horário HH:mm');
    });

    it('deve validar schema Zod de parâmetros', () => {
      const validPayload = {
        configuracoes: [
          { chave: 'LIMITE_SEMANAL_RESERVAS', valor: '5' },
          { chave: 'AUTO_LOCK_ATIVO', valor: 'false' }
        ]
      };
      const parseResult = updateParametrosSchema.safeParse(validPayload);
      expect(parseResult.success).toBe(true);

      const invalidPayload = {
        configuracoes: [
          { chave: 'CHAVE_INVALIDA', valor: '123' }
        ]
      };
      const invalidResult = updateParametrosSchema.safeParse(invalidPayload);
      expect(invalidResult.success).toBe(false);
    });
  });

  describe('2. ParametrosService (Camada de Negócio Desacoplada)', () => {
    it('deve buscar todos os parâmetros via ConfigService', async () => {
      (ConfigService.getAll as jest.Mock).mockResolvedValue([
        { chave: 'LIMITE_SEMANAL_RESERVAS', valor: '3' }
      ]);

      const res = await ParametrosService.getParametros();
      expect(ConfigService.getAll).toHaveBeenCalled();
      expect(res).toEqual([{ chave: 'LIMITE_SEMANAL_RESERVAS', valor: '3' }]);
    });

    it('deve atualizar parâmetros no formato array com sucesso', async () => {
      (ConfigService.set as jest.Mock).mockResolvedValue(undefined);
      (ConfigService.getAll as jest.Mock).mockResolvedValue([{ chave: 'LIMITE_SEMANAL_RESERVAS', valor: '4' }]);
      (ConfigService.get as jest.Mock).mockResolvedValue('Aviso de teste');

      const result = await ParametrosService.updateParametros([
        { chave: 'LIMITE_SEMANAL_RESERVAS', valor: '4' }
      ]);

      expect(result.success).toBe(true);
      expect(result.code).toBe(200);
      expect(ConfigService.set).toHaveBeenCalledWith('LIMITE_SEMANAL_RESERVAS', '4', undefined);
    });

    it('deve atualizar parâmetros no formato objeto/dicionário com sucesso', async () => {
      (ConfigService.set as jest.Mock).mockResolvedValue(undefined);
      (ConfigService.getAll as jest.Mock).mockResolvedValue([{ chave: 'AUTO_LOCK_ATIVO', valor: 'true' }]);
      (ConfigService.get as jest.Mock).mockResolvedValue('');

      const result = await ParametrosService.updateParametros({
        AUTO_LOCK_ATIVO: 'true'
      });

      expect(result.success).toBe(true);
      expect(ConfigService.set).toHaveBeenCalledWith('AUTO_LOCK_ATIVO', 'true', undefined);
    });

    it('deve rejeitar chave inválida ao tentar atualizar parâmetros', async () => {
      const result = await ParametrosService.updateParametros([
        { chave: 'MALICIOUS_KEY', valor: 'hack' }
      ]);

      expect(result.success).toBe(false);
      expect(result.code).toBe(400);
      expect(result.error).toContain('não é permitida ou não existe na whitelist');
    });

    it('deve rejeitar início de reserva tardia posterior ao limite de check-in', async () => {
      const result = await ParametrosService.updateParametros([
        { chave: 'HORARIO_INICIO_CHECKIN', valor: '06:00' },
        { chave: 'HORARIO_LIMITE_CHECKIN', valor: '11:00' },
        { chave: 'HORARIO_INICIO_RESERVA_TARDIA', valor: '12:00' }
      ]);

      expect(result.success).toBe(false);
      expect(result.code).toBe(400);
      expect(result.error).toContain('HORARIO_INICIO_RESERVA_TARDIA não pode ser posterior');
      expect(ConfigService.set).not.toHaveBeenCalled();
    });
  });

  describe('3. RelatorioService & RelatorioSchemas', () => {
    it('deve validar datas corretas no schema Zod de relatórios', () => {
      const validQuery = {
        dataInicio: '2026-09-01',
        dataFim: '2026-09-07'
      };
      const result = relatorioFiltrosSchema.safeParse(validQuery);
      expect(result.success).toBe(true);
    });

    it('deve rejeitar dataInicio inválida no schema Zod', () => {
      const invalidQuery = {
        dataInicio: '01/09/2026',
        dataFim: '2026-09-07'
      };
      const result = relatorioFiltrosSchema.safeParse(invalidQuery);
      expect(result.success).toBe(false);
    });

    it('deve construir cláusula WHERE e parâmetros com filtros dinâmicos', () => {
      const query = {
        dataInicio: '2026-09-01',
        dataFim: '2026-09-07',
        escritorioId: '2',
        departamentoId: '3',
        status: 'ATIVA',
        checkinStatus: 'confirmado',
        busca: 'Maria'
      };

      const { whereClause, params, dataInicio, dataFim } = RelatorioService.buildWhereClause(query);
      expect(dataInicio).toBe('2026-09-01');
      expect(dataFim).toBe('2026-09-07');
      expect(whereClause).toContain('r.data_reserva >= $1 AND r.data_reserva <= $2');
      expect(whereClause).toContain('e.id = $3');
      expect(whereClause).toContain('u.departamento_id = $4');
      expect(whereClause).toContain('r.status = $5');
      expect(whereClause).toContain('r.checkin_realizado = true');
      expect(whereClause).toContain('u.nome ILIKE $6');
      expect(params).toEqual(['2026-09-01', '2026-09-07', 2, 3, 'ATIVA', '%Maria%']);
    });

    it('deve obter KPIs e analytics agregados via getAnalytics', async () => {
      (pool.query as jest.Mock)
        .mockResolvedValueOnce({
          rows: [{
            total_reservas: 10,
            total_checkins: 8,
            total_canceladas: 1,
            total_noshows: 1,
            total_pendentes: 0
          }]
        })
        .mockResolvedValueOnce({
          rows: [{ id: 1, escritorio: 'São Paulo', cidade: 'SP', total_reservas: 10, total_checkins: 8, total_noshows: 1, total_mesas_utilizadas: 5 }]
        })
        .mockResolvedValueOnce({
          rows: [{ departamento: 'Engenharia', total_reservas: 10, total_checkins: 8, total_noshows: 1 }]
        })
        .mockResolvedValueOnce({
          rows: [{ data_reserva: new Date('2026-09-01'), total_reservas: 10, total_checkins: 8, total_noshows: 1 }]
        });

      const analytics = await RelatorioService.getAnalytics({
        dataInicio: '2026-09-01',
        dataFim: '2026-09-07'
      });

      expect(analytics.kpis.totalReservas).toBe(10);
      expect(analytics.kpis.totalCheckins).toBe(8);
      expect(analytics.kpis.taxaPresenca).toBe(80);
      expect(analytics.porEscritorio).toHaveLength(1);
      expect(analytics.porDepartamento).toHaveLength(1);
    });
  });

  describe('4. Middleware validateRequest', () => {
    it('deve chamar next() quando o payload for válido', async () => {
      const middleware = validateRequest({
        body: updateParametrosSchema
      });

      mockReq.body = {
        configuracoes: [{ chave: 'LIMITE_SEMANAL_RESERVAS', valor: '5' }]
      };

      await middleware(mockReq, mockRes, mockNext);
      expect(mockNext).toHaveBeenCalled();
      expect(statusMock).not.toHaveBeenCalled();
    });

    it('deve responder 400 com mensagem clara quando o payload for inválido', async () => {
      const middleware = validateRequest({
        body: updateParametrosSchema
      });

      mockReq.body = {
        configuracoes: [{ chave: 'CHAVE_TOTALMENTE_INVALIDA', valor: '123' }]
      };

      await middleware(mockReq, mockRes, mockNext);
      expect(mockNext).not.toHaveBeenCalled();
      expect(statusMock).toHaveBeenCalledWith(400);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.stringContaining('não é permitida ou não existe na whitelist')
      }));
    });
  });

  describe('5. Thin Controllers Orchestration', () => {
    it('AdminParametrosController.getParametros deve delegar para ParametrosService', async () => {
      (ConfigService.getAll as jest.Mock).mockResolvedValue([{ chave: 'LIMITE_SEMANAL_RESERVAS', valor: '3' }]);

      await AdminParametrosController.getParametros(mockReq, mockRes);
      expect(statusMock).toHaveBeenCalledWith(200);
      expect(jsonMock).toHaveBeenCalledWith([{ chave: 'LIMITE_SEMANAL_RESERVAS', valor: '3' }]);
    });

    it('RelatorioController.getAnalytics deve delegar para RelatorioService', async () => {
      (pool.query as jest.Mock)
        .mockResolvedValueOnce({
          rows: [{ total_reservas: 5, total_checkins: 5, total_canceladas: 0, total_noshows: 0, total_pendentes: 0 }]
        })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [] });

      mockReq.query = { dataInicio: '2026-09-01', dataFim: '2026-09-07' };
      await RelatorioController.getAnalytics(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(200);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        kpis: expect.objectContaining({ totalReservas: 5, totalCheckins: 5 })
      }));
    });
  });
});
