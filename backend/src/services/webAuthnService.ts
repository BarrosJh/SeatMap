import {
  generateRegistrationOptions,
  verifyRegistrationResponse,
  generateAuthenticationOptions,
  verifyAuthenticationResponse
} from '@simplewebauthn/server';
import pool from '../config/db';
import { logger } from '../utils/logger';

interface PendingChallenge {
  challenge: string;
  userId?: number;
  expiresAt: number;
}

export class WebAuthnService {
  public static getRpId(originHeader?: string, hostHeader?: string): string {
    if (process.env.RP_ID) {
      return process.env.RP_ID;
    }
    if (process.env.RP_ORIGIN) {
      try {
        return new URL(process.env.RP_ORIGIN).hostname;
      } catch (_) {}
    }
    if (process.env.RENDER_EXTERNAL_URL) {
      try {
        return new URL(process.env.RENDER_EXTERNAL_URL).hostname;
      } catch (_) {}
    }
    if (process.env.APP_URL) {
      try {
        return new URL(process.env.APP_URL).hostname;
      } catch (_) {}
    }
    if (originHeader) {
      try {
        const parsed = new URL(originHeader);
        return parsed.hostname;
      } catch (_) {}
    }
    if (hostHeader) {
      return hostHeader.split(':')[0];
    }
    return 'localhost';
  }

  public static getExpectedOrigin(originHeader?: string, hostHeader?: string): string {
    if (process.env.RP_ORIGIN) {
      return process.env.RP_ORIGIN.replace(/\/$/, '');
    }
    if (process.env.RENDER_EXTERNAL_URL) {
      return process.env.RENDER_EXTERNAL_URL.replace(/\/$/, '');
    }
    if (process.env.APP_URL) {
      return process.env.APP_URL.replace(/\/$/, '');
    }
    const isProduction = ['production', 'staging'].includes((process.env.NODE_ENV || 'development').toLowerCase());
    if (process.env.ALLOWED_ORIGINS) {
      const allowed = process.env.ALLOWED_ORIGINS.split(',').map(s => s.trim().replace(/\/$/, ''));
      if (originHeader && allowed.includes(originHeader.replace(/\/$/, ''))) {
        return originHeader.replace(/\/$/, '');
      }
      if (allowed.length > 0 && allowed[0] !== '*') {
        return allowed[0];
      }
    }
    if (originHeader && (originHeader.startsWith('http://') || originHeader.startsWith('https://'))) {
      try {
        const parsed = new URL(originHeader);
        if (!isProduction) {
          return originHeader.replace(/\/$/, '');
        }
        if (parsed.hostname.endsWith('.onrender.com') || (hostHeader && parsed.host === hostHeader)) {
          return originHeader.replace(/\/$/, '');
        }
      } catch (_) {}
    }
    if (hostHeader && !isProduction) {
      return `https://${hostHeader}`;
    }
    if (!isProduction) {
      return 'http://localhost:3000';
    }
    throw new Error('Configuração de segurança RP_ORIGIN ou ALLOWED_ORIGINS obrigatória em ambiente de produção.');
  }

  public static async saveChallenge(key: string, challenge: string, userId?: number): Promise<void> {
    const expiresAt = Date.now() + 5 * 60 * 1000;
    try {
      await pool.query(
        `INSERT INTO webauthn_challenges (key, challenge, user_id, expires_at, criado_em)
         VALUES ($1, $2, $3, $4, NOW())
         ON CONFLICT (key) DO UPDATE SET challenge = $2, user_id = $3, expires_at = $4, criado_em = NOW()`,
        [key, challenge, userId || null, expiresAt]
      );
      const cleanup = pool.query('DELETE FROM webauthn_challenges WHERE expires_at < $1', [Date.now()]);
      if (cleanup && typeof cleanup.catch === 'function') {
        cleanup.catch(() => {});
      }
    } catch (error) {
      logger.error('[WebAuthnService.saveChallenge] Erro ao salvar challenge no banco:', { key, error });
      throw error;
    }
  }

  public static async getChallenge(key: string): Promise<PendingChallenge | null> {
    try {
      const res = await pool.query(
        'SELECT challenge, user_id, expires_at FROM webauthn_challenges WHERE key = $1',
        [key]
      );
      if (res.rowCount === 0) return null;
      const row = res.rows[0];
      const expiresAt = Number(row.expires_at);
      if (Date.now() > expiresAt) {
        await this.removeChallenge(key);
        return null;
      }
      return {
        challenge: row.challenge,
        userId: row.user_id ? Number(row.user_id) : undefined,
        expiresAt
      };
    } catch (error) {
      logger.error('[WebAuthnService.getChallenge] Erro ao buscar challenge:', { key, error });
      return null;
    }
  }

  public static async removeChallenge(key: string): Promise<void> {
    try {
      await pool.query('DELETE FROM webauthn_challenges WHERE key = $1', [key]);
    } catch (error) {
      logger.error('[WebAuthnService.removeChallenge] Erro ao remover challenge:', { key, error });
    }
  }

  public static async generateRegisterOptions(user: { id: number; email: string; nome: string }, rpId: string) {
    const userPasskeys = await this.listUserPasskeys(user.id);
    const excludeCredentials = userPasskeys.map(pk => ({
      id: pk.credential_id,
      transports: pk.transports as any
    }));

    const options = await generateRegistrationOptions({
      rpName: 'SeatMap Corporativo',
      rpID: rpId,
      userID: new TextEncoder().encode(user.id.toString()),
      userName: user.email,
      userDisplayName: user.nome,
      attestationType: 'none',
      excludeCredentials,
      authenticatorSelection: {
        residentKey: 'required',
        userVerification: 'required',
        authenticatorAttachment: 'platform'
      }
    });

    await this.saveChallenge(`reg_${user.id}`, options.challenge, user.id);
    return options;
  }

