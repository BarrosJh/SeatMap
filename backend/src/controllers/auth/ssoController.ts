import { Request, Response } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import pool from '../../config/db';
import { ConfigService } from '../../services/configService';
import { AuditService } from '../../services/auditService';
import { SsoService } from '../../services/ssoService';
import { TokenService } from '../../services/tokenService';
import { logger } from '../../utils/logger';
import { env } from '../../config/env';
import { toUserResponseDto } from '../../utils/userDtoMapper';
import { BCRYPT_SALT_ROUNDS } from '../../config/securityConstants';
import { JwtCryptoUtils } from '../../config/jwtCryptoUtils';

const JWT_EXPIRATION = env.JWT_EXPIRATION;

export class SsoController {
  public static async getSsoConfig(req: Request, res: Response) {
    try {
      const config = await SsoService.getActiveProviders();
      return res.status(200).json(config);
    } catch (error) {
      logger.error('[SsoController.getSsoConfig] Erro:', { correlationId: (req as any).correlationId, error });
      return res.status(500).json({ error: 'Erro ao buscar configurações de SSO.' });
    }
  }

  public static async loginSso(req: Request, res: Response) {
    const { provider, idToken, email: rawEmail, name: rawName, ssoId: rawSsoId } = req.body;
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

    if (!provider) {
      AuditService.log({
        loginInformado: rawEmail || 'desconhecido',
        tipoEvento: 'SSO_FALHA',
        sucesso: false,
        ip,
        userAgent,
        detalhes: { motivo: 'Provedor SSO não informado' }
      });
      return res.status(400).json({ error: 'Provedor SSO é obrigatório.' });
    }

    let email = rawEmail;
    let name = rawName;
    let ssoId = rawSsoId;

    // SEC-01: Validação criptográfica obrigatória do idToken via JWKS
    if (idToken) {
      try {
        const verified = await SsoService.verifyIdToken(provider, idToken);
        email = verified.email;
        if (verified.name) name = verified.name;
        if (verified.ssoId) ssoId = verified.ssoId;
      } catch (err: any) {
        logger.error('[SsoController.loginSso] Falha na validação do idToken:', { correlationId: (req as any).correlationId, error: err });
        AuditService.log({
          loginInformado: rawEmail || 'token_invalido',
          tipoEvento: 'SSO_FALHA',
          sucesso: false,
          ip,
          userAgent,
          detalhes: { motivo: 'Falha na validação de assinatura do idToken', erro: err.message }
        });
        return res.status(401).json({ error: 'Falha na validação do token de autenticação SSO.' });
      }
    } else {
      AuditService.log({
        loginInformado: rawEmail || 'sem_token',
        tipoEvento: 'SSO_FALHA',
        sucesso: false,
        ip,
        userAgent,
        detalhes: { motivo: 'Tentativa de login SSO sem idToken assinado' }
      });
      return res.status(401).json({ error: 'O idToken assinado pelo provedor de identidade é obrigatório para autenticação SSO.' });
    }

    if (!email || typeof email !== 'string') {
      return res.status(400).json({ error: 'E-mail corporativo não identificado no fluxo SSO.' });
    }

    try {
      const ssoEnabledStr = await ConfigService.get('SSO_ENABLED', 'false');
      if (ssoEnabledStr !== 'true') {
        return res.status(403).json({ error: 'Autenticação Single Sign-On (SSO) desativada pelo administrador de TI.' });
      }

      // Validar se o domínio é autorizado
      const isAllowed = await SsoService.isEmailDomainAllowed(email);
      if (!isAllowed) {
        AuditService.log({
          loginInformado: email,
          tipoEvento: 'SSO_DOMINIO_BLOQUEADO',
          sucesso: false,
          ip,
          userAgent,
          detalhes: { provider, email }
        });
        return res.status(403).json({ error: 'O domínio do seu e-mail corporativo não está autorizado para login SSO neste sistema.' });
      }

      // Buscar usuário pelo e-mail
      let userRes = await pool.query(`
        SELECT u.id, u.nome, u.email, u.matricula, u.perfil, 
               COALESCE(u.permissao_rh, false) AS permissao_rh,
               COALESCE(u.permissao_ti, false) AS permissao_ti,
               COALESCE(u.token_version, 1) AS token_version,
               u.ativo,
               COALESCE(u.totp_ativo, false) AS totp_ativo,
               u.departamento_id, d.nome AS departamento_nome
        FROM usuarios u
        LEFT JOIN departamentos d ON u.departamento_id = d.id
        WHERE LOWER(u.email) = LOWER($1)
      `, [email.trim()]);

      // Se não existir, verificar se o auto-provisionamento JIT está ativo
      if (userRes.rowCount === 0) {
        const autoProvision = (await ConfigService.get('SSO_AUTO_PROVISION', 'true')) === 'true';
        if (!autoProvision) {
          AuditService.log({
            loginInformado: email,
            tipoEvento: 'SSO_PROVISIONAMENTO_DESATIVADO',
            sucesso: false,
            ip,
            userAgent,
            detalhes: { provider, email }
          });
          return res.status(403).json({ error: 'Conta corporativa não localizada e o auto-provisionamento JIT está desativado. Solicite cadastro ao RH.' });
        }

        const defaultRole = await ConfigService.get('SSO_DEFAULT_ROLE', 'COLABORADOR');
        const userName = (name && String(name).trim().length > 0) ? String(name).trim() : email.split('@')[0];
        const generatedMatricula = `SSO-${Date.now().toString().slice(-6)}`;
        const randomHash = await bcrypt.hash(crypto.randomBytes(32).toString('hex'), BCRYPT_SALT_ROUNDS);

        const insertRes = await pool.query(`
          INSERT INTO usuarios (nome, email, matricula, senha_hash, perfil, ativo, token_version, sso_provider, sso_id, ultimo_login)
          VALUES ($1, $2, $3, $4, $5, true, 1, $6, $7, NOW())
          RETURNING id, nome, email, matricula, perfil, permissao_rh, permissao_ti, departamento_id, token_version
        `, [userName, email.trim().toLowerCase(), generatedMatricula, randomHash, defaultRole, provider, ssoId || null]);

        userRes = {
          rowCount: 1,
          rows: [{
            ...insertRes.rows[0],
            departamento_nome: null,
            totp_ativo: false,
            ativo: true,
            token_version: 1
          }]
        } as any;

        AuditService.log({
          usuarioId: insertRes.rows[0].id,
          loginInformado: email,
          tipoEvento: 'SSO_USUARIO_PROVISIONADO',
          sucesso: true,
          ip,
          userAgent,
          detalhes: { provider, matricula: generatedMatricula, perfil: defaultRole }
        });
      }

      const user = userRes.rows[0];

      if (!user.ativo) {
        AuditService.log({
          usuarioId: user.id,
          loginInformado: email,
          tipoEvento: 'LOGIN_USUARIO_INATIVO',
          sucesso: false,
          ip,
          userAgent,
          detalhes: { provider, motivo: 'Conta inativa no sistema' }
        });
        return res.status(401).json({ error: 'Usuário inativo no sistema. Entre em contato com o RH.' });
      }

      // Atualizar último login e vínculo SSO
      await pool.query(
        'UPDATE usuarios SET ultimo_login = NOW(), sso_provider = $1, sso_id = COALESCE($2, sso_id), tentativas_login_falhas = 0, bloqueado_ate = NULL WHERE id = $3',
        [provider, ssoId || null, user.id]
      );

      // Hardening de Sessão: Invalidação de sessões ativas anteriores (Single Active Session Enforcement)
      await TokenService.incrementarTokenVersion(user.id, { ip, userAgent });
      const activeTokenVersion = (user.token_version || 1) + 1;
      const authTime = Math.floor(Date.now() / 1000);

      // Emitir token JWT definitivo
      const token = JwtCryptoUtils.signToken({
        userId: user.id,
        nome: user.nome,
        email: user.email,
        matricula: user.matricula,
        perfil: user.perfil,
        permissaoRh: user.permissao_rh === true || user.perfil === 'ADMIN_RH',
        permissaoTi: user.permissao_ti === true || user.perfil === 'ADMIN_TI',
        departamentoId: user.departamento_id,
        departamentoNome: user.departamento_nome,
        tokenVersion: activeTokenVersion,
        authTime
      }, { expiresIn: JWT_EXPIRATION as any });

      AuditService.log({
        usuarioId: user.id,
        loginInformado: email,
        tipoEvento: 'SSO_LOGIN_SUCESSO',
        sucesso: true,
        ip,
        userAgent,
        detalhes: { provider }
      });

      // Emissão de Refresh Token com rotação de segurança
      const refreshToken = await TokenService.gerarRefreshToken(user.id, ip, userAgent);

      return res.status(200).json({
        token,
        refreshToken,
        user: toUserResponseDto(user)
      });
    } catch (error) {
      logger.error('[SsoController.loginSso] Erro:', { correlationId: (req as any).correlationId, error });
      return res.status(500).json({ error: 'Erro ao processar autenticação Single Sign-On.' });
    }
  }
}
