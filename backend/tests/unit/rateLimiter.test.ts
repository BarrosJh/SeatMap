import { AuditService } from '../../src/services/auditService';
import { authRateLimiter } from '../../src/middleware/rateLimiter';

describe('Bloco 5: rate limiting e alertas de abuso', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('registra auditoria quando o limite de autenticacao por IP e excedido', async () => {
    const logSpy = jest.spyOn(AuditService, 'log').mockImplementation(() => undefined);
    const req: any = {
      ip: '203.0.113.10',
      socket: { remoteAddress: '203.0.113.10' },
      headers: { 'user-agent': 'jest' },
      body: { login: 'usuario@empresa.com' },
      path: '/api/auth/login',
      method: 'POST'
    };
    const res: any = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
      setHeader: jest.fn()
    };

    for (let attempt = 0; attempt < 50; attempt += 1) {
      await new Promise<void>((resolve, reject) => {
        authRateLimiter(req, res, (error?: unknown) => error ? reject(error) : resolve());
      });
    }

    await authRateLimiter(req, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(429);
    expect(logSpy).toHaveBeenCalledWith(expect.objectContaining({
      tipoEvento: 'LOGIN_CONTA_BLOQUEADA',
      sucesso: false,
      loginInformado: 'usuario@empresa.com'
    }));
  });
});