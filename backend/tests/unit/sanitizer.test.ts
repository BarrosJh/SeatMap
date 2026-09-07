import { sanitizeText, sanitizeForLog, maskSensitiveData } from '../../src/utils/sanitizer';

describe('Sanitizer & Log Masking Security Utility', () => {
  describe('sanitizeText (Anti-XSS)', () => {
    it('deve escapar tags HTML perigosas', () => {
      const dirty = '<script>alert("xss")</script>';
      const clean = sanitizeText(dirty);
      expect(clean).not.toContain('<script>');
      expect(clean).toContain('&lt;script&gt;');
    });

    it('deve escapar aspas e barras para prevenir injeções de atributos', () => {
      const dirty = `" onfocus="alert('hack') /`;
      const clean = sanitizeText(dirty);
      expect(clean).toContain('&quot;');
      expect(clean).toContain('&#x27;');
      expect(clean).toContain('&#x2F;');
    });
  });

  describe('sanitizeForLog (Anti-CRLF Injection)', () => {
    it('deve remover quebras de linha e retornos de carro', () => {
      const forged = 'admin_login\r\n[CRITICAL] System Compromised\nFake log entry';
      const clean = sanitizeForLog(forged);
      expect(clean).not.toContain('\r');
      expect(clean).not.toContain('\n');
    });
  });

  describe('maskSensitiveData (Log Masking)', () => {
    it('deve mascarar senhas, hashes e tokens sensíveis', () => {
      const payload = {
        email: 'user@corp.com',
        senha: 'SecretPassword@123',
        senha_hash: '$2b$10$abcdefghijklmnopqrstuvwxyz',
        totp_secret: 'JBSWY3DPEHPK3PXP',
        totp_backup_codes: ['code1', 'code2'],
        token: 'eyJh...secret',
        departamento: 'TI'
      };

      const masked = maskSensitiveData(payload);
      expect(masked.email).toBe('user@corp.com');
      expect(masked.departamento).toBe('TI');
      expect(masked.senha).toBe('***REDACTED***');
      expect(masked.senha_hash).toBe('***REDACTED***');
      expect(masked.totp_secret).toBe('***REDACTED***');
      expect(masked.totp_backup_codes).toBe('***REDACTED***');
      expect(masked.token).toBe('***REDACTED***');
    });

    it('deve mascarar objetos aninhados', () => {
      const nested = {
        user: {
          nome: 'Fulano',
          auth: {
            password: 'SuperSecret123!',
            apiKey: 'key_123456'
          }
        }
      };

      const masked = maskSensitiveData(nested);
      expect(masked.user.nome).toBe('Fulano');
      expect(masked.user.auth.password).toBe('***REDACTED***');
      expect(masked.user.auth.apiKey).toBe('***REDACTED***');
    });
  });
});

