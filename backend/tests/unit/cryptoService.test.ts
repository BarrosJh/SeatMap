import { CryptoService } from '../../src/services/cryptoService';

describe('CryptoService (AES-256-GCM Enterprise Encryption)', () => {
  it('deve criptografar e descriptografar texto puro com sucesso', () => {
    const secretMessage = 'MinhaSenhaCorporativaForte@2026';
    const encrypted = CryptoService.encrypt(secretMessage);

    expect(encrypted).toBeDefined();
    expect(encrypted.startsWith('enc:v1:')).toBe(true);
    expect(CryptoService.isEncrypted(encrypted)).toBe(true);

    const decrypted = CryptoService.decrypt(encrypted);
    expect(decrypted).toBe(secretMessage);
  });

  it('não deve re-criptografar uma string já criptografada (idempotência)', () => {
    const raw = 'ApiKey_Super_Secreta';
    const firstEncryption = CryptoService.encrypt(raw);
    const secondEncryption = CryptoService.encrypt(firstEncryption);

    expect(secondEncryption).toBe(firstEncryption);
  });

  it('deve retornar texto puro se o dado fornecido não for criptografado (retrocompatibilidade legada)', () => {
    const legacyPlain = 'senha_plana_legada_123';
    expect(CryptoService.isEncrypted(legacyPlain)).toBe(false);
    expect(CryptoService.decrypt(legacyPlain)).toBe(legacyPlain);
  });

  it('deve gerar vetores de inicialização (IV) únicos para o mesmo texto plano (anti-padrão de repetição)', () => {
    const text = 'MesmoTextoPlano';
    const enc1 = CryptoService.encrypt(text);
    const enc2 = CryptoService.encrypt(text);

    expect(enc1).not.toBe(enc2);
    expect(CryptoService.decrypt(enc1)).toBe(text);
    expect(CryptoService.decrypt(enc2)).toBe(text);
  });

  it('deve rejeitar e retornar string vazia caso o ciphertext ou a tag de autenticação sejam adulterados', () => {
    const text = 'IntegridadeDosDados';
    const enc = CryptoService.encrypt(text);

    // Corrompe o payload
    const corrupted = enc.slice(0, -4) + 'abcd';
    const result = CryptoService.decrypt(corrupted);

    expect(result).toBe('');
  });

  it('deve lidar com valores vazios ou não-string graciosamente', () => {
    expect(CryptoService.encrypt('')).toBe('');
    expect(CryptoService.decrypt('')).toBe('');
    // @ts-ignore
    expect(CryptoService.encrypt(null)).toBeNull();
    // @ts-ignore
    expect(CryptoService.decrypt(undefined)).toBeUndefined();
  });
});

