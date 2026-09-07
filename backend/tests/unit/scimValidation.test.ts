import { Request, Response } from 'express';
import { scimAuth } from '../../src/middleware/scimAuth';
import { ScimController } from '../../src/controllers/scimController';

describe('SCIM 2.0 Identity Management & Authentication', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
    process.env.SCIM_BEARER_TOKEN = 'secret-scim-test-token-2026';
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  describe('scimAuth Middleware', () => {
    it('deve rejeitar requisições sem header Authorization', () => {
      const req = { headers: {} } as Request;
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;
      const next = jest.fn();

      scimAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        schemas: ['urn:ietf:params:scim:api:messages:2.0:Error'],
        status: '401'
      }));
      expect(next).not.toHaveBeenCalled();
    });

    it('deve rejeitar tokens incorretos', () => {
      const req = { headers: { authorization: 'Bearer wrong-token-123' } } as Request;
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;
      const next = jest.fn();

      scimAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(next).not.toHaveBeenCalled();
    });

    it('deve permitir acesso com Bearer Token SCIM válido', () => {
      const req = { headers: { authorization: 'Bearer secret-scim-test-token-2026' } } as Request;
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;
      const next = jest.fn();

      scimAuth(req, res, next);

      expect(next).toHaveBeenCalled();
      expect(res.status).not.toHaveBeenCalled();
    });

    it('deve retornar 500 se o servidor não tiver SCIM_BEARER_TOKEN configurado', () => {
      delete process.env.SCIM_BEARER_TOKEN;

      const req = { headers: { authorization: 'Bearer some-token' } } as Request;
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;
      const next = jest.fn();

      scimAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        schemas: ['urn:ietf:params:scim:api:messages:2.0:Error'],
        status: '500'
      }));
      expect(next).not.toHaveBeenCalled();
    });
  });

  describe('ScimController.getUsers Filter Validation', () => {
    it('deve retornar 400 com scimType invalidFilter quando o filtro não for suportado', async () => {
      const req = {
        query: { filter: 'title pr' }
      } as unknown as Request;
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;

      await ScimController.getUsers(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        schemas: ['urn:ietf:params:scim:api:messages:2.0:Error'],
        scimType: 'invalidFilter',
        status: '400'
      }));
    });
  });

  describe('ScimController.getServiceProviderConfig', () => {
    it('deve retornar ServiceProviderConfig em conformidade com RFC 7644 §5', async () => {
      const req = {} as Request;
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;

      await ScimController.getServiceProviderConfig(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        schemas: ['urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig'],
        patch: { supported: true },
        filter: expect.objectContaining({ supported: true }),
        authenticationSchemes: expect.arrayContaining([
          expect.objectContaining({ type: 'oauthbearertoken' })
        ])
      }));
    });
  });
});

