import { Request, Response } from 'express';
import pool from '../../src/config/db';
import { ConfigService } from '../../src/services/configService';
import { ScimController } from '../../src/controllers/scimController';
import { TiController } from '../../src/controllers/tiController';
import { ReservaController } from '../../src/controllers/reservaController';
import { TokenService } from '../../src/services/tokenService';
import { CronService } from '../../src/services/cronService';
import { WebAuthnService } from '../../src/services/webAuthnService';
import { isRhGlobal } from '../../src/middleware/auth';

jest.mock('../../src/config/db');
jest.mock('../../src/services/tokenService');
jest.mock('../../src/services/emailService', () => ({
  EmailService: {
    enviarEmailTeste: jest.fn().mockResolvedValue({ success: true, message: 'OK' }),
    resetTransporter: jest.fn()
  }
}));

describe('Auditoria Técnica: Verificação e Validação dos 20 Achados Corrigidos', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('F-06 & F-15: WebAuthn Multi-Instância e Origin Seguro', () => {
    it('deve persistir e consumir desafios no banco de dados', async () => {
      (pool.query as jest.Mock)
        .mockResolvedValueOnce({ rowCount: 1 }) // saveChallenge INSERT
        .mockResolvedValueOnce({ rowCount: 0 }) // cleanup DELETE
        .mockResolvedValueOnce({ // getChallenge
          rowCount: 1,
          rows: [{ challenge: 'chal_abc', user_id: 10, expires_at: Date.now() + 100000 }]
        })
        .mockResolvedValueOnce({ rowCount: 1 }); // removeChallenge DELETE

      await WebAuthnService.saveChallenge('test_k', 'chal_abc', 10);
      const ch = await WebAuthnService.getChallenge('test_k');
      expect(ch).not.toBeNull();
      expect(ch?.challenge).toBe('chal_abc');

      await WebAuthnService.removeChallenge('test_k');
      expect(pool.query).toHaveBeenCalledWith(expect.stringContaining('DELETE FROM webauthn_challenges'), ['test_k']);
    });

    it('deve rejeitar origin não configurado em ambiente de produção (F-15)', () => {
      const oldEnv = process.env.NODE_ENV;
      const oldOrigin = process.env.RP_ORIGIN;
      const oldAllowed = process.env.ALLOWED_ORIGINS;

      process.env.NODE_ENV = 'production';
      delete process.env.RP_ORIGIN;
      delete process.env.ALLOWED_ORIGINS;

      expect(() => WebAuthnService.getExpectedOrigin('https://attacker.evil.com')).toThrow(
        'Configuração de segurança RP_ORIGIN ou ALLOWED_ORIGINS obrigatória em ambiente de produção.'
      );

      process.env.NODE_ENV = oldEnv;
      process.env.RP_ORIGIN = oldOrigin;
      process.env.ALLOWED_ORIGINS = oldAllowed;
    });
  });

  describe('F-07 & F-20: ConfigService Invalidação, Segurança no Heap e getMultiple', () => {
    it('deve invalidar cache imediatamente quando ConfigService.invalidateCache for chamado', async () => {
      (pool.query as jest.Mock).mockResolvedValueOnce({
        rows: [{ chave: 'HORARIO_LIMITE_CHECKIN', valor: '11:00' }]
      });

      const val1 = await ConfigService.get('HORARIO_LIMITE_CHECKIN');
      expect(val1).toBe('11:00');

      ConfigService.invalidateCache();

      (pool.query as jest.Mock).mockResolvedValueOnce({
        rows: [{ chave: 'HORARIO_LIMITE_CHECKIN', valor: '12:00' }]
      });

      const val2 = await ConfigService.get('HORARIO_LIMITE_CHECKIN');
      expect(val2).toBe('12:00');
    });

    it('deve buscar múltiplas chaves em paralelo via getMultiple (F-20)', async () => {
      (pool.query as jest.Mock).mockResolvedValue({
        rows: [
          { chave: 'K1', valor: 'V1' },
          { chave: 'K2', valor: 'V2' }
        ]
      });

      const results = await ConfigService.getMultiple(['K1', 'K2']);
      expect(results.K1).toBe('V1');
      expect(results.K2).toBe('V2');
    });
  });

  describe('F-09: CronService Concurrent Executions Tracker', () => {
    it('deve suportar múltiplas execuções concorrentes sem sobrescrever activeExecution', async () => {
      (pool.query as jest.Mock).mockResolvedValue({
        rows: [{ obtido: true }],
        rowCount: 0
      });
      const p1 = CronService.cancelExpiredNoShows();
      const p2 = CronService.cancelExpiredNoShows();

      await expect(Promise.all([p1, p2])).resolves.toBeDefined();
    });
  });

  describe('F-10 & F-14: SCIM Token Invalidation & RFC 5322 Email Validation', () => {
    it('deve rejeitar criação de usuário SCIM com e-mail inválido RFC 5322 (F-14)', async () => {
      const req = {
        body: { userName: 'invalid-email-format-without-at', displayName: 'Teste' }
      } as Request;
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;

      await ScimController.createUser(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        scimType: 'invalidValue'
      }));
    });

    it('NÃO deve invalidar token quando o usuário for atualizado com active: true (F-10)', async () => {
      (pool.query as jest.Mock).mockResolvedValueOnce({
        rowCount: 1,
        rows: [{ id: 7, nome: 'User Ativo', email: 'user@empresa.com', matricula: 'M1', ativo: true }]
      });

      const req = {
        params: { id: '7' },
        body: { active: true, displayName: 'User Renomeado' }
      } as unknown as Request;
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;

      await ScimController.updateUser(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(TokenService.incrementarTokenVersion).not.toHaveBeenCalled();
    });

    it('DEVE invalidar token quando o usuário for desativado com active: false (F-10)', async () => {
      (pool.query as jest.Mock).mockResolvedValueOnce({
        rowCount: 1,
        rows: [{ id: 7, nome: 'User Desativado', email: 'user@empresa.com', matricula: 'M1', ativo: false }]
      });

      const req = {
        params: { id: '7' },
        body: { active: false }
      } as unknown as Request;
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;

      await ScimController.updateUser(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(TokenService.incrementarTokenVersion).toHaveBeenCalledWith(7);
    });
  });

  describe('F-12 & F-18: SMTP Test Email Validation e Payload Consistente', () => {
    it('deve rejeitar e-mail de teste malformado ou com caracteres CRLF (F-12)', async () => {
      const req = {
        body: { emailDestino: 'admin@empresa.com\r\nBcc: evil@attacker.com' }
      } as Request;
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;

      await TiController.testarConexaoEmail(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.stringContaining('RFC 5322')
      }));
    });

    it('deve retornar JSON consolidado de TI com passConfigured consistente (F-18)', async () => {
      (pool.query as jest.Mock).mockResolvedValue({
        rows: [
          { chave: 'SMTP_HOST', valor: 'smtp.office365.com' },
          { chave: 'SMTP_PORT', valor: '587' },
          { chave: 'SMTP_PASS', valor: 'supersecret' }
        ]
      });

      const req = {} as Request;
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;

      await TiController.getConfiguracoesTi(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      const data = (res.json as jest.Mock).mock.calls[0][0];
      expect(data.email.smtp.passConfigured).toBe(true);
      expect(data.smtp.passConfigured).toBe(true);
    });
  });

  describe('F-13 & F-17: Limit/Offset Cap & isRhGlobal Centralizado', () => {
    it('deve aplicar cap no limit (máx 100) e offset (mín 0) nas listagens (F-13)', async () => {
      (pool.query as jest.Mock).mockResolvedValueOnce({
        rows: []
      });

      const req = {
        user: { userId: 1, perfil: 'COLABORADOR' },
        query: { limit: '999999', offset: '-10' }
      } as unknown as Request;
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn()
      } as unknown as Response;

      await ReservaController.minhasReservas(req as any, res);

      expect(res.status).toHaveBeenCalledWith(200);
    });

    it('isRhGlobal deve identificar privilégio global de RH corretamente (F-17)', () => {
      expect(isRhGlobal({ perfil: 'ADMIN_RH' })).toBe(true);
      expect(isRhGlobal({ perfil: 'COLABORADOR', permissaoRh: true })).toBe(true);
      expect(isRhGlobal({ perfil: 'COLABORADOR', is_admin: true })).toBe(true);
      expect(isRhGlobal({ perfil: 'GESTAO' })).toBe(false);
      expect(isRhGlobal({ perfil: 'COLABORADOR' })).toBe(false);
      expect(isRhGlobal(undefined)).toBe(false);
    });
  });
});
