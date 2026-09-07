import crypto from 'crypto';
import { env } from '../config/env';

export class CryptoService {
  private static readonly ALGORITHM = 'aes-256-gcm';
  private static readonly IV_LENGTH = 12; // Padrão recomendado para GCM
  private static readonly PREFIX = 'enc:v1:';

  /**
   * Obtém a chave mestra de 32 bytes (256 bits) usando SHA-256 sobre a chave de ambiente estrita
   */
  private static getKey(): Buffer {
    const rawSecret = env.ENCRYPTION_KEY;
    return crypto.createHash('sha256').update(rawSecret).digest();
  }

  /**
   * Verifica se uma string já está criptografada
   */
  public static isEncrypted(value: string): boolean {
    return typeof value === 'string' && value.startsWith(this.PREFIX);
  }

  /**
   * Criptografa uma string em AES-256-GCM
   * Retorna no formato: enc:v1:<iv_hex>:<authTag_hex>:<ciphertext_hex>
   */
  public static encrypt(plainText: string): string {
    if (!plainText || typeof plainText !== 'string') {
      return plainText;
    }

    if (this.isEncrypted(plainText)) {
      return plainText;
    }

    const key = this.getKey();
    const iv = crypto.randomBytes(this.IV_LENGTH);
    const cipher = crypto.createCipheriv(this.ALGORITHM, key, iv);

    let encrypted = cipher.update(plainText, 'utf8', 'hex');
    encrypted += cipher.final('hex');

    const authTag = cipher.getAuthTag().toString('hex');
    const ivHex = iv.toString('hex');

    return `${this.PREFIX}${ivHex}:${authTag}:${encrypted}`;
  }

  /**
   * Descriptografa uma string criptografada em AES-256-GCM
   * Se o valor não for criptografado (dados legados), retorna o texto puro com segurança.
   */
  public static decrypt(cipherText: string): string {
    if (!cipherText || typeof cipherText !== 'string') {
      return cipherText;
    }

    if (!this.isEncrypted(cipherText)) {
      // Retorna o valor original para manter retrocompatibilidade com senhas legadas
      return cipherText;
    }

    try {
      const parts = cipherText.substring(this.PREFIX.length).split(':');
      if (parts.length !== 3) {
        console.error('[CryptoService.decrypt] Formato de payload cifrado inválido.');
        return cipherText;
      }

      const [ivHex, authTagHex, encryptedHex] = parts;
      const key = this.getKey();
      const iv = Buffer.from(ivHex, 'hex');
      const authTag = Buffer.from(authTagHex, 'hex');

      const decipher = crypto.createDecipheriv(this.ALGORITHM, key, iv);
      decipher.setAuthTag(authTag);

      let decrypted = decipher.update(encryptedHex, 'hex', 'utf8');
      decrypted += decipher.final('utf8');

      return decrypted;
    } catch (error) {
      console.error('[CryptoService.decrypt] Falha ao descriptografar valor:', error);
      // Se falhar a autenticação ou descriptografia, retorna string vazia por segurança
      return '';
    }
  }
}

