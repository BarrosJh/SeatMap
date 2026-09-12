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
import { TotpService } from '../../services/totpService';
import { CryptoService } from '../../services/cryptoService';
import { TokenService } from '../../services/tokenService';
import { logger } from '../../utils/logger';
import { env } from '../../config/env';
import { toUserResponseDto } from '../../utils/userDtoMapper';
import { JwtCryptoUtils } from '../../config/jwtCryptoUtils';

const JWT_EXPIRATION = env.JWT_EXPIRATION;
const JWT_ADMIN_EXPIRATION = env.JWT_ADMIN_EXPIRATION;

export class MfaController {
  public static async setupTotp(req: AuthenticatedRequest, res: Response) {
    const user = req.user;
    if (!user) return res.status(401).json({ error: 'Não autenticado.' });

    try {
      const secret = TotpService.generateSecret();
      const otpauthUri = TotpService.generateOtpauthUri(secret, user.email);
      const backupCodes = TotpService.generateBackupCodes(8);

      // Criptografar segredo temporário
      const encryptedSecret = CryptoService.encrypt(secret);
      const encryptedBackupCodes = CryptoService.encrypt(JSON.stringify(backupCodes));

      await pool.query(
        'UPDATE usuarios SET totp_secret = $1, totp_backup_codes = $2 WHERE id = $3',
        [encryptedSecret, encryptedBackupCodes, user.userId]
      );

      return res.status(200).json({
        secret,
        otpauthUri,
        backupCodes
      });
    } catch (error) {
      logger.error('[MfaController.setupTotp] Erro:', { correlationId: (req as any).correlationId, error });
      return res.status(500).json({ error: 'Erro ao configurar autenticação TOTP.' });
    }
  }

  public static async ativarTotp(req: AuthenticatedRequest, res: Response) {
    const user = req.user;
    const { codigo } = req.body;
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

    if (!user) return res.status(401).json({ error: 'Não autenticado.' });
    if (!codigo || String(codigo).trim().length !== 6) {
      return res.status(400).json({ error: 'Código de 6 dígitos obrigatório.' });
    }

    try {
      const userRes = await pool.query('SELECT totp_secret FROM usuarios WHERE id = $1', [user.userId]);
      const storedSecret = userRes.rows[0]?.totp_secret;

      if (!storedSecret) {
        return res.status(400).json({ error: 'Nenhum segredo TOTP configurado. Inicie a configuração novamente.' });
      }

      const isValid = TotpService.verifyToken(String(codigo).trim(), storedSecret);

      if (!isValid) {
        AuditService.log({
          usuarioId: user.userId,
          tipoEvento: 'TOTP_FALHA',
          sucesso: false,
          ip,
          userAgent,
          detalhes: { contexto: 'Ativação inicial do 2FA' }
        });
        return res.status(400).json({ error: 'Código inválido. Verifique o horário do seu dispositivo e tente novamente.' });
      }

      await pool.query('UPDATE usuarios SET totp_ativo = true WHERE id = $1', [user.userId]);

      AuditService.log({
        usuarioId: user.userId,
        tipoEvento: 'TOTP_ATIVADO',
        sucesso: true,
        ip,
        userAgent
      });

      return res.status(200).json({ message: 'Autenticação em 2 etapas (TOTP) ativada com sucesso!' });
    } catch (error) {
      logger.error('[MfaController.ativarTotp] Erro:', { correlationId: (req as any).correlationId, error });
      return res.status(500).json({ error: 'Erro ao ativar TOTP.' });
    }
  }

