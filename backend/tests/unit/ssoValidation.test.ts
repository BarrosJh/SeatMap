import { SsoService } from '../../src/services/ssoService';
import { validateSecurityConfig } from '../../src/config/securityValidation';

describe('Validação de Segurança SSO & Fail-Fast (SEC-01 & SEC-02)', () => {
  describe('SsoService.verifyIdToken (SEC-01)', () => {
    it('deve rejeitar tokens vazios ou nulos com erro explícito', async () => {
      // @ts-ignore
      await expect(SsoService.verifyIdToken('google', null)).rejects.toThrow('idToken não fornecido');
      await expect(SsoService.verifyIdToken('azure', '')).rejects.toThrow('idToken não fornecido');
    });

    it('deve rejeitar provedor não suportado', async () => {
      await expect(SsoService.verifyIdToken('facebook', 'dummy.jwt.token')).rejects.toThrow('não suportado');
    });

    it('deve rejeitar tokens malformados que não são JWTs válidos', async () => {
      await expect(SsoService.verifyIdToken('google', 'invalid_jwt_format')).rejects.toThrow();
    });
  });

  describe('validateSecurityConfig Fail-Fast Guard (SEC-02)', () => {
    const originalEnv = process.env;

    beforeEach(() => {
      jest.resetModules();
      process.env = { ...originalEnv };
    });

    afterAll(async () => {
      process.env = originalEnv;
      const pool = (await import('../../src/config/db')).default;
      await pool.end();
    });

    it('não deve disparar erro quando em ambiente de teste ou desenvolvimento', () => {
      process.env.NODE_ENV = 'development';
      expect(() => validateSecurityConfig()).not.toThrow();

      process.env.NODE_ENV = 'test';
      expect(() => validateSecurityConfig()).not.toThrow();
    });

    it('deve chamar process.exit(1) em produção se JWT_SECRET for fraco ou contiver chaves padrão', () => {
      process.env.NODE_ENV = 'production';
      process.env.JWT_SECRET = 'super_secret_jwt_key_seatmap_2026_change_in_prod';
      
      const mockExit = jest.spyOn(process, 'exit').mockImplementation((code?: string | number | null | undefined) => {
        throw new Error(`process.exit called with ${code}`);
      });

      expect(() => validateSecurityConfig()).toThrow('process.exit called with 1');
      mockExit.mockRestore();
    });
  });
});

