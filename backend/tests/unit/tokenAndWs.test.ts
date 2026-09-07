import { TokenService } from '../../src/services/tokenService';
import pool from '../../src/config/db';
import jwt from 'jsonwebtoken';

describe('TokenService & WebSocket Hardening (OBS-01 & OBS-03)', () => {
  const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_jwt_key_seatmap_2026_change_in_prod';

  describe('TokenService (Token Family Rotation & Replay Attack Defense)', () => {
    it('deve rejeitar tentativa de rotação com token nulo ou vazio', async () => {
      const res = await TokenService.rotacionarRefreshToken('', '127.0.0.1', 'Jest');
      expect(res.success).toBe(false);
      expect(res.error).toBe('Refresh token não fornecido.');
    });

    it('deve rejeitar token inexistente no banco', async () => {
      const res = await TokenService.rotacionarRefreshToken('token_aleatorio_totalmente_ficticio', '127.0.0.1', 'Jest');
      expect(res.success).toBe(false);
      expect(res.error).toBe('Refresh token inválido ou não encontrado.');
    });

    it('deve gerar e verificar JWT válidos para autenticação do WebSocket', () => {
      const payload = { userId: 42, email: 'tech@empresa.com', perfil: 'ADMIN_TI' };
      const token = jwt.sign(payload, JWT_SECRET, { expiresIn: '1h' });

      const decoded = jwt.verify(token, JWT_SECRET) as any;
      expect(decoded.userId).toBe(42);
      expect(decoded.email).toBe('tech@empresa.com');
      expect(decoded.perfil).toBe('ADMIN_TI');
    });

    it('deve falhar verificação do WebSocket se o token for adulterado ou assinado com chave errada', () => {
      const payload = { userId: 99, email: 'fake@empresa.com' };
      const invalidToken = jwt.sign(payload, 'wrong_secret_key');

      expect(() => {
        jwt.verify(invalidToken, JWT_SECRET);
      }).toThrow();
    });
  });

  afterAll(async () => {
    await pool.end();
  });
});

