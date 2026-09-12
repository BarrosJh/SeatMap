import jwt, { SignOptions, VerifyOptions } from 'jsonwebtoken';
import { env } from './env';
import { logger } from '../utils/logger';

/**
 * Utilitário centralizado de Criptografia e Assinatura JWT
 * Suporta chaves assimétricas RS256/ES256 com fallback para HS256.
 */
export class JwtCryptoUtils {
  private static getPrivateKey(): string {
    const rawKey = process.env.JWT_PRIVATE_KEY;
    if (rawKey && rawKey.trim().length > 0) {
      return rawKey.replace(/\\n/g, '\n');
    }
    return env.JWT_SECRET;
  }

  private static getPublicKey(): string {
    const rawKey = process.env.JWT_PUBLIC_KEY;
    if (rawKey && rawKey.trim().length > 0) {
      return rawKey.replace(/\\n/g, '\n');
    }
    return env.JWT_SECRET;
  }

  public static getAlgorithm(): jwt.Algorithm {
    const requested = (process.env.JWT_ALGORITHM || '').toUpperCase();
    if (requested === 'RS256' || requested === 'ES256') {
      return requested as jwt.Algorithm;
    }
    if (process.env.JWT_PRIVATE_KEY && process.env.JWT_PUBLIC_KEY) {
      return 'RS256';
    }
    return 'HS256';
  }

  public static signToken(payload: object, options?: SignOptions): string {
    const algorithm = this.getAlgorithm();
    const secretOrKey = (algorithm === 'RS256' || algorithm === 'ES256')
      ? this.getPrivateKey()
      : env.JWT_SECRET;

    return jwt.sign(payload, secretOrKey, {
      ...options,
      algorithm
    });
  }

  public static verifyToken(token: string, options?: VerifyOptions): any {
    const algorithm = this.getAlgorithm();
    const secretOrKey = (algorithm === 'RS256' || algorithm === 'ES256')
      ? this.getPublicKey()
      : env.JWT_SECRET;

    return jwt.verify(token, secretOrKey, {
      ...options,
      algorithms: [algorithm, 'HS256'] // Permite transição suave se houver tokens em trânsito
    });
  }
}

