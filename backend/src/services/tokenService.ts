import crypto from 'crypto';
import { DateTime } from 'luxon';
import jwt from 'jsonwebtoken';
import pool from '../config/db';
import { AuditService } from './auditService';
import { env } from '../config/env';
import { toUserResponseDto } from '../utils/userDtoMapper';

const JWT_SECRET = env.JWT_SECRET;
const JWT_EXPIRATION = env.JWT_EXPIRATION;
const REFRESH_TOKEN_DAYS = 30;

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
   * Gera e persiste um novo Refresh Token com validade de 30 dias
   */
  public static async gerarRefreshToken(
    usuarioId: number,
    ip: string,
    userAgent: string,
    familyId?: string
  ): Promise<string> {
    const rawRefreshToken = crypto.randomBytes(40).toString('hex');
    const tokenHash = this.hashToken(rawRefreshToken);
    const famId = familyId || crypto.randomUUID();
    const expiraEm = DateTime.now().setZone('America/Sao_Paulo').plus({ days: REFRESH_TOKEN_DAYS }).toJSDate();

    await pool.query(`
      INSERT INTO auth_refresh_tokens (
        usuario_id, token_hash, family_id, expira_em, ip, user_agent, revogado, criado_em
      ) VALUES ($1, $2, $3, $4, $5, $6, false, NOW())
    `, [usuarioId, tokenHash, famId, expiraEm, ip, userAgent]);

    return rawRefreshToken;
  }

  /**
   * Rotaciona um Refresh Token emitindo um novo par de Access Token e Refresh Token.
   * Implementa detecção e bloqueio de Replay Attacks (reuso de token já rotacionado).
   */
  public static async rotacionarRefreshToken(
    rawRefreshToken: string,
    ip: string,
    userAgent: string
  ): Promise<TokenPairResult> {
    if (!rawRefreshToken || typeof rawRefreshToken !== 'string') {
      return { success: false, error: 'Refresh token não fornecido.' };
    }

    const tokenHash = this.hashToken(rawRefreshToken.trim());

    try {
      const tokenRes = await pool.query(`
        SELECT id, usuario_id, family_id, revogado, expira_em
        FROM auth_refresh_tokens
        WHERE token_hash = $1
      `, [tokenHash]);

      if (tokenRes.rowCount === 0) {
        return { success: false, error: 'Refresh token inválido ou não encontrado.' };
      }

      const tokenRecord = tokenRes.rows[0];

      // 1. Detecção de Ataque de Repetição (Token Replay)
      if (tokenRecord.revogado) {
        console.warn(`[TokenService] Tentativa de reuso de Refresh Token detectada! Revogando família ${tokenRecord.family_id}`);
        await pool.query(`
          UPDATE auth_refresh_tokens
          SET revogado = true
          WHERE family_id = $1
        `, [tokenRecord.family_id]);

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

      // 2. Validação de Expiração
      if (new Date(tokenRecord.expira_em) < new Date()) {
        return { success: false, error: 'Refresh token expirado. Faça login novamente.' };
      }

      // 3. Buscar dados atualizados do usuário
      const userRes = await pool.query(`
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
        return { success: false, error: 'Usuário inativo ou inexistente.' };
      }

      const user = userRes.rows[0];

      // 4. Revogar o token atual
      await pool.query(`
        UPDATE auth_refresh_tokens
        SET revogado = true
        WHERE id = $1
      `, [tokenRecord.id]);

      // 5. Emitir novo Refresh Token na mesma família (Rotação)
      const novoRefreshToken = await this.gerarRefreshToken(
        user.id,
        ip,
        userAgent,
        tokenRecord.family_id
      );

      // 6. Emitir novo Access Token JWT
      const novoAccessToken = jwt.sign(
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
          tokenVersion: user.token_version || 1
        },
        JWT_SECRET,
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
        refreshToken: novoRefreshToken,
        user: toUserResponseDto(user)
      };
    } catch (error) {
      console.error('[TokenService.rotacionarRefreshToken Error]:', error);
      return { success: false, error: 'Erro interno ao renovar sessão.' };
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
      console.error('[TokenService.revogarToken Error]:', e);
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
      console.error('[TokenService.revogarPorUsuario Error]:', e);
    }
  }

  /**
   * Incrementa o token_version do usuário no banco e revoga todas as suas sessões ativas.
   * Usado em: Desativação de Usuário (TI/RH/SCIM), Mudança de Perfil, Reset de Senha e Logout Global.
   */
  public static async incrementarTokenVersion(usuarioId: number): Promise<number> {
    try {
      const res = await pool.query(`
        UPDATE usuarios
        SET token_version = COALESCE(token_version, 1) + 1
        WHERE id = $1
        RETURNING token_version
      `, [usuarioId]);

      await this.revogarPorUsuario(usuarioId);

      return res.rows[0]?.token_version || 1;
    } catch (err) {
      console.error('[TokenService.incrementarTokenVersion Error]:', err);
      return 1;
    }
  }
}
