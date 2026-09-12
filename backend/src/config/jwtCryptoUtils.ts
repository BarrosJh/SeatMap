import crypto from 'crypto';
import jwt, { SignOptions, VerifyOptions } from 'jsonwebtoken';
import { logger } from '../utils/logger';

/**
 * Utilitário centralizado de Criptografia e Assinatura JWT 100% Assimétrica (RS256)
 * Em conformidade com OWASP e padrões bancários BACEN.
 */
export class JwtCryptoUtils {
  private static ephemeralKeyPair: { privateKey: string; publicKey: string } | null = null;

  private static getOrGenerateKeyPair(): { privateKey: string; publicKey: string } {
    const rawPrivateKey = process.env.JWT_PRIVATE_KEY;
    const rawPublicKey = process.env.JWT_PUBLIC_KEY;

    if (rawPrivateKey && rawPrivateKey.trim().length > 0 && rawPublicKey && rawPublicKey.trim().length > 0) {
      return {
        privateKey: rawPrivateKey.replace(/\\n/g, '\n'),
        publicKey: rawPublicKey.replace(/\\n/g, '\n')
      };
    }

    const nodeEnv = (process.env.NODE_ENV || 'development').toLowerCase();
    const isProduction = nodeEnv === 'production' || nodeEnv === 'staging';

    if (isProduction) {
      const errorMsg = 'Configuração de segurança crítica ausente: JWT_PRIVATE_KEY e JWT_PUBLIC_KEY são obrigatórias em ambiente de produção/staging.';
      logger.error(`[JwtCryptoUtils] ${errorMsg}`);
      throw new Error(errorMsg);
    }

    // Em ambiente de desenvolvimento ou testes: autogera par de chaves RSA 2048-bit em memória
    if (!this.ephemeralKeyPair) {
      logger.info('[JwtCryptoUtils] JWT_PRIVATE_KEY / JWT_PUBLIC_KEY não configuradas. Gerando par de chaves RSA-2048 efêmero para ambiente de dev/teste...');
      const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', {
        modulusLength: 2048,
        publicKeyEncoding: { type: 'spki', format: 'pem' },
        privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
      });
      this.ephemeralKeyPair = { privateKey, publicKey };
    }

    return this.ephemeralKeyPair;
  }

  public static getPrivateKey(): string {
    return this.getOrGenerateKeyPair().privateKey;
  }

  public static getPublicKey(): string {
    return this.getOrGenerateKeyPair().publicKey;
  }

  public static getAlgorithm(): jwt.Algorithm {
    return 'RS256';
  }

  public static signToken(payload: object, options?: SignOptions): string {
    const privateKey = this.getPrivateKey();
    return jwt.sign(payload, privateKey, {
      ...options,
      algorithm: 'RS256'
    });
  }

  public static verifyToken(token: string, options?: VerifyOptions): any {
    const publicKey = this.getPublicKey();
    return jwt.verify(token, publicKey, {
      ...options,
      algorithms: ['RS256']
    });
  }
}


