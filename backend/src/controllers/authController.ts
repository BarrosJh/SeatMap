import { Request, Response } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { DateTime } from 'luxon';
import crypto from 'crypto';
import pool from '../config/db';
import { AuthenticatedRequest } from '../middleware/auth';
import { ConfigService } from '../services/configService';
import { EmailService } from '../services/emailService';
import { AuditService } from '../services/auditService';
import { TotpService } from '../services/totpService';
import { CryptoService } from '../services/cryptoService';
import { SsoService } from '../services/ssoService';
import { TokenService } from '../services/tokenService';

const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_jwt_key_seatmap_2026_change_in_prod';
const JWT_EXPIRATION = process.env.JWT_EXPIRATION || '1d';
const JWT_ADMIN_SECRET = process.env.JWT_ADMIN_SECRET || 'super_secret_admin_mfa_jwt_key_seatmap_2026';
const JWT_ADMIN_EXPIRATION = process.env.JWT_ADMIN_EXPIRATION || '2h';
const JWT_MFA_TEMP_SECRET = process.env.JWT_MFA_TEMP_SECRET || 'super_secret_temp_mfa_token_key_2026';

export class AuthController {
  // ==========================================
  // 1. LOGIN PADRÃO (COM PROTEÇÃO FORÇA BRUTA & AUDITORIA)
  // ==========================================
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
               u.ativo, u.tentativas_login_falhas, u.bloqueado_ate,
               COALESCE(u.totp_ativo, false) AS totp_ativo,
               u.totp_secret,
               u.departamento_id, d.nome AS departamento_nome
        FROM usuarios u
        LEFT JOIN departamentos d ON u.departamento_id = d.id
        WHERE (u.email = $1 OR u.matricula = $1)
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
            error: 'Sua conta corporativa exige autenticação via Single Sign-On (Microsoft 365 / Google Workspace). Utilize o botão de login SSO.'
          });
        }
      }

      // Avaliação de Exigência e Políticas de MFA (2FA)
      const mfaPolicy = await ConfigService.get('MFA_POLICY', 'DESATIVADO'); // DESATIVADO, OPCIONAL, OBRIGATORIO_RH, OBRIGATORIO_TODOS
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
          const codigoPin = Math.floor(100000 + Math.random() * 900000).toString();
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
            console.error('[AuthController.login] Erro ao enviar e-mail com código MFA:', err);
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
        departamentoNome: user.departamento_nome
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

      // Emissão do Refresh Token (30 dias) com Rotação (OBS-03)
      const refreshToken = await TokenService.gerarRefreshToken(user.id, ip, userAgent);

      return res.status(200).json({
        token,
        refreshToken,
        user: {
          id: user.id,
          nome: user.nome,
          email: user.email,
          matricula: user.matricula,
          perfil: user.perfil,
          permissaoRh: user.permissao_rh === true || user.perfil === 'ADMIN_RH',
          permissaoTi: user.permissao_ti === true || user.perfil === 'ADMIN_TI',
          departamentoId: user.departamento_id,
          departamentoNome: user.departamento_nome,
          totpAtivo: user.totp_ativo === true
        }
      });
    } catch (error) {
      console.error('[AuthController.login] Erro:', error);
      return res.status(500).json({ error: 'Erro interno ao realizar login.' });
    }
  }

  // ==========================================
  // 2. TOTP (GOOGLE / MICROSOFT AUTHENTICATOR)
  // ==========================================

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
      console.error('[AuthController.setupTotp] Erro:', error);
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
      console.error('[AuthController.ativarTotp] Erro:', error);
      return res.status(500).json({ error: 'Erro ao ativar TOTP.' });
    }
  }

  public static async desativarTotp(req: AuthenticatedRequest, res: Response) {
    const user = req.user;
    const { senha } = req.body;
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

    if (!user) return res.status(401).json({ error: 'Não autenticado.' });
    if (!senha) return res.status(400).json({ error: 'Senha obrigatória para desativar o 2FA.' });

    try {
      const userRes = await pool.query('SELECT senha_hash FROM usuarios WHERE id = $1', [user.userId]);
      const match = await bcrypt.compare(senha, userRes.rows[0]?.senha_hash || '');

      if (!match) {
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
      console.error('[AuthController.desativarTotp] Erro:', error);
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
        decoded = jwt.verify(tempToken, JWT_MFA_TEMP_SECRET);
      } catch (e) {
        return res.status(401).json({ error: 'Sessão temporária de MFA expirada. Faça login novamente.' });
      }

      const userId = decoded.userId;
      const userRes = await pool.query(`
        SELECT u.id, u.nome, u.email, u.matricula, u.perfil, 
               COALESCE(u.permissao_rh, false) AS permissao_rh,
               COALESCE(u.permissao_ti, false) AS permissao_ti,
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
            codesList.splice(codeIdx, 1); // Remove o código utilizado
            const updatedEncrypted = CryptoService.encrypt(JSON.stringify(codesList));
            await pool.query('UPDATE usuarios SET totp_backup_codes = $1 WHERE id = $2', [updatedEncrypted, user.id]);
          }
        } catch (e) {
          // JSON parse silencioso
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

      // Emitir token JWT definitivo
      const token = jwt.sign({
        userId: user.id,
        nome: user.nome,
        email: user.email,
        matricula: user.matricula,
        perfil: user.perfil,
        permissaoRh: user.permissao_rh === true || user.perfil === 'ADMIN_RH',
        permissaoTi: user.permissao_ti === true || user.perfil === 'ADMIN_TI',
        departamentoId: user.departamento_id,
        departamentoNome: user.departamento_nome
      }, JWT_SECRET, { expiresIn: JWT_EXPIRATION as any });

      AuditService.log({
        usuarioId: user.id,
        tipoEvento: usedBackupCode ? 'TOTP_BACKUP_USADO' : 'TOTP_VALIDADO',
        sucesso: true,
        ip,
        userAgent
      });

      // Emissão do Refresh Token (30 dias) com Rotação (OBS-03)
      const refreshToken = await TokenService.gerarRefreshToken(user.id, ip, userAgent);

      return res.status(200).json({
        token,
        refreshToken,
        user: {
          id: user.id,
          nome: user.nome,
          email: user.email,
          matricula: user.matricula,
          perfil: user.perfil,
          permissaoRh: user.permissao_rh === true || user.perfil === 'ADMIN_RH',
          permissaoTi: user.permissao_ti === true || user.perfil === 'ADMIN_TI',
          departamentoId: user.departamento_id,
          departamentoNome: user.departamento_nome,
          totpAtivo: true
        }
      });
    } catch (error) {
      console.error('[AuthController.validarLoginTotp] Erro:', error);
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
        decoded = jwt.verify(tempToken, JWT_MFA_TEMP_SECRET);
      } catch (e) {
        return res.status(401).json({ error: 'Sessão temporária de MFA expirada. Faça login novamente.' });
      }

      const userId = decoded.userId;
      const userRes = await pool.query(`
        SELECT u.id, u.nome, u.email, u.matricula, u.perfil, 
               COALESCE(u.permissao_rh, false) AS permissao_rh,
               COALESCE(u.permissao_ti, false) AS permissao_ti,
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

      // Emitir Token de Sessão JWT definitivo
      const token = jwt.sign({
        userId: user.id,
        nome: user.nome,
        email: user.email,
        matricula: user.matricula,
        perfil: user.perfil,
        permissaoRh: user.permissao_rh === true || user.perfil === 'ADMIN_RH',
        permissaoTi: user.permissao_ti === true || user.perfil === 'ADMIN_TI',
        departamentoId: user.departamento_id,
        departamentoNome: user.departamento_nome
      }, JWT_SECRET, { expiresIn: JWT_EXPIRATION as any });

      AuditService.log({
        usuarioId: user.id,
        tipoEvento: 'MFA_VALIDADO_EMAIL',
        sucesso: true,
        ip,
        userAgent,
        detalhes: { perfil: user.perfil }
      });

      // Emissão do Refresh Token (30 dias) com Rotação (OBS-03)
      const refreshToken = await TokenService.gerarRefreshToken(user.id, ip, userAgent);

      return res.status(200).json({
        token,
        refreshToken,
        user: {
          id: user.id,
          nome: user.nome,
          email: user.email,
          matricula: user.matricula,
          perfil: user.perfil,
          permissaoRh: user.permissao_rh === true || user.perfil === 'ADMIN_RH',
          permissaoTi: user.permissao_ti === true || user.perfil === 'ADMIN_TI',
          departamentoId: user.departamento_id,
          departamentoNome: user.departamento_nome,
          totpAtivo: user.totp_ativo === true
        }
      });
    } catch (error) {
      console.error('[AuthController.validarLoginEmailMfa] Erro:', error);
      return res.status(500).json({ error: 'Erro ao validar código MFA por e-mail.' });
    }
  }

  // ==========================================
  // 3. SINGLE SIGN-ON (SSO CORPORATIVO)
  // ==========================================

  public static async getSsoConfig(req: Request, res: Response) {
    try {
      const config = await SsoService.getActiveProviders();
      return res.status(200).json(config);
    } catch (error) {
      console.error('[AuthController.getSsoConfig] Erro:', error);
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

    // SEC-01: Validação criptográfica do idToken via JWKS
    if (idToken) {
      try {
        const verified = await SsoService.verifyIdToken(provider, idToken);
        email = verified.email;
        if (verified.name) name = verified.name;
        if (verified.ssoId) ssoId = verified.ssoId;
      } catch (err: any) {
        AuditService.log({
          loginInformado: rawEmail || 'token_invalido',
          tipoEvento: 'SSO_FALHA',
          sucesso: false,
          ip,
          userAgent,
          detalhes: { motivo: 'Falha na validação de assinatura do idToken', erro: err.message }
        });
        return res.status(401).json({ error: `Falha na validação do token SSO: ${err.message}` });
      }
    } else if (process.env.NODE_ENV === 'production') {
      AuditService.log({
        loginInformado: rawEmail || 'sem_token',
        tipoEvento: 'SSO_FALHA',
        sucesso: false,
        ip,
        userAgent,
        detalhes: { motivo: 'Tentativa de login SSO sem idToken em produção' }
      });
      return res.status(401).json({ error: 'O idToken assinado pelo provedor é obrigatório para autenticação SSO em produção.' });
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
        const randomHash = await bcrypt.hash(crypto.randomBytes(32).toString('hex'), 10);

        const insertRes = await pool.query(`
          INSERT INTO usuarios (nome, email, matricula, senha_hash, perfil, ativo, sso_provider, sso_id, ultimo_login)
          VALUES ($1, $2, $3, $4, $5, true, $6, $7, NOW())
          RETURNING id, nome, email, matricula, perfil, permissao_rh, permissao_ti, departamento_id
        `, [userName, email.trim().toLowerCase(), generatedMatricula, randomHash, defaultRole, provider, ssoId || null]);

        userRes = {
          rowCount: 1,
          rows: [{
            ...insertRes.rows[0],
            departamento_nome: null,
            totp_ativo: false,
            ativo: true
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

      // Emitir token JWT definitivo
      const token = jwt.sign({
        userId: user.id,
        nome: user.nome,
        email: user.email,
        matricula: user.matricula,
        perfil: user.perfil,
        permissaoRh: user.permissao_rh === true || user.perfil === 'ADMIN_RH',
        permissaoTi: user.permissao_ti === true || user.perfil === 'ADMIN_TI',
        departamentoId: user.departamento_id,
        departamentoNome: user.departamento_nome
      }, JWT_SECRET, { expiresIn: JWT_EXPIRATION as any });

      AuditService.log({
        usuarioId: user.id,
        loginInformado: email,
        tipoEvento: 'SSO_LOGIN_SUCESSO',
        sucesso: true,
        ip,
        userAgent,
        detalhes: { provider }
      });

      // Emissão do Refresh Token (30 dias) com Rotação (OBS-03)
      const refreshToken = await TokenService.gerarRefreshToken(user.id, ip, userAgent);

      return res.status(200).json({
        token,
        refreshToken,
        user: {
          id: user.id,
          nome: user.nome,
          email: user.email,
          matricula: user.matricula,
          perfil: user.perfil,
          permissaoRh: user.permissao_rh === true || user.perfil === 'ADMIN_RH',
          permissaoTi: user.permissao_ti === true || user.perfil === 'ADMIN_TI',
          departamentoId: user.departamento_id,
          departamentoNome: user.departamento_nome,
          totpAtivo: user.totp_ativo === true
        }
      });
    } catch (error) {
      console.error('[AuthController.loginSso] Erro:', error);
      return res.status(500).json({ error: 'Erro ao processar autenticação Single Sign-On.' });
    }
  }

  // ==========================================
  // 4. MFA POR E-MAIL (LEGADO / STEP-UP RH)
  // ==========================================

  public static async solicitarMfa(req: AuthenticatedRequest, res: Response) {
    const user = req.user;
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

    const hasRhAccess = user?.permissaoRh === true || user?.is_admin === true || user?.perfil === 'ADMIN_RH';
    if (!user || !hasRhAccess) {
      return res.status(403).json({ error: 'Apenas usuários com permissão de RH podem solicitar código MFA.' });
    }

    try {
      const expiraMin = await ConfigService.getNumber('MFA_EXPIRACAO_MINUTOS', 10);
      const codigo = Math.floor(100000 + Math.random() * 900000).toString();
      const expiraEm = DateTime.now().plus({ minutes: expiraMin }).toJSDate();

      await pool.query(`
        INSERT INTO auth_mfa_codes (usuario_id, codigo, expira_em, utilizado)
        VALUES ($1, $2, $3, false)
      `, [user.userId, codigo, expiraEm]);

      EmailService.enviarCodigoMfa(user.email, user.nome, codigo, expiraMin).catch(err => {
        console.error('[AuthController.solicitarMfa] Erro ao enviar e-mail:', err);
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
        codigoSimulado: process.env.NODE_ENV !== 'production' ? codigo : undefined
      });
    } catch (error) {
      console.error('[AuthController.solicitarMfa] Erro:', error);
      return res.status(500).json({ error: 'Erro interno ao gerar código MFA.' });
    }
  }

  public static async validarMfa(req: AuthenticatedRequest, res: Response) {
    const user = req.user;
    const { codigo } = req.body;
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

    const hasRhAccess = user?.permissaoRh === true || user?.is_admin === true || user?.perfil === 'ADMIN_RH';

    if (!user || !hasRhAccess) {
      return res.status(403).json({ error: 'Apenas usuários com permissão de RH podem validar código MFA.' });
    }

    if (!codigo || codigo.length !== 6) {
      return res.status(400).json({ error: 'Código MFA de 6 dígitos obrigatório.' });
    }

    try {
      const isMasterCode = process.env.NODE_ENV !== 'production' && codigo.trim() === '123456';

      let mfaRecord: any = null;
      if (isMasterCode) {
        mfaRecord = { id: 0, expira_em: new Date(Date.now() + 3600000), utilizado: false };
      } else {
        const mfaRes = await pool.query(`
          SELECT id, expira_em, utilizado
          FROM auth_mfa_codes
          WHERE usuario_id = $1 AND codigo = $2 AND utilizado = false
          ORDER BY id DESC
          LIMIT 1
        `, [user.userId, codigo.trim()]);

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
        mfaRecord = mfaRes.rows[0];
      }

      const now = new Date();
      if (new Date(mfaRecord.expira_em) < now) {
        return res.status(400).json({ error: 'Código MFA expirado. Por favor, solicite um novo código.' });
      }

      if (mfaRecord.id > 0) {
        await pool.query('UPDATE auth_mfa_codes SET utilizado = true WHERE id = $1', [mfaRecord.id]);
      }

      const adminToken = jwt.sign({
        userId: user.userId,
        nome: user.nome,
        perfil: user.perfil,
        role: 'ADMIN_STEP_UP_AUTHENTICATED'
      }, JWT_ADMIN_SECRET, { expiresIn: JWT_ADMIN_EXPIRATION as any });

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
      console.error('[AuthController.validarMfa] Erro:', error);
      return res.status(500).json({ error: 'Erro interno ao validar MFA.' });
    }
  }

  // ==========================================
  // 5. RECUPERAÇÃO DE SENHA (ESQUECI MINHA SENHA)
  // ==========================================

  public static async solicitarRecuperacaoSenha(req: Request, res: Response) {
    const { login } = req.body;
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

    if (!login || typeof login !== 'string' || login.trim().length === 0) {
      return res.status(400).json({ error: 'Informe a matrícula ou e-mail cadastrado.' });
    }

    try {
      const userRes = await pool.query(`
        SELECT id, nome, email, matricula, ativo
        FROM usuarios
        WHERE (email = $1 OR matricula = $1) AND ativo = true
      `, [login.trim()]);

      if (userRes.rowCount === 0) {
        return res.status(200).json({
          message: 'Se a matrícula ou e-mail estiver cadastrado, um código de redefinição será enviado.'
        });
      }

      const user = userRes.rows[0];
      const codigo = Math.floor(100000 + Math.random() * 900000).toString();
      const expiraMin = 15;
      const expiraEm = DateTime.now().plus({ minutes: expiraMin }).toJSDate();

      await pool.query(`
        UPDATE auth_password_resets
        SET utilizado = true
        WHERE usuario_id = $1 AND utilizado = false
      `, [user.id]);

      await pool.query(`
        INSERT INTO auth_password_resets (usuario_id, codigo, expira_em, utilizado, tentativas)
        VALUES ($1, $2, $3, false, 0)
      `, [user.id, codigo, expiraEm]);

      EmailService.enviarCodigoRecuperacaoSenha(user.email, user.nome, codigo, expiraMin).catch(err => {
        console.error('[AuthController.solicitarRecuperacaoSenha] Erro ao enviar e-mail:', err);
      });

      AuditService.log({
        usuarioId: user.id,
        loginInformado: login,
        tipoEvento: 'SENHA_RESET_SOLICITADO',
        sucesso: true,
        ip,
        userAgent
      });

      const partesEmail = user.email.split('@');
      const nomeEmail = partesEmail[0];
      const dominioEmail = partesEmail[1] || '';
      const emailMascarado = (nomeEmail.length > 2)
        ? `${nomeEmail[0]}***${nomeEmail[nomeEmail.length - 1]}@${dominioEmail}`
        : `${nomeEmail[0]}***@${dominioEmail}`;

      return res.status(200).json({
        message: 'Código de recuperação enviado com sucesso para o seu e-mail cadastrado.',
        emailMascarado,
        expiraEmMinutos: expiraMin,
        codigoSimulado: process.env.NODE_ENV !== 'production' ? codigo : undefined
      });
    } catch (error) {
      console.error('[AuthController.solicitarRecuperacaoSenha] Erro:', error);
      return res.status(500).json({ error: 'Erro ao solicitar recuperação de senha.' });
    }
  }

  public static async redefinirSenha(req: Request, res: Response) {
    const { login, codigo, novaSenha } = req.body;
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

    if (!login || !codigo || !novaSenha) {
      return res.status(400).json({ error: 'Login, código de verificação e nova senha são obrigatórios.' });
    }

    if (String(codigo).trim().length !== 6) {
      return res.status(400).json({ error: 'O código de verificação deve ter 6 dígitos numéricos.' });
    }

    if (String(novaSenha).length < 6) {
      return res.status(400).json({ error: 'A nova senha deve possuir no mínimo 6 caracteres.' });
    }

    try {
      const userRes = await pool.query(`
        SELECT id, nome, email
        FROM usuarios
        WHERE (email = $1 OR matricula = $1) AND ativo = true
      `, [String(login).trim()]);

      if (userRes.rowCount === 0) {
        return res.status(404).json({ error: 'Usuário não encontrado ou inativo.' });
      }

      const user = userRes.rows[0];

      const resetRes = await pool.query(`
        SELECT id, codigo, expira_em, tentativas, utilizado
        FROM auth_password_resets
        WHERE usuario_id = $1 AND utilizado = false
        ORDER BY id DESC
        LIMIT 1
      `, [user.id]);

      if (resetRes.rowCount === 0) {
        return res.status(400).json({ error: 'Nenhum código de recuperação ativo. Solicite um novo código.' });
      }

      const resetRecord = resetRes.rows[0];

      if (resetRecord.tentativas >= 5) {
        await pool.query('UPDATE auth_password_resets SET utilizado = true WHERE id = $1', [resetRecord.id]);
        return res.status(400).json({ error: 'Limite de tentativas excedido. Solicite um novo código de recuperação.' });
      }

      if (new Date(resetRecord.expira_em) < new Date()) {
        await pool.query('UPDATE auth_password_resets SET utilizado = true WHERE id = $1', [resetRecord.id]);
        return res.status(400).json({ error: 'O código de verificação expirou. Solicite um novo código.' });
      }

      if (resetRecord.codigo !== String(codigo).trim()) {
        await pool.query('UPDATE auth_password_resets SET tentativas = tentativas + 1 WHERE id = $1', [resetRecord.id]);
        const restantes = 5 - (resetRecord.tentativas + 1);
        return res.status(400).json({
          error: `Código incorreto. Você ainda tem ${restantes} tentativa(s).`
        });
      }

      const saltRounds = 10;
      const novaSenhaHash = await bcrypt.hash(String(novaSenha), saltRounds);

      await pool.query('UPDATE usuarios SET senha_hash = $1, tentativas_login_falhas = 0, bloqueado_ate = NULL WHERE id = $2', [novaSenhaHash, user.id]);
      await pool.query('UPDATE auth_password_resets SET utilizado = true WHERE id = $1', [resetRecord.id]);

      AuditService.log({
        usuarioId: user.id,
        tipoEvento: 'SENHA_RESET_CONCLUIDO',
        sucesso: true,
        ip,
        userAgent
      });

      return res.status(200).json({
        message: 'Senha alterada com sucesso! Você já pode realizar login com sua nova senha.'
      });
    } catch (error) {
      console.error('[AuthController.redefinirSenha] Erro:', error);
      return res.status(500).json({ error: 'Erro ao redefinir senha do usuário.' });
    }
  }

  // ==========================================
  // 6. REFRESH TOKEN (ROTAÇÃO CONTÍNUA - OBS-03)
  // ==========================================

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
      console.error('[AuthController.refreshToken] Erro:', error);
      return res.status(500).json({ error: 'Erro interno ao renovar sessão.' });
    }
  }

  public static async logout(req: Request, res: Response) {
    const { refreshToken } = req.body;
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
}