  public static async verifyRegister(
    userId: number,
    responseBody: any,
    expectedOrigin: string,
    expectedRpId: string,
    deviceName: string = 'Dispositivo Móvel'
  ) {
    const pending = await this.getChallenge(`reg_${userId}`);
    if (!pending) {
      throw new Error('Desafio biométrico expirado ou inexistente. Tente novamente.');
    }

    const verification = await verifyRegistrationResponse({
      response: responseBody,
      expectedChallenge: pending.challenge,
      expectedOrigin,
      expectedRPID: expectedRpId,
      requireUserVerification: true
    });

    if (!verification.verified || !verification.registrationInfo) {
      throw new Error('Falha na validação biométrica do dispositivo.');
    }

    await this.removeChallenge(`reg_${userId}`);

    const info = verification.registrationInfo as any;
    const credentialId = info.credential?.id || info.credentialID || responseBody.id;
    const rawPublicKey = info.credentialPublicKey || info.credential?.publicKey;
    const publicKeyBase64 = Buffer.from(rawPublicKey).toString('base64');
    const counter = info.counter || 0;

    await pool.query(
      `INSERT INTO usuarios_biometria_passkeys (usuario_id, credential_id, public_key, counter, transports, nome_dispositivo, criado_em, ultimo_uso)
       VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
       ON CONFLICT (credential_id) DO UPDATE SET public_key = $3, counter = $4, ultimo_uso = NOW()`,
      [userId, credentialId, publicKeyBase64, counter, responseBody.response?.transports || [], deviceName]
    );

    return { verified: true, credentialId };
  }

  public static async generateAuthOptions(rpId: string, userEmailOrMatricula?: string) {
    let allowCredentials: any[] | undefined = undefined;

    if (userEmailOrMatricula) {
      const userRes = await pool.query(
        'SELECT id FROM usuarios WHERE LOWER(email) = LOWER($1) OR LOWER(matricula) = LOWER($1)',
        [userEmailOrMatricula.trim()]
      );
      if (userRes.rowCount && userRes.rows[0]) {
        const passkeys = await this.listUserPasskeys(userRes.rows[0].id);
        if (passkeys.length > 0) {
          allowCredentials = passkeys.map(pk => ({
            id: pk.credential_id,
            transports: pk.transports as any
          }));
        }
      }
    }

    const options = await generateAuthenticationOptions({
      rpID: rpId,
      userVerification: 'required',
      allowCredentials
    });

    const sessionKey = `auth_${options.challenge}`;
    await this.saveChallenge(sessionKey, options.challenge);

    return { options, challengeKey: sessionKey };
  }

  public static async verifyAuth(
    challengeKey: string,
    responseBody: any,
    expectedOrigin: string,
    expectedRpId: string
  ) {
    const pending = await this.getChallenge(challengeKey);
    if (!pending) {
      throw new Error('Desafio biométrico expirado. Tente novamente.');
    }

    const credentialId = responseBody.id;
    const passkeyRes = await pool.query(
      'SELECT * FROM usuarios_biometria_passkeys WHERE credential_id = $1',
      [credentialId]
    );

    if (passkeyRes.rowCount === 0) {
      throw new Error('Dispositivo biométrico não cadastrado para esta conta.');
    }

    const passkey = passkeyRes.rows[0];
    const publicKeyBuffer = Buffer.from(passkey.public_key, 'base64');

    const verification = await verifyAuthenticationResponse({
      response: responseBody,
      expectedChallenge: pending.challenge,
      expectedOrigin,
      expectedRPID: expectedRpId,
      credential: {
        id: passkey.credential_id,
        publicKey: publicKeyBuffer,
        counter: Number(passkey.counter),
        transports: passkey.transports
      },
      requireUserVerification: true
    });

    if (!verification.verified) {
      throw new Error('Assinatura biométrica inválida.');
    }

    await this.removeChallenge(challengeKey);

    const newCounter = verification.authenticationInfo.newCounter;
    await pool.query(
      'UPDATE usuarios_biometria_passkeys SET counter = $1, ultimo_uso = NOW() WHERE id = $2',
      [newCounter, passkey.id]
    );

    const userRes = await pool.query(
      `SELECT u.id, u.nome, u.email, u.matricula, u.perfil,
              COALESCE(u.permissao_rh, false) AS permissao_rh,
              COALESCE(u.permissao_ti, false) AS permissao_ti,
              COALESCE(u.token_version, 1) AS token_version,
              u.ativo, u.departamento_id, d.nome AS departamento_nome
       FROM usuarios u
       LEFT JOIN departamentos d ON u.departamento_id = d.id
       WHERE u.id = $1`,
      [passkey.usuario_id]
    );

    if (userRes.rowCount === 0 || !userRes.rows[0].ativo) {
      throw new Error('Usuário inativo ou não encontrado.');
    }

    return {
      verified: true,
      user: userRes.rows[0]
    };
  }

  public static async listUserPasskeys(userId: number) {
    const res = await pool.query(
      'SELECT id, credential_id, counter, transports, nome_dispositivo, criado_em, ultimo_uso FROM usuarios_biometria_passkeys WHERE usuario_id = $1 ORDER BY criado_em DESC',
      [userId]
    );
    return res.rows;
  }

  public static async deleteUserPasskey(userId: number, passkeyId: number) {
    const res = await pool.query(
      'DELETE FROM usuarios_biometria_passkeys WHERE id = $1 AND usuario_id = $2 RETURNING id',
      [passkeyId, userId]
    );
    return res.rowCount !== 0;
  }
}

