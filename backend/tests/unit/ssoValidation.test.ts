import { SsoService } from '../../src/services/ssoService';
import { validateSecurityConfig } from '../../src/config/securityValidation';

describe('Validação de Segurança SSO & Configuração', () => {
  describe('SsoService.verifyIdToken', () => {
    it('deve rejeitar tokens vazios ou nulos com erro explícito', async () => {
      // @ts-ignore
      await expect(SsoService.verifyIdToken('azure', null)).rejects.toThrow('idToken não fornecido');
      await expect(SsoService.verifyIdToken('microsoft', '')).rejects.toThrow('idToken não fornecido');
    });

    it('deve rejeitar provedor não suportado (ex: google, okta, facebook)', async () => {
      await expect(SsoService.verifyIdToken('google', 'dummy.jwt.token')).rejects.toThrow('não suportado');
      await expect(SsoService.verifyIdToken('okta', 'dummy.jwt.token')).rejects.toThrow('não suportado');
      await expect(SsoService.verifyIdToken('facebook', 'dummy.jwt.token')).rejects.toThrow('não suportado');
    });

    it('deve rejeitar tokens malformados que não são JWTs válidos', async () => {
      await expect(SsoService.verifyIdToken('azure', 'invalid_jwt_format')).rejects.toThrow();
      await expect(SsoService.verifyIdToken('microsoft', 'invalid_jwt_format')).rejects.toThrow();
    });
  });

  describe('validateSecurityConfig Guard', () => {
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

    it('deve chamar process.exit(1) em produção se JWT_MFA_TEMP_SECRET for fraco ou ausente', () => {
      process.env.NODE_ENV = 'production';
      process.env.JWT_SECRET = 'uma_chave_jwt_muito_forte_com_mais_de_32_caracteres_12345';
      process.env.JWT_ADMIN_SECRET = 'outra_chave_admin_muito_forte_com_mais_de_32_caracteres_67890';
      process.env.JWT_MFA_TEMP_SECRET = 'super_secret_temp_mfa_token_key_2026';
      
      const mockExit = jest.spyOn(process, 'exit').mockImplementation((code?: string | number | null | undefined) => {
        throw new Error(`process.exit called with ${code}`);
      });

      expect(() => validateSecurityConfig()).toThrow('process.exit called with 1');
      mockExit.mockRestore();
    });
  });
});