  public static async desativarTotp(req: AuthenticatedRequest, res: Response) {
    const user = req.user;
    const { senha } = req.body;
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

    if (!user) return res.status(401).json({ error: 'Não autenticado.' });
    if (!senha) return res.status(400).json({ error: 'Senha atual é obrigatória para desativar o TOTP.' });

    try {
      const userRes = await pool.query('SELECT senha_hash FROM usuarios WHERE id = $1', [user.userId]);
      const userDb = userRes.rows[0];

      const match = await bcrypt.compare(senha, userDb.senha_hash);
      if (!match) {
        AuditService.log({
          usuarioId: user.userId,
          tipoEvento: 'TOTP_FALHA',
          sucesso: false,
          ip,
          userAgent,
          detalhes: { contexto: 'Tentativa de desativação com senha incorreta' }
        });
        return res.status(401).json({ error: 'Senha incorreta.' });
      }

      await pool.query('UPDATE usuarios SET totp_ativo = false, totp_secret = NULL, totp_backup_codes = NULL WHERE id = $1', [user.userId]);

      AuditService.log({
        usuarioId: user.userId,
        tipoEvento: 'TOTP_DESATIVADO',
        sucesso: true,
        ip,
        userAgent
      });

      return res.status(200).json({ message: 'Autenticação em 2 etapas (TOTP) desativada.' });
    } catch (error) {
      logger.error('[MfaController.desativarTotp] Erro:', { correlationId: (req as any).correlationId, error });
      return res.status(500).json({ error: 'Erro ao desativar TOTP.' });
    }
  }

  public static async validarLoginTotp(req: Request, res: Response) {
    const { tempToken, codigo } = req.body;
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

    if (!tempToken || !codigo) {
      return res.status(400).json({ error: 'Token temporário e código de 6 dígitos são obrigatórios.' });
    }

    try {
      let decoded: any;
      try {
        decoded = JwtCryptoUtils.verifyToken(tempToken);
      } catch (e) {
        return res.status(401).json({ error: 'Sessão temporária de MFA expirada. Faça login novamente.' });
      }

      const userId = decoded.userId;
      const userRes = await pool.query(`
        SELECT u.id, u.nome, u.email, u.matricula, u.perfil, 
               COALESCE(u.permissao_rh, false) AS permissao_rh,
               COALESCE(u.permissao_ti, false) AS permissao_ti,
               COALESCE(u.token_version, 1) AS token_version,
               u.ativo, u.totp_secret, u.totp_backup_codes,
               u.departamento_id, d.nome AS departamento_nome
        FROM usuarios u
        LEFT JOIN departamentos d ON u.departamento_id = d.id
        WHERE u.id = $1 AND u.ativo = true
      `, [userId]);

      if (userRes.rowCount === 0) {
        return res.status(401).json({ error: 'Usuário inválido ou inativo.' });
      }

      const user = userRes.rows[0];
      const cleanCode = String(codigo).trim();
      let codeValid = false;
      let usedBackupCode = false;

      // 1. Checar código TOTP de 6 dígitos
      if (cleanCode.length === 6 && user.totp_secret) {
        codeValid = TotpService.verifyToken(cleanCode, user.totp_secret);
      }

      // 2. Se falhar, checar códigos de backup (scratch codes)
      if (!codeValid && user.totp_backup_codes) {
        const rawCodesJson = CryptoService.isEncrypted(user.totp_backup_codes)
          ? CryptoService.decrypt(user.totp_backup_codes)
          : user.totp_backup_codes;

        try {
          const codesList: string[] = JSON.parse(rawCodesJson);
          const codeIdx = codesList.indexOf(cleanCode.toUpperCase());
          if (codeIdx !== -1) {
            codeValid = true;
            usedBackupCode = true;
            codesList.splice(codeIdx, 1);
            const updatedEncrypted = CryptoService.encrypt(JSON.stringify(codesList));
            await pool.query('UPDATE usuarios SET totp_backup_codes = $1 WHERE id = $2', [updatedEncrypted, user.id]);
          }
        } catch (e) {
          logger.error('[MfaController.validarLoginTotp] Falha ao desserializar backup codes:', { correlationId: (req as any).correlationId, error: e });
        }
      }

      if (!codeValid) {
        AuditService.log({
          usuarioId: user.id,
          tipoEvento: 'TOTP_FALHA',
          sucesso: false,
          ip,
          userAgent,
          detalhes: { motivo: 'Código TOTP ou Backup incorreto' }
        });
        return res.status(400).json({ error: 'Código de autenticação inválido.' });
      }

      // Atualizar último login
      await pool.query('UPDATE usuarios SET ultimo_login = NOW() WHERE id = $1', [user.id]);

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
        tipoEvento: usedBackupCode ? 'TOTP_BACKUP_USADO' : 'TOTP_VALIDADO',
        sucesso: true,
        ip,
        userAgent
      });

      // Emissão de Refresh Token com rotação de segurança
      const refreshToken = await TokenService.gerarRefreshToken(user.id, ip, userAgent);

