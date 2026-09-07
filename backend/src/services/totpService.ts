import crypto from 'crypto';
import { CryptoService } from './cryptoService';

const BASE32_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

export class TotpService {
  private static readonly TIME_STEP_SECONDS = 30;
  private static readonly DIGITS = 6;

  /**
   * Converte Buffer para Base32 (RFC 4648)
   */
  public static bufferToBase32(buffer: Buffer): string {
    let bits = 0;
    let value = 0;
    let output = '';

    for (let i = 0; i < buffer.length; i++) {
      value = (value << 8) | buffer[i];
      bits += 8;

      while (bits >= 5) {
        output += BASE32_CHARS[(value >>> (bits - 5)) & 31];
        bits -= 5;
      }
    }

    if (bits > 0) {
      output += BASE32_CHARS[(value << (5 - bits)) & 31];
    }

    return output;
  }

  /**
   * Converte Base32 para Buffer
   */
  public static base32ToBuffer(base32: string): Buffer {
    const cleaned = base32.toUpperCase().replace(/=+$/, '').replace(/\s+/g, '');
    let bits = 0;
    let value = 0;
    const bytes: number[] = [];

    for (let i = 0; i < cleaned.length; i++) {
      const idx = BASE32_CHARS.indexOf(cleaned[i]);
      if (idx === -1) continue;

      value = (value << 5) | idx;
      bits += 5;

      if (bits >= 8) {
        bytes.push((value >>> (bits - 8)) & 255);
        bits -= 8;
      }
    }

    return Buffer.from(bytes);
  }

  /**
   * Gera um segredo aleatório Base32 de 20 bytes (160 bits - padrão RFC 6238)
   */
  public static generateSecret(): string {
    const randomBytes = crypto.randomBytes(20);
    return this.bufferToBase32(randomBytes);
  }

  /**
   * Gera a URI padrão compatível com Google Authenticator, Microsoft Authenticator e Authy
   */
  public static generateOtpauthUri(secret: string, email: string, issuer: string = 'SeatMap Corporativo'): string {
    const encodedIssuer = encodeURIComponent(issuer);
    const encodedEmail = encodeURIComponent(email);
    return `otpauth://totp/${encodedIssuer}:${encodedEmail}?secret=${secret}&issuer=${encodedIssuer}&algorithm=SHA1&digits=${this.DIGITS}&period=${this.TIME_STEP_SECONDS}`;
  }

  /**
   * Gera o token numérico para um determinado contador de tempo
   */
  public static generateTokenForCounter(secret: string, counter: number): string {
    const key = this.base32ToBuffer(secret);
    const counterBuffer = Buffer.alloc(8);
    counterBuffer.writeBigInt64BE(BigInt(counter));

    const hmac = crypto.createHmac('sha1', key);
    hmac.update(counterBuffer);
    const digest = hmac.digest();

    const offset = digest[digest.length - 1] & 0x0f;
    const binary =
      ((digest[offset] & 0x7f) << 24) |
      ((digest[offset + 1] & 0xff) << 16) |
      ((digest[offset + 2] & 0xff) << 8) |
      (digest[offset + 3] & 0xff);

    const otp = binary % Math.pow(10, this.DIGITS);
    return otp.toString().padStart(this.DIGITS, '0');
  }

  /**
   * Gera o token atual baseado no timestamp Unix
   */
  public static generateToken(secret: string, offsetSteps: number = 0): string {
    const currentCounter = Math.floor(Date.now() / 1000 / this.TIME_STEP_SECONDS) + offsetSteps;
    return this.generateTokenForCounter(secret, currentCounter);
  }

  /**
   * Valida se um código TOTP de 6 dígitos é válido para o segredo fornecido (com janela de tolerância de ±1 step = ±30s)
   */
  public static verifyToken(token: string, rawSecretOrCipher: string, windowSteps: number = 1): boolean {
    if (!token || typeof token !== 'string') return false;
    const cleanToken = token.trim();
    if (cleanToken.length !== this.DIGITS) return false;

    const secret = CryptoService.isEncrypted(rawSecretOrCipher)
      ? CryptoService.decrypt(rawSecretOrCipher)
      : rawSecretOrCipher;

    if (!secret) return false;

    const currentCounter = Math.floor(Date.now() / 1000 / this.TIME_STEP_SECONDS);

    for (let error = -windowSteps; error <= windowSteps; error++) {
      const expectedToken = this.generateTokenForCounter(secret, currentCounter + error);
      if (expectedToken === cleanToken) {
        return true;
      }
    }

    return false;
  }

  /**
   * Gera conjunto de 8 Códigos de Backup (Scratch codes)
   */
  public static generateBackupCodes(count: number = 8): string[] {
    const codes: string[] = [];
    for (let i = 0; i < count; i++) {
      const code = crypto.randomBytes(4).toString('hex').toUpperCase(); // 8 caracteres (ex: A1B2C3D4)
      codes.push(`${code.slice(0, 4)}-${code.slice(4)}`);
    }
    return codes;
  }
}

