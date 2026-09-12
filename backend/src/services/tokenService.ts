import crypto from 'crypto';
import { DateTime } from 'luxon';
import jwt from 'jsonwebtoken';
import pool from '../config/db';
import { getDbClient } from '../utils/dbClient';
import { AuditService } from './auditService';
import { env } from '../config/env';
import { toUserResponseDto } from '../utils/userDtoMapper';
import { logger } from '../utils/logger';
import { JwtCryptoUtils } from '../config/jwtCryptoUtils';

const JWT_EXPIRATION = env.JWT_EXPIRATION;
const REFRESH_TOKEN_DAYS = 7;
const MAX_ABSOLUTE_SESSION_SECONDS = 3600; // 60 minutos

export interface TokenPairResult {
  success: boolean;
  token?: string;
  refreshToken?: string;
  user?: any;
  error?: string;
}

export class TokenService {
  /**
   * Gera um hash criptográfico SHA-256 do token bruto
   */
  private static hashToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  /**
   * Gera e persiste um novo Refresh Token com validade de 7 dias
   */
  public static async gerarRefreshToken(
    usuarioId: number,
    ip: string,
    userAgent: string,
    familyId?: string
  ): Promise<string> {
    const rawRefreshToken = crypto.randomBytes(40).toString('hex');
    const tokenHash = this.hashToken(rawRefreshToken);
    const finalFamilyId = familyId || crypto.randomUUID();
    const expiraEm = DateTime.now().plus({ days: REFRESH_TOKEN_DAYS }).toJSDate();

    await pool.query(`
      INSERT INTO auth_refresh_tokens (usuario_id, token_hash, family_id, expira_em, ip, user_agent)
      VALUES ($1, $2, $3, $4, $5, $6)
    `, [usuarioId, tokenHash, finalFamilyId, expiraEm, ip, userAgent]);

    return rawRefreshToken;
  }

  /**
   * Valida o refresh token, detecta reuso (replay attack), aplica timeout de 60m e rotaciona
   */
  public static async rotacionarRefreshToken(
    rawRefreshToken: string,
    ip: string,
    userAgent: string
  ): Promise<TokenPairResult> {
    if (!rawRefreshToken) {
      return { success: false, error: 'Refresh token não fornecido.' };
    }

    const tokenHash = this.hashToken(rawRefreshToken.trim());

    const client = await getDbClient();
    try {
      await client.query('BEGIN');

      const tokenRes = await client.query(`
        SELECT id, usuario_id, family_id, revogado, expira_em, criado_em
        FROM auth_refresh_tokens
        WHERE token_hash = $1
        FOR UPDATE
      `, [tokenHash]);

      if (tokenRes.rowCount === 0) {
        await client.query('ROLLBACK');
        return { success: false, error: 'Refresh token inválido ou não encontrado.' };
      }

      const tokenRecord = tokenRes.rows[0];

      // 1. Detecção de Ataque de Repetição (Token Replay)
      if (tokenRecord.revogado) {
        logger.warn(`[TokenService] Tentativa de reuso de Refresh Token detectada! Revogando família ${tokenRecord.family_id}`, {
          familyId: tokenRecord.family_id,
          usuarioId: tokenRecord.usuario_id,
          ip
        });
        await client.query(`
          UPDATE auth_refresh_tokens
          SET revogado = true
          WHERE family_id = $1
        `, [tokenRecord.family_id]);

        await client.query('COMMIT');

        AuditService.log({
          usuarioId: tokenRecord.usuario_id,
          tipoEvento: 'REFRESH_TOKEN_REUSO_SUSPEITO',
          sucesso: false,
          ip,
          userAgent,
          detalhes: { familyId: tokenRecord.family_id, motivo: 'Tentativa de reuso de token já revogado' }
        });

        return {
          success: false,
          error: 'Sessão revogada por motivos de segurança devido a atividade suspeita. Por favor, faça login novamente.'
        };
      }

      // 2. Validação de Expiração do Refresh Token
      if (new Date(tokenRecord.expira_em) < new Date()) {
        await client.query('ROLLBACK');
        return { success: false, error: 'Refresh token expirado. Faça login novamente.' };
      }

      // 3. Timeout Absoluto Server-Side de 60 minutos (Baseado na criação da família de sessão)
      const familyFirstTokenRes = await client.query(`
        SELECT MIN(criado_em) AS session_start
        FROM auth_refresh_tokens
        WHERE family_id = $1
      `, [tokenRecord.family_id]);

      const sessionStart = familyFirstTokenRes.rows[0]?.session_start
        ? new Date(familyFirstTokenRes.rows[0].session_start).getTime()
        : new Date(tokenRecord.criado_em).getTime();

      const sessionAgeSeconds = Math.floor((Date.now() - sessionStart) / 1000);

      if (sessionAgeSeconds > MAX_ABSOLUTE_SESSION_SECONDS) {
        await client.query(`
          UPDATE auth_refresh_tokens
          SET revogado = true
          WHERE family_id = $1
        `, [tokenRecord.family_id]);

        await client.query('COMMIT');

        AuditService.log({
          usuarioId: tokenRecord.usuario_id,
          tipoEvento: 'LOGOUT',
          sucesso: false,
          ip,
          userAgent,
          detalhes: { familyId: tokenRecord.family_id, motivo: 'Timeout absoluto de sessão de 60 minutos atingido' }
        });

        return {
          success: false,
          error: 'Sessão expirada pelo limite máximo de tempo absoluto (60 minutos). Por favor, faça login novamente.'
        };
      }

      // 4. Buscar dados atualizados do usuário
      const userRes = await client.query(`
        SELECT u.id, u.nome, u.email, u.matricula, u.perfil,
               COALESCE(u.permissao_rh, false) AS permissao_rh,
               COALESCE(u.permissao_ti, false) AS permissao_ti,
               COALESCE(u.token_version, 1) AS token_version,
               u.ativo, u.departamento_id, d.nome AS departamento_nome
        FROM usuarios u
        LEFT JOIN departamentos d ON u.departamento_id = d.id
        WHERE u.id = $1
      `, [tokenRecord.usuario_id]);

      if (userRes.rowCount === 0 || !userRes.rows[0].ativo) {
        await client.query('ROLLBACK');
        return { success: false, error: 'Usuário inativo ou inexistente.' };
      }

      const user = userRes.rows[0];

      // 5. Revogar o refresh token atual
      await client.query(`
        UPDATE auth_refresh_tokens
        SET revogado = true
        WHERE id = $1
      `, [tokenRecord.id]);

      // 6. Emitir novo Refresh Token na mesma família (Rotação)
      const rawNewRefreshToken = crypto.randomBytes(40).toString('hex');
      const newTokenHash = this.hashToken(rawNewRefreshToken);
      const expiraEm = DateTime.now().plus({ days: REFRESH_TOKEN_DAYS }).toJSDate();

      await client.query(`
        INSERT INTO auth_refresh_tokens (usuario_id, token_hash, family_id, expira_em, ip, user_agent)
        VALUES ($1, $2, $3, $4, $5, $6)
      `, [user.id, newTokenHash, tokenRecord.family_id, expiraEm, ip, userAgent]);

      await client.query('COMMIT');

      const authTime = Math.floor(sessionStart / 1000);

      // 7. Emitir novo Access Token JWT com authTime persistido
      const novoAccessToken = JwtCryptoUtils.signToken(
        {
          userId: user.id,
          nome: user.nome,
          email: user.email,
          matricula: user.matricula,
          perfil: user.perfil,
          permissaoRh: user.permissao_rh,
          permissaoTi: user.permissao_ti,
          departamentoId: user.departamento_id,
          departamentoNome: user.departamento_nome,
          tokenVersion: user.token_version || 1,
          authTime
        },
        { expiresIn: JWT_EXPIRATION as any }
      );

      AuditService.log({
        usuarioId: user.id,
        tipoEvento: 'REFRESH_TOKEN_ROTACAO',
        sucesso: true,
        ip,
        userAgent,
        detalhes: { familyId: tokenRecord.family_id }
      });

      return {
        success: true,
        token: novoAccessToken,
        refreshToken: rawNewRefreshToken,
        user: toUserResponseDto(user)
      };
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {}
      logger.error('[TokenService.rotacionarRefreshToken Error]:', { error });
      return { success: false, error: 'Erro interno ao renovar sessão.' };
    } finally {
      client.release();
    }
  }

