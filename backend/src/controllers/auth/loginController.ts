import { Request, Response } from 'express';
import crypto from 'crypto';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { DateTime } from 'luxon';
import pool from '../../config/db';
import { AuthenticatedRequest } from '../../middleware/auth';
import { ConfigService } from '../../services/configService';
import { EmailService } from '../../services/emailService';
import { AuditService } from '../../services/auditService';
import { SsoService } from '../../services/ssoService';
import { TokenService } from '../../services/tokenService';
import { logger } from '../../utils/logger';
import { env } from '../../config/env';
import { toUserResponseDto } from '../../utils/userDtoMapper';

const JWT_SECRET = env.JWT_SECRET;
const JWT_EXPIRATION = env.JWT_EXPIRATION;
const JWT_MFA_TEMP_SECRET = env.JWT_MFA_TEMP_SECRET;

export class LoginController {
  public static async login(req: Request, res: Response) {
    const { login, senha } = req.body;
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

    if (!login || !senha) {
      AuditService.log({
        loginInformado: login,
        tipoEvento: 'LOGIN_FALHA_SENHA',
        sucesso: false,
        ip,
        userAgent,
        detalhes: { motivo: 'Campos obrigatórios não informados' }
      });
      return res.status(400).json({ error: 'Matrícula/E-mail e senha são obrigatórios.' });
    }

    try {
      const userRes = await pool.query(`
        SELECT u.id, u.nome, u.email, u.matricula, u.senha_hash, u.perfil, 
               COALESCE(u.permissao_rh, false) AS permissao_rh,
               COALESCE(u.permissao_ti, false) AS permissao_ti,
               COALESCE(u.exigir_mfa, false) AS exigir_mfa,
               COALESCE(u.token_version, 1) AS token_version,
               u.ativo, u.tentativas_login_falhas, u.bloqueado_ate,
               COALESCE(u.totp_ativo, false) AS totp_ativo,
               u.totp_secret,
               u.departamento_id, d.nome AS departamento_nome
        FROM usuarios u
        LEFT JOIN departamentos d ON u.departamento_id = d.id
        WHERE (LOWER(u.email) = LOWER($1) OR LOWER(u.matricula) = LOWER($1))
      `, [login.trim()]);

      if (userRes.rowCount === 0) {
        AuditService.log({
          loginInformado: login,
          tipoEvento: 'LOGIN_USUARIO_NAO_ENCONTRADO',
          sucesso: false,
          ip,
          userAgent,
          detalhes: { motivo: 'Usuário não localizado no banco' }
        });
        return res.status(401).json({ error: 'Credenciais inválidas.' });
      }

      const user = userRes.rows[0];

      if (!user.ativo) {
        AuditService.log({
          usuarioId: user.id,
          loginInformado: login,
          tipoEvento: 'LOGIN_USUARIO_INATIVO',
          sucesso: false,
          ip,
          userAgent,
          detalhes: { motivo: 'Conta inativa no sistema' }
        });
        return res.status(401).json({ error: 'Usuário inativo. Entre em contato com o RH.' });
      }

      // Checar se a conta está temporariamente bloqueada por força bruta
      if (user.bloqueado_ate) {
        const bloqueioData = new Date(user.bloqueado_ate);
        const agora = new Date();
        if (bloqueioData > agora) {
          const minutosRestantes = Math.ceil((bloqueioData.getTime() - agora.getTime()) / (60 * 1000));
          AuditService.log({
            usuarioId: user.id,
            loginInformado: login,
            tipoEvento: 'LOGIN_CONTA_BLOQUEADA',
            sucesso: false,
            ip,
            userAgent,
            detalhes: { motivo: `Conta bloqueada até ${user.bloqueado_ate} (${minutosRestantes} min restantes)` }
          });
          return res.status(403).json({
            error: `Conta temporariamente bloqueada por segurança devido a tentativas falhas. Tente novamente em ${minutosRestantes} minuto(s).`
          });
        }
      }

      const match = await bcrypt.compare(senha, user.senha_hash);

      if (!match) {
        const novasFalhas = (user.tentativas_login_falhas || 0) + 1;
        let bloqueadoAte: Date | null = null;
        let msgErro = 'Credenciais inválidas.';

        if (novasFalhas >= 5) {
          bloqueadoAte = new Date(Date.now() + 15 * 60 * 1000); // 15 min de bloqueio
          await pool.query(
            'UPDATE usuarios SET tentativas_login_falhas = $1, bloqueado_ate = $2 WHERE id = $3',
            [novasFalhas, bloqueadoAte, user.id]
          );
          msgErro = 'Limite de 5 tentativas excedido. Sua conta foi temporariamente bloqueada por 15 minutos.';
          AuditService.log({
            usuarioId: user.id,
            loginInformado: login,
            tipoEvento: 'LOGIN_CONTA_BLOQUEADA',
            sucesso: false,
            ip,
            userAgent,
            detalhes: { tentativas: novasFalhas, bloqueadoPorMinutos: 15 }
          });
        } else {
          await pool.query(
            'UPDATE usuarios SET tentativas_login_falhas = $1 WHERE id = $2',
            [novasFalhas, user.id]
          );
          const restantes = 5 - novasFalhas;
          msgErro = `Credenciais inválidas. Você possui mais ${restantes} tentativa(s) antes do bloqueio temporário.`;
          AuditService.log({
            usuarioId: user.id,
            loginInformado: login,
            tipoEvento: 'LOGIN_FALHA_SENHA',
            sucesso: false,
            ip,
            userAgent,
            detalhes: { tentativas: novasFalhas }
          });
        }

        return res.status(401).json({ error: msgErro });
      }

      // Senha correta: resetar tentativas falhas, atualizar último login e desbloquear
      await pool.query(
        'UPDATE usuarios SET tentativas_login_falhas = 0, bloqueado_ate = NULL, ultimo_login = NOW() WHERE id = $1',
        [user.id]
      );

      // Checar política de Forçar SSO (SSO Enforcement) para domínios corporativos
      const ssoEnabled = (await ConfigService.get('SSO_ENABLED', 'false')) === 'true';
      const enforceSso = (await ConfigService.get('SSO_ENFORCE_FOR_DOMAINS', 'false')) === 'true';
      if (ssoEnabled && enforceSso && user.perfil !== 'ADMIN_TI') {
        const isDomainAllowed = await SsoService.isEmailDomainAllowed(user.email);
        if (isDomainAllowed) {
          AuditService.log({
            usuarioId: user.id,
            loginInformado: login,
            tipoEvento: 'LOGIN_SSO_EXIGIDO',
            sucesso: false,
            ip,
            userAgent,
            detalhes: { motivo: 'Política de SSO Enforcement ativa' }
          });
          return res.status(403).json({
            error: 'Sua conta corporativa exige autenticação via Single Sign-On (Microsoft 365 / Entra ID). Utilize o botão de login SSO.'
          });
        }
      }

      // Avaliação de Exigência e Políticas de MFA (2FA)
      const mfaPolicy = await ConfigService.get('MFA_POLICY', 'OBRIGATORIO_RH');
      const mfaTotpEnabled = (await ConfigService.get('MFA_TOTP_ENABLED', 'true')) === 'true';
      const mfaEmailEnabled = (await ConfigService.get('MFA_EMAIL_ENABLED', 'true')) === 'true';
      const mfaExpiracaoMinutos = await ConfigService.getNumber('MFA_EXPIRACAO_MINUTOS', 10);

      const isRhOrTech = user.permissao_rh || user.permissao_ti || user.perfil === 'ADMIN_RH' || user.perfil === 'ADMIN_TI' || user.perfil === 'GESTAO';

      const isMfaRequired = mfaPolicy === 'OBRIGATORIO_TODOS' ||
                            (mfaPolicy === 'OBRIGATORIO_RH' && isRhOrTech) ||
                            user.exigir_mfa === true ||
                            (user.totp_ativo && mfaTotpEnabled);

      if (isMfaRequired && mfaPolicy !== 'DESATIVADO') {
        // 1. Prioridade A: TOTP (App Authenticator) se ativo para o usuário e habilitado globalmente
        if (user.totp_ativo && user.totp_secret && mfaTotpEnabled) {
          const tempToken = jwt.sign({
            userId: user.id,
            tipo: 'TOTP_CHALLENGE'
          }, JWT_MFA_TEMP_SECRET, { expiresIn: '5m' });

          AuditService.log({
            usuarioId: user.id,
            loginInformado: login,
            tipoEvento: 'TOTP_SOLICITADO',
            sucesso: true,
            ip,
            userAgent,
            detalhes: { mfaMetodo: 'TOTP_AUTHENTICATOR' }
          });

          return res.status(200).json({
            requiresMfa: true,
            mfaType: 'TOTP',
            tempToken,
            message: 'Insira o código de 6 dígitos do seu aplicativo autenticador.'
          });
        }

        // 2. Prioridade B: Código via E-mail Corporativo (PIN de 6 dígitos) se habilitado globalmente
        if (mfaEmailEnabled) {
          const codigoPin = crypto.randomInt(100000, 1000000).toString();
          const expiraEm = DateTime.now().plus({ minutes: mfaExpiracaoMinutos }).toJSDate();

          // Invalidar códigos anteriores não utilizados
          await pool.query(`
            UPDATE auth_mfa_codes
            SET utilizado = true
            WHERE usuario_id = $1 AND utilizado = false
          `, [user.id]);

          await pool.query(`
            INSERT INTO auth_mfa_codes (usuario_id, codigo, expira_em, utilizado)
            VALUES ($1, $2, $3, false)
          `, [user.id, codigoPin, expiraEm]);

          // Enviar código por e-mail em background
          EmailService.enviarCodigoMfa(user.email, user.nome, codigoPin, mfaExpiracaoMinutos).catch(err => {
            logger.error('[LoginController.login] Erro ao enviar e-mail com código MFA:', { correlationId: req.correlationId, error: err });
          });

          const tempToken = jwt.sign({
            userId: user.id,
            tipo: 'EMAIL_MFA_CHALLENGE'
          }, JWT_MFA_TEMP_SECRET, { expiresIn: `${mfaExpiracaoMinutos}m` });

          const partesEmail = user.email.split('@');
          const nomeEmail = partesEmail[0];
          const dominioEmail = partesEmail[1] || '';
          const emailMascarado = (nomeEmail.length > 2)
            ? `${nomeEmail[0]}***${nomeEmail[nomeEmail.length - 1]}@${dominioEmail}`
            : `${nomeEmail[0]}***@${dominioEmail}`;

          AuditService.log({
            usuarioId: user.id,
            loginInformado: login,
            tipoEvento: 'MFA_SOLICITADO_EMAIL',
            sucesso: true,
            ip,
            userAgent,
            detalhes: { mfaMetodo: 'EMAIL_SMTP', emailMascarado }
          });

          return res.status(200).json({
            requiresMfa: true,
            mfaType: 'EMAIL',
            tempToken,
            emailMascarado,
            expiraEmMinutos: mfaExpiracaoMinutos,
            codigoSimulado: process.env.NODE_ENV !== 'production' ? codigoPin : undefined,
            message: `Código de verificação enviado para ${emailMascarado}. Insira o código de 6 dígitos para continuar.`
          });
        }
      }

      // Hardening de Sessão: Invalidação de sessões ativas anteriores (Single Active Session Enforcement)
      await TokenService.incrementarTokenVersion(user.id);
      const activeTokenVersion = (user.token_version || 1) + 1;
      const authTime = Math.floor(Date.now() / 1000);

      // Emissão do Token de Sessão JWT
      const token = jwt.sign({
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
      }, JWT_SECRET, { expiresIn: JWT_EXPIRATION as any });

      // Auditoria de Sucesso
      AuditService.log({
        usuarioId: user.id,
        loginInformado: login,
        tipoEvento: 'LOGIN_SUCESSO',
        sucesso: true,
        ip,
        userAgent,
        detalhes: { perfil: user.perfil }
      });

      // Emissão de Refresh Token com rotação de segurança
      const refreshToken = await TokenService.gerarRefreshToken(user.id, ip, userAgent);

      return res.status(200).json({
        token,
        refreshToken,
        user: toUserResponseDto(user)
      });
    } catch (error) {
      logger.error('[LoginController.login] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro interno ao realizar login.' });
    }
  }

  public static async refreshToken(req: Request, res: Response) {
    const { refreshToken } = req.body;
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

    if (!refreshToken) {
      return res.status(400).json({ error: 'Refresh token é obrigatório.' });
    }

    try {
      const result = await TokenService.rotacionarRefreshToken(refreshToken, ip, userAgent);

      if (!result.success) {
        return res.status(401).json({ error: result.error || 'Falha ao renovar sessão.' });
      }

      return res.status(200).json({
        token: result.token,
        refreshToken: result.refreshToken,
        user: result.user
      });
    } catch (error) {
      logger.error('[LoginController.refreshToken] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro interno ao renovar sessão.' });
    }
  }

  public static async logout(req: Request, res: Response) {
    const { refreshToken } = req.body || {};
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

    if (refreshToken) {
      await TokenService.revogarToken(refreshToken);
    }

    const authReq = req as AuthenticatedRequest;
    if (authReq.user) {
      AuditService.log({
        usuarioId: authReq.user.userId,
        tipoEvento: 'LOGOUT',
        sucesso: true,
        ip,
        userAgent
      });
    }

    return res.status(200).json({ message: 'Sessão finalizada com sucesso.' });
  }

  public static async logoutGlobal(req: AuthenticatedRequest, res: Response) {
    const user = req.user;
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

    if (!user) {
      return res.status(401).json({ error: 'Não autenticado.' });
    }

    try {
      await TokenService.incrementarTokenVersion(user.userId);

      AuditService.log({
        usuarioId: user.userId,
        tipoEvento: 'LOGOUT_GLOBAL',
        sucesso: true,
        ip,
        userAgent,
        detalhes: { motivo: 'Todas as sessões ativas foram encerradas' }
      });

      return res.status(200).json({ message: 'Todas as suas sessões ativas foram desconectadas com sucesso.' });
    } catch (error) {
      logger.error('[LoginController.logoutGlobal] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao processar logout global.' });
    }
  }

  public static async getMe(req: Request, res: Response) {
    const authReq = req as AuthenticatedRequest;
    const userId = authReq.user?.userId;

    if (!userId) {
      return res.status(401).json({ error: 'Sessão inválida ou não autenticada.' });
    }

    try {
      const userRes = await pool.query(`
        SELECT u.id, u.nome, u.email, u.matricula, u.perfil, 
               COALESCE(u.permissao_rh, false) AS permissao_rh,
               COALESCE(u.permissao_ti, false) AS permissao_ti,
               COALESCE(u.exigir_mfa, false) AS exigir_mfa,
               u.ativo,
               COALESCE(u.totp_ativo, false) AS totp_ativo,
               u.departamento_id, d.nome AS departamento_nome,
               u.ultimo_login
        FROM usuarios u
        LEFT JOIN departamentos d ON u.departamento_id = d.id
        WHERE u.id = $1
      `, [userId]);

      if (userRes.rowCount === 0) {
        return res.status(404).json({ error: 'Usuário não encontrado.' });
      }

      const user = userRes.rows[0];

      if (!user.ativo) {
        return res.status(401).json({ error: 'Usuário inativo. Entre em contato com o RH.' });
      }

      return res.status(200).json(toUserResponseDto(user));
    } catch (error) {
      logger.error('[LoginController.getMe] Erro ao buscar perfil:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro interno ao buscar perfil do usuário.' });
    }
  }

  public static async getConfigSeguranca(req: Request, res: Response) {
    try {
      const autoLockAtivo = (await ConfigService.get('AUTO_LOCK_ATIVO', 'true')) === 'true';
      const autoLockMinutos = await ConfigService.getNumber('AUTO_LOCK_MINUTOS', 15);
      const mfaPolicy = await ConfigService.get('MFA_POLICY', 'OBRIGATORIO_RH');
      const ssoEnabled = (await ConfigService.get('SSO_ENABLED', 'false')) === 'true';

      return res.status(200).json({
        autoLock: {
          ativo: autoLockAtivo,
          minutos: autoLockMinutos
        },
        mfa: {
          policy: mfaPolicy
        },
        sso: {
          enabled: ssoEnabled
        }
      });
    } catch (error) {
      logger.error('[LoginController.getConfigSeguranca] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao obter configurações públicas de segurança.' });
    }
  }
}
