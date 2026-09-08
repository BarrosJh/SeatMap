import { internalProbeAuth } from '../../src/middleware/internalProbeAuth';

describe('Autorização das probes internas', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv, NODE_ENV: 'production', INTERNAL_HEALTH_TOKEN: 'a'.repeat(32) };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  it('aceita o token configurado', () => {
    const next = jest.fn();
    const response = { status: jest.fn().mockReturnThis(), json: jest.fn() } as any;

    internalProbeAuth({ headers: { 'x-health-token': 'a'.repeat(32) } } as any, response, next);

    expect(next).toHaveBeenCalledTimes(1);
    expect(response.status).not.toHaveBeenCalled();
  });

  it('responde 404 sem revelar que a rota existe quando o token é inválido', () => {
    const next = jest.fn();
    const response = { status: jest.fn().mockReturnThis(), json: jest.fn() } as any;

    internalProbeAuth({ headers: { 'x-health-token': 'invalid' } } as any, response, next);

    expect(next).not.toHaveBeenCalled();
    expect(response.status).toHaveBeenCalledWith(404);
    expect(response.json).toHaveBeenCalledWith({ error: 'Not Found' });
  });

  it('mantém acesso local sem token fora de produção', () => {
    process.env.NODE_ENV = 'development';
    delete process.env.INTERNAL_HEALTH_TOKEN;
    const next = jest.fn();

    internalProbeAuth({ headers: {} } as any, {} as any, next);

    expect(next).toHaveBeenCalledTimes(1);
  });
});