  /**
   * Revoga todos os tokens associados a um refresh token específico
   */
  public static async revogarToken(rawRefreshToken: string): Promise<void> {
    if (!rawRefreshToken) return;
    const tokenHash = this.hashToken(rawRefreshToken.trim());
    try {
      const res = await pool.query(`
        SELECT family_id FROM auth_refresh_tokens WHERE token_hash = $1
      `, [tokenHash]);
      if (res.rowCount && res.rows[0]?.family_id) {
        await pool.query(`
          UPDATE auth_refresh_tokens SET revogado = true WHERE family_id = $1
        `, [res.rows[0].family_id]);
      }
    } catch (e) {
      logger.error('[TokenService.revogarToken Error]:', { error: e });
    }
  }

  /**
   * Revoga todos os tokens ativos de um usuário (logout global)
   */
  public static async revogarPorUsuario(usuarioId: number): Promise<void> {
    try {
      await pool.query(`
        UPDATE auth_refresh_tokens SET revogado = true WHERE usuario_id = $1
      `, [usuarioId]);
    } catch (e) {
      logger.error('[TokenService.revogarPorUsuario Error]:', { error: e });
    }
  }

  /**
   * Incrementa o token_version do usuário no banco e revoga todas as suas sessões ativas.
   * Usado em: Desativação de Usuário (TI/RH/SCIM), Mudança de Perfil, Reset de Senha, Logout Global e Login Concorrente.
   */
  public static async incrementarTokenVersion(
    usuarioId: number,
    auditContext?: { ip?: string; userAgent?: string; motivo?: string }
  ): Promise<number> {
    try {
      // Verifica se o usuário possuía sessões/refresh tokens ativos antes de revogar
      const activeSessions = await pool.query(`
        SELECT COUNT(*)::int AS total
        FROM auth_refresh_tokens
        WHERE usuario_id = $1 AND revogado = false AND expira_em > NOW()
      `, [usuarioId]);

      const previousSessionsCount = activeSessions.rows[0]?.total || 0;

      const res = await pool.query(`
        UPDATE usuarios
        SET token_version = COALESCE(token_version, 1) + 1
        WHERE id = $1
        RETURNING token_version
      `, [usuarioId]);

      await this.revogarPorUsuario(usuarioId);

      if (previousSessionsCount > 0 && auditContext) {
        AuditService.log({
          usuarioId,
          tipoEvento: 'SESSAO_SIMULTANEA_REVOGADA',
          sucesso: true,
          ip: auditContext.ip,
          userAgent: auditContext.userAgent,
          detalhes: {
            sessoesRevogadas: previousSessionsCount,
            motivo: auditContext.motivo || 'Novo login realizado pelo mesmo usuário (Single Active Session Enforcement)'
          }
        });
      }

      return res.rows[0]?.token_version || 1;
    } catch (err) {
      logger.error('[TokenService.incrementarTokenVersion Error]:', { error: err });
      return 1;
    }
  }
}
