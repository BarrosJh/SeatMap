import { Request, Response } from 'express';
import { validateRequest } from '../../src/middleware/validateRequest';
import {
  criarReservaSchema,
  loginSchema,
  paginationQuerySchema,
  tiConfigSchema,
  usuarioListQuerySchema,
  scimPatchSchema
} from '../../src/schemas';

describe('Bloco 4: validação e hardening de entrada', () => {
  const runMiddleware = async (schema: any, request: Partial<Request>) => {
    const req = { body: {}, query: {}, params: {}, ...request } as Request;
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    } as unknown as Response;
    const next = jest.fn();

    await validateRequest({ body: schema })(req, res, next);
    return { req, res, next };
  };

  it('aceita login válido e rejeita campos desconhecidos', async () => {
    const valid = await runMiddleware(loginSchema, {
      body: { login: 'usuario@empresa.com', senha: 'SenhaForte@2026' }
    });
    expect(valid.next).toHaveBeenCalled();

    const invalid = await runMiddleware(loginSchema, {
      body: { login: 'usuario@empresa.com', senha: 'SenhaForte@2026', permissaoTi: true }
    });
    expect(invalid.res.status).toHaveBeenCalledWith(400);
    expect(invalid.next).not.toHaveBeenCalled();
  });

  it('rejeita reserva com ID inválido ou data fora do formato', async () => {
    const invalid = await runMiddleware(criarReservaSchema, {
      body: { cadeiraId: 'abc', dataReserva: '07/09/2026' }
    });
    expect(invalid.res.status).toHaveBeenCalledWith(400);
    expect(invalid.next).not.toHaveBeenCalled();

    const valid = await runMiddleware(criarReservaSchema, {
      body: { cadeiraId: '10', dataReserva: '2026-09-07' }
    });
    expect(valid.next).toHaveBeenCalled();
    expect(valid.req.body).toEqual({ cadeiraId: 10, dataReserva: '2026-09-07' });
  });

  it('limita paginação e normaliza query strings', async () => {
    const valid = await runMiddleware(paginationQuerySchema, {
      body: { limit: '50', offset: '20' }
    });
    expect(valid.next).toHaveBeenCalled();

    const oversized = await runMiddleware(paginationQuerySchema, {
      body: { limit: '101', offset: '0' }
    });
    expect(oversized.res.status).toHaveBeenCalledWith(400);
  });

  it('rejeita filtros e configurações acima dos limites definidos', async () => {
    const queryResult = await validateRequest({ query: usuarioListQuerySchema })(
      { query: { busca: 'x'.repeat(256), limit: '10', offset: '0' } } as any,
      { status: jest.fn().mockReturnThis(), json: jest.fn() } as any,
      jest.fn()
    );
    expect(queryResult).toBeUndefined();

    const config = await runMiddleware(tiConfigSchema, {
      body: { smtpHost: 'x'.repeat(256) }
    });
    expect(config.res.status).toHaveBeenCalledWith(400);
  });

  it('aceita operações SCIM limitadas e rejeita lote excessivo', async () => {
    const valid = await runMiddleware(scimPatchSchema, {
      body: { Operations: [{ op: 'replace', path: 'active', value: false }] }
    });
    expect(valid.next).toHaveBeenCalled();

    const invalid = await runMiddleware(scimPatchSchema, {
      body: { Operations: Array.from({ length: 21 }, () => ({ op: 'replace', path: 'active', value: false })) }
    });
    expect(invalid.res.status).toHaveBeenCalledWith(400);
  });
});