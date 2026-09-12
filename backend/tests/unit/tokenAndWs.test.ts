import { TokenService } from '../../src/services/tokenService';
import { WsManager } from '../../src/websocket/wsServer';
import pool from '../../src/config/db';
import { JwtCryptoUtils } from '../../src/config/jwtCryptoUtils';

describe('TokenService & Autenticação WebSocket', () => {
  describe('TokenService (Rotação de Refresh Tokens e Prevenção de Replay)', () => {
    it('deve rejeitar tentativa de rotação com token nulo ou vazio', async () => {
      const res = await TokenService.rotacionarRefreshToken('', '127.0.0.1', 'Jest');
      expect(res.success).toBe(false);
      expect(res.error).toBe('Refresh token não fornecido.');
    });

    it('deve rejeitar token inexistente no banco', async () => {
      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => ({
        rowCount: 0,
        rows: []
      } as any));

      const res = await TokenService.rotacionarRefreshToken('token_aleatorio_totalmente_ficticio', '127.0.0.1', 'Jest');
      expect(res.success).toBe(false);
      expect(res.error).toBe('Refresh token inválido ou não encontrado.');

      querySpy.mockRestore();
    });

    it('deve gerar e verificar JWT válidos para autenticação do WebSocket', () => {
      const payload = { userId: 42, email: 'tech@empresa.com', perfil: 'ADMIN_TI' };
      const token = JwtCryptoUtils.signToken(payload, { expiresIn: '1h' });

      const decoded = JwtCryptoUtils.verifyToken(token) as any;
      expect(decoded.userId).toBe(42);
      expect(decoded.email).toBe('tech@empresa.com');
      expect(decoded.perfil).toBe('ADMIN_TI');
    });

    it('deve falhar verificação do WebSocket se o token for adulterado ou assinado com chave errada', () => {
      const invalidToken = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.invalidpayload.invalidsig';

      expect(() => {
        JwtCryptoUtils.verifyToken(invalidToken);
      }).toThrow();
    });
  });

  describe('WsManager (Validação Atômica no Pré-Upgrade)', () => {
    it('deve extrair token via Sec-WebSocket-Protocol, Authorization e query param', () => {
      const reqWithProtocol: any = {
        headers: { 'sec-websocket-protocol': 'bearer, eyJhbGciOi...' }
      };
      expect(WsManager.extractToken(reqWithProtocol)).toBe('eyJhbGciOi...');

      const reqWithAuthHeader: any = {
        headers: { authorization: 'Bearer eyJhbGciOiHeader...' }
      };
      expect(WsManager.extractToken(reqWithAuthHeader)).toBe('eyJhbGciOiHeader...');

      const reqWithQuery: any = {
        headers: {},
        url: '/ws?token=queryToken123'
      };
      expect(WsManager.extractToken(reqWithQuery)).toBe('queryToken123');
    });

    it('authenticateRequest deve rejeitar requisição sem token', async () => {
      const req: any = { headers: {} };
      const result = await WsManager.authenticateRequest(req);
      expect(result.valid).toBe(false);
      expect(result.reason).toContain('não fornecido');
    });

    it('authenticateRequest deve validar token legítimo e usuário ativo', async () => {
      const token = JwtCryptoUtils.signToken({ userId: 15, email: 'ativo@empresa.com', tokenVersion: 1 });
      const req: any = {
        headers: { authorization: `Bearer ${token}` }
      };

      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => ({
        rowCount: 1,
        rows: [{ ativo: true, token_version: 1 }]
      } as any));

      const result = await WsManager.authenticateRequest(req);
      expect(result.valid).toBe(true);
      expect(result.user.userId).toBe(15);

      querySpy.mockRestore();
    });

    it('authenticateRequest deve rejeitar conexão com tokenVersion defasada (sessão revogada)', async () => {
      const token = JwtCryptoUtils.signToken({ userId: 15, email: 'ativo@empresa.com', tokenVersion: 1 });
      const req: any = {
        headers: { authorization: `Bearer ${token}` }
      };

      // Banco já está na versão 2 (revogado)
      const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => ({
        rowCount: 1,
        rows: [{ ativo: true, token_version: 2 }]
      } as any));

      const result = await WsManager.authenticateRequest(req);
      expect(result.valid).toBe(false);
      expect(result.reason).toContain('revogada');

      querySpy.mockRestore();
    });
  });

  afterAll(async () => {
    await pool.end();
  });
});
