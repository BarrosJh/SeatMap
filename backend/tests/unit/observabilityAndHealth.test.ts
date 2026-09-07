import { Request, Response } from 'express';
import { Logger } from '../../src/utils/logger/index';
import { JsonFormatter, DevFormatter } from '../../src/utils/logger/formatters';
import { MemoryTransport } from '../../src/utils/logger/transports';
import { redactSensitiveData } from '../../src/utils/logger/redactor';
import { correlationIdMiddleware } from '../../src/middleware/correlationId';
import { HealthController } from '../../src/controllers/healthController';
import pool from '../../src/config/db';

describe('Prioridade 2: Observabilidade & Governança de Infraestrutura', () => {
  describe('Módulo Logger & Sanitização (LGPD / PCI-DSS)', () => {
    it('deve mascarar campos sensíveis como senhas, tokens e segredos recursivamente', () => {
      const sensitiveObj = {
        usuario: 'admin_bank',
        password: 'super_secret_password',
        auth: {
          token: 'jwt.token.here',
          client_secret: 'secret-12345'
        },
        dados: {
          cpf: '123.456.789-00',
          credit_card: '4111 2222 3333 4444',
          publicInfo: 'ok'
        },
        headerStr: 'Bearer eyJhbGciOi...'
      };

      const redacted = redactSensitiveData(sensitiveObj);

      expect(redacted.password).toBe('[REDACTED]');
      expect(redacted.auth.token).toBe('[REDACTED]');
      expect(redacted.auth.client_secret).toBe('[REDACTED]');
      expect(redacted.dados.cpf).toBe('[REDACTED]');
      expect(redacted.dados.credit_card).toBe('[REDACTED]');
      expect(redacted.dados.publicInfo).toBe('ok');
      expect(redacted.headerStr).toBe('Bearer [REDACTED]');
    });

    it('deve formatar logs em JSON válido para ingestão em SIEM', () => {
      const memoryTransport = new MemoryTransport();
      const logger = new Logger({
        level: 'debug',
        service: 'test-bank-service',
        environment: 'production',
        formatter: new JsonFormatter(),
        transports: [memoryTransport]
      });

      logger.info('Transação financeira auditada', {
        userId: 42,
        correlationId: 'trace-abc-123',
        password: 'must-be-hidden'
      });

      expect(memoryTransport.entries.length).toBe(1);
      const parsed = JSON.parse(memoryTransport.entries[0].formattedMessage);

      expect(parsed.level).toBe('INFO');
      expect(parsed.service).toBe('test-bank-service');
      expect(parsed.environment).toBe('production');
      expect(parsed.correlationId).toBe('trace-abc-123');
      expect(parsed.message).toBe('Transação financeira auditada');
      expect(parsed.context.userId).toBe(42);
      expect(parsed.context.password).toBe('[REDACTED]');
    });

    it('deve respeitar filtro de LogLevel e child loggers com contexto herdado', () => {
      const memoryTransport = new MemoryTransport();
      const parentLogger = new Logger({
        level: 'warn',
        transports: [memoryTransport]
      });

      parentLogger.info('Isso não deve ser registrado pois o nível é warn');
      expect(memoryTransport.entries.length).toBe(0);

      const childLogger = parentLogger.child({ correlationId: 'child-cid-999' });
      childLogger.warn('Alerta de segurança emitido');

      expect(memoryTransport.entries.length).toBe(1);
      expect(memoryTransport.entries[0].entry.correlationId).toBe('child-cid-999');
      expect(memoryTransport.entries[0].entry.level).toBe('warn');
    });

    it('deve formatar mensagens corretamente com DevFormatter', () => {
      const devFormatter = new DevFormatter();
      const formatted = devFormatter.format({
        timestamp: '2026-09-07T12:00:00.000Z',
        level: 'info',
        message: 'Dev log message',
        service: 'seatmap',
        environment: 'development',
        correlationId: '12345678-abcd',
        context: { test: true }
      });

      expect(formatted).toContain('[INFO]');
      expect(formatted).toContain('[CID:12345678]');
      expect(formatted).toContain('Dev log message');
    });
  });

  describe('Middleware de X-Correlation-ID', () => {
    it('deve gerar e injetar X-Correlation-Id quando não fornecido no request', () => {
      const req = {
        headers: {}
      } as unknown as Request;

      const setHeaderMock = jest.fn();
      const res = {
        setHeader: setHeaderMock
      } as unknown as Response;

      const next = jest.fn();

      correlationIdMiddleware(req, res, next);

      expect(req.correlationId).toBeDefined();
      expect(typeof req.correlationId).toBe('string');
      expect(req.logger).toBeDefined();
      expect(setHeaderMock).toHaveBeenCalledWith('X-Correlation-Id', req.correlationId);
      expect(next).toHaveBeenCalled();
    });

    it('deve propagar e reutilizar X-Correlation-Id existente do cliente', () => {
      const clientTraceId = 'client-trace-id-555';
      const req = {
        headers: { 'x-correlation-id': clientTraceId }
      } as unknown as Request;

      const setHeaderMock = jest.fn();
      const res = {
        setHeader: setHeaderMock
      } as unknown as Response;

      const next = jest.fn();

      correlationIdMiddleware(req, res, next);

      expect(req.correlationId).toBe(clientTraceId);
      expect(setHeaderMock).toHaveBeenCalledWith('X-Correlation-Id', clientTraceId);
      expect(next).toHaveBeenCalled();
    });
  });

  describe('Sondas de Health Check (Liveness & Readiness)', () => {
    let mockReq: Request;
    let mockRes: Response;
    let statusMock: jest.Mock;
    let jsonMock: jest.Mock;

    beforeEach(() => {
      jest.clearAllMocks();
      statusMock = jest.fn().mockReturnThis();
      jsonMock = jest.fn();
      mockReq = {
        correlationId: 'trace-test-123'
      } as unknown as Request;
      mockRes = {
        status: statusMock,
        json: jsonMock
      } as unknown as Response;
    });

    it('HealthController.live deve responder 200 com métricas de memória e uptime', async () => {
      await HealthController.live(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(200);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        status: 'ok',
        service: 'seatmap-backend',
        memory: expect.objectContaining({
          rssMb: expect.any(Number),
          heapUsedMb: expect.any(Number)
        })
      }));
    });

    it('HealthController.ready deve responder 200 e status connected quando banco responde', async () => {
      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => ({
        rows: [{ ready: 1, db_time: '2026-09-07T12:00:00.000Z' }]
      } as any));

      await HealthController.ready(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(200);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        status: 'ready',
        database: expect.objectContaining({
          status: 'connected',
          latencyMs: expect.any(Number)
        })
      }));

      querySpy.mockRestore();
    });

    it('HealthController.ready deve responder 503 e status unhealthy quando banco falha', async () => {
      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => {
        throw new Error('Connection terminated unexpectedly');
      });

      await HealthController.ready(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(503);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        status: 'unhealthy',
        database: expect.objectContaining({
          status: 'disconnected',
          error: 'Connection terminated unexpectedly'
        })
      }));

      querySpy.mockRestore();
    });

    it('HealthController.health deve responder 200 para backward compatibility', async () => {
      await HealthController.health(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(200);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        status: 'ok',
        service: 'seatmap-backend'
      }));
    });
  });
});