      return res.status(200).json({
        token,
        refreshToken,
        user: toUserResponseDto(user)
      });
    } catch (error) {
      logger.error('[MfaController.validarLoginTotp] Erro:', { correlationId: (req as any).correlationId, error });
      return res.status(500).json({ error: 'Erro ao validar código TOTP.' });
    }
  }

  public static async validarLoginEmailMfa(req: Request, res: Response) {
    const { tempToken, codigo } = req.body;
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

    if (!tempToken || !codigo) {
      return res.status(400).json({ error: 'Token temporário e código de 6 dígitos são obrigatórios.' });
    }

    try {
      let decoded: any;
      try {
        decoded = JwtCryptoUtils.verifyToken(tempToken);
      } catch (e) {
        return res.status(401).json({ error: 'Sessão temporária de MFA expirada. Faça login novamente.' });
      }

      const userId = decoded.userId;
      const userRes = await pool.query(`
        SELECT u.id, u.nome, u.email, u.matricula, u.perfil, 
                COALESCE(u.permissao_rh, false) AS permissao_rh,
                COALESCE(u.permissao_ti, false) AS permissao_ti,
                COALESCE(u.token_version, 1) AS token_version,
                u.ativo,
                COALESCE(u.totp_ativo, false) AS totp_ativo,
                u.departamento_id, d.nome AS departamento_nome
        FROM usuarios u
        LEFT JOIN departamentos d ON u.departamento_id = d.id
        WHERE u.id = $1 AND u.ativo = true
      `, [userId]);

      if (userRes.rowCount === 0) {
        return res.status(401).json({ error: 'Usuário inválido ou inativo.' });
      }

      const user = userRes.rows[0];
      const cleanCode = String(codigo).trim();

      const codeRes = await pool.query(`
        SELECT id, codigo, expira_em, utilizado
        FROM auth_mfa_codes
        WHERE usuario_id = $1 AND utilizado = false
        ORDER BY id DESC
        LIMIT 1
      `, [user.id]);

      if (codeRes.rowCount === 0) {
        return res.status(400).json({ error: 'Nenhum código de segurança pendente. Solicite um novo login.' });
      }

      const mfaRecord = codeRes.rows[0];

      if (new Date(mfaRecord.expira_em) < new Date()) {
        await pool.query('UPDATE auth_mfa_codes SET utilizado = true WHERE id = $1', [mfaRecord.id]);
        return res.status(400).json({ error: 'O código de verificação expirou. Faça login novamente para receber um novo código.' });
      }

      if (mfaRecord.codigo !== cleanCode) {
        AuditService.log({
          usuarioId: user.id,
          tipoEvento: 'MFA_FALHA_EMAIL',
          sucesso: false,
          ip,
          userAgent,
          detalhes: { motivo: 'Código PIN de e-mail incorreto' }
        });
        return res.status(400).json({ error: 'Código de verificação incorreto.' });
      }

      // Marcar código como utilizado
      await pool.query('UPDATE auth_mfa_codes SET utilizado = true WHERE id = $1', [mfaRecord.id]);

      // Atualizar último login
      await pool.query('UPDATE usuarios SET ultimo_login = NOW() WHERE id = $1', [user.id]);

      // Hardening de Sessão: Invalidação de sessões ativas anteriores (Single Active Session Enforcement)
      await TokenService.incrementarTokenVersion(user.id, { ip, userAgent });
      const activeTokenVersion = (user.token_version || 1) + 1;
      const authTime = Math.floor(Date.now() / 1000);

      // Emitir Token de Sessão JWT definitivo
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
        tipoEvento: 'MFA_VALIDADO_EMAIL',
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
      logger.error('[MfaController.validarLoginEmailMfa] Erro:', { correlationId: (req as any).correlationId, error });
      return res.status(500).json({ error: 'Erro ao validar código MFA por e-mail.' });
    }
  }

  public static async solicitarMfa(req: AuthenticatedRequest, res: Response) {
    const user = req.user;
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

    const hasAdminAccess = user?.permissaoRh === true || user?.permissaoTi === true || user?.is_admin === true || user?.perfil === 'ADMIN_RH' || user?.perfil === 'ADMIN_TI';
    if (!user || !hasAdminAccess) {
      return res.status(403).json({ error: 'Apenas administradores com permissão de RH ou TI podem solicitar código MFA.' });
    }

    try {
      const expiraMin = await ConfigService.getNumber('MFA_EXPIRACAO_MINUTOS', 10);
      const codigo = crypto.randomInt(100000, 1000000).toString();
      const expiraEm = DateTime.now().plus({ minutes: expiraMin }).toJSDate();

      await pool.query(`
        INSERT INTO auth_mfa_codes (usuario_id, codigo, expira_em, utilizado)
        VALUES ($1, $2, $3, false)
      `, [user.userId, codigo, expiraEm]);

      EmailService.enviarCodigoMfa(user.email, user.nome, codigo, expiraMin).catch(err => {
        logger.error('[MfaController.solicitarMfa] Erro ao enviar e-mail:', { correlationId: req.correlationId, error: err });
      });

      AuditService.log({
        usuarioId: user.userId,
        tipoEvento: 'MFA_SOLICITADO_EMAIL',
        sucesso: true,
        ip,
        userAgent
      });

      return res.status(200).json({
        message: 'Código de autenticação MFA gerado e enviado por e-mail com sucesso.',
        email: user.email,
        expiraEmMinutos: expiraMin,
        codigoSimulado: (process.env.NODE_ENV === 'test' && process.env.ENABLE_DEV_MFA_EXPOSURE === 'true') ? codigo : undefined
      });
    } catch (error) {
      logger.error('[MfaController.solicitarMfa] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro interno ao gerar código MFA.' });
    }
  }

  public static async validarMfa(req: AuthenticatedRequest, res: Response) {
    const user = req.user;
    const { codigo } = req.body;
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

    const hasAdminAccess = user?.permissaoRh === true || user?.permissaoTi === true || user?.is_admin === true || user?.perfil === 'ADMIN_RH' || user?.perfil === 'ADMIN_TI';

    if (!user || !hasAdminAccess) {
      return res.status(403).json({ error: 'Apenas administradores com permissão de RH ou TI podem validar código MFA.' });
    }

    if (!codigo || String(codigo).trim().length !== 6) {
      return res.status(400).json({ error: 'Código MFA de 6 dígitos obrigatório.' });
    }

    try {
      const mfaRes = await pool.query(`
        SELECT id, expira_em, utilizado
        FROM auth_mfa_codes
        WHERE usuario_id = $1 AND codigo = $2 AND utilizado = false
        ORDER BY id DESC
        LIMIT 1
      `, [user.userId, String(codigo).trim()]);

      if (mfaRes.rowCount === 0) {
        AuditService.log({
          usuarioId: user.userId,
          tipoEvento: 'MFA_FALHA_EMAIL',
          sucesso: false,
          ip,
          userAgent,
          detalhes: { motivo: 'Código inválido ou já utilizado' }
        });
        return res.status(400).json({ error: 'Código MFA inválido ou já utilizado.' });
      }
      const mfaRecord = mfaRes.rows[0];

      const now = new Date();
      if (new Date(mfaRecord.expira_em) < now) {
        return res.status(400).json({ error: 'Código MFA expirado. Por favor, solicite um novo código.' });
      }

      await pool.query('UPDATE auth_mfa_codes SET utilizado = true WHERE id = $1', [mfaRecord.id]);

      const adminToken = JwtCryptoUtils.signToken({
        userId: user.userId,
        nome: user.nome,
        perfil: user.perfil,
        permissaoRh: user.permissaoRh,
        permissaoTi: user.permissaoTi,
        role: 'ADMIN_STEP_UP_AUTHENTICATED'
      }, { expiresIn: JWT_ADMIN_EXPIRATION as any });


      AuditService.log({
        usuarioId: user.userId,
        tipoEvento: 'MFA_VALIDADO_EMAIL',
        sucesso: true,
        ip,
        userAgent
      });

      return res.status(200).json({
        message: 'Autenticação Step-Up MFA realizada com sucesso.',
        admin_token: adminToken,
        expiresIn: JWT_ADMIN_EXPIRATION
      });
    } catch (error) {
      logger.error('[MfaController.validarMfa] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro interno ao validar MFA.' });
    }
  }
}
