import { WebAuthnService } from '../../src/services/webAuthnService';
import pool from '../../src/config/db';

jest.mock('../../src/config/db', () => ({
  query: jest.fn()
}));

describe('WebAuthn & Biometrics Service (FIDO2 / Passkeys)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('1. RP ID e Origin Resolution', () => {
    it('deve extrair o hostname do header origin', () => {
      const rpId = WebAuthnService.getRpId('https://seatmap.empresa.com:443');
      expect(rpId).toBe('seatmap.empresa.com');
    });

    it('deve usar o host header quando origin não for informado', () => {
      const rpId = WebAuthnService.getRpId(undefined, 'api.seatmap.local:3000');
      expect(rpId).toBe('api.seatmap.local');
    });

    it('deve retornar localhost como fallback seguro', () => {
      const rpId = WebAuthnService.getRpId(undefined, undefined);
      expect(rpId).toBe('localhost');
    });

    it('deve retornar expectedOrigin correto', () => {
      const origin = WebAuthnService.getExpectedOrigin('https://app.seatmap.com');
      expect(origin).toBe('https://app.seatmap.com');
    });
  });

  describe('2. Gestão Segura de Desafios (Challenges)', () => {
    it('deve salvar, recuperar e remover challenge antes da expiração', () => {
      const key = 'test_challenge_key_1';
      WebAuthnService.saveChallenge(key, 'random_nonce_12345', 42);

      const challenge = WebAuthnService.getChallenge(key);
      expect(challenge).not.toBeNull();
      expect(challenge?.challenge).toBe('random_nonce_12345');
      expect(challenge?.userId).toBe(42);

      WebAuthnService.removeChallenge(key);
      expect(WebAuthnService.getChallenge(key)).toBeNull();
    });

    it('deve retornar null para challenge inexistente', () => {
      expect(WebAuthnService.getChallenge('non_existent_key')).toBeNull();
    });
  });

  describe('3. Geração de Opções de Registro (Passkey Attestation)', () => {
    it('deve gerar opções de registro WebAuthn válidas', async () => {
      (pool.query as jest.Mock).mockResolvedValueOnce({ rows: [] });

      const options = await WebAuthnService.generateRegisterOptions(
        { id: 10, email: 'colab@empresa.com', nome: 'Colaborador Teste' },
        'localhost'
      );

      expect(options).toBeDefined();
      expect(options.challenge).toBeDefined();
      expect(options.rp.name).toBe('SeatMap Corporativo');
      expect(options.rp.id).toBe('localhost');
      expect(options.user.name).toBe('colab@empresa.com');
      expect(options.authenticatorSelection?.authenticatorAttachment).toBe('platform');

      const saved = WebAuthnService.getChallenge('reg_10');
      expect(saved?.challenge).toBe(options.challenge);
    });
  });

  describe('4. Geração de Opções de Autenticação (Passkey Assertion)', () => {
    it('deve gerar opções de autenticação biométrica', async () => {
      (pool.query as jest.Mock).mockResolvedValueOnce({
        rowCount: 1,
        rows: [{ id: 5 }]
      }).mockResolvedValueOnce({
        rows: [{ credential_id: 'cred_abc_123', transports: ['internal'] }]
      });

      const { options, challengeKey } = await WebAuthnService.generateAuthOptions(
        'localhost',
        'colab@empresa.com'
      );

      expect(options).toBeDefined();
      expect(options.challenge).toBeDefined();
      expect(options.rpId).toBe('localhost');
      expect(challengeKey).toBe(`auth_${options.challenge}`);

      const saved = WebAuthnService.getChallenge(challengeKey);
      expect(saved?.challenge).toBe(options.challenge);
    });
  });

  describe('5. Tratamento de Erros de Verificação', () => {
    it('deve rejeitar validação de registro caso o challenge tenha expirado', async () => {
      await expect(
        WebAuthnService.verifyRegister(999, {}, 'http://localhost:3000', 'localhost')
      ).rejects.toThrow('Desafio biométrico expirado ou inexistente.');
    });

    it('deve rejeitar validação de login caso o challenge seja inválido', async () => {
      await expect(
        WebAuthnService.verifyAuth('invalid_key', {}, 'http://localhost:3000', 'localhost')
      ).rejects.toThrow('Desafio biométrico expirado.');
    });

    it('deve rejeitar autenticação se a credencial não for encontrada no banco', async () => {
      WebAuthnService.saveChallenge('auth_dummy', 'dummy_challenge');
      (pool.query as jest.Mock).mockResolvedValueOnce({ rowCount: 0, rows: [] });

      await expect(
        WebAuthnService.verifyAuth('auth_dummy', { id: 'unknown_cred' }, 'http://localhost:3000', 'localhost')
      ).rejects.toThrow('Dispositivo biométrico não cadastrado para esta conta.');
    });
  });

  describe('6. Gestão e Revogação de Dispositivos Biométricos', () => {
    it('deve listar passkeys do usuário', async () => {
      const mockPasskeys = [
        { id: 1, credential_id: 'cred_1', nome_dispositivo: 'iPhone 15' },
        { id: 2, credential_id: 'cred_2', nome_dispositivo: 'Samsung Galaxy' }
      ];
      (pool.query as jest.Mock).mockResolvedValueOnce({ rows: mockPasskeys });

      const result = await WebAuthnService.listUserPasskeys(10);
      expect(result).toEqual(mockPasskeys);
      expect(pool.query).toHaveBeenCalledWith(
        expect.stringContaining('WHERE usuario_id = $1'),
        [10]
      );
    });

    it('deve deletar passkey do usuário', async () => {
      (pool.query as jest.Mock).mockResolvedValueOnce({ rowCount: 1 });

      const deleted = await WebAuthnService.deleteUserPasskey(10, 1);
      expect(deleted).toBe(true);
      expect(pool.query).toHaveBeenCalledWith(
        expect.stringContaining('DELETE FROM usuarios_biometria_passkeys'),
        [1, 10]
      );
    });
  });
});

