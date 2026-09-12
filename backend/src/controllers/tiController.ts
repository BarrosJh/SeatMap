import { Request, Response } from 'express';
import pool from '../config/db';
import { ConfigService } from '../services/configService';
import { EmailService } from '../services/emailService';
import { AuditService } from '../services/auditService';
import { wsManager } from '../websocket/wsServer';
import { performance } from 'perf_hooks';
import { logger } from '../utils/logger';

export class TiController {
  /**
   * Obtém as configurações de TI (SMTP, MFA e SSO Corporativo)
   */
  public static async getConfiguracoesTi(req: Request, res: Response): Promise<void> {
    try {
      const emailProvider = await ConfigService.get('EMAIL_PROVIDER', '');
      const resendApiKeyRaw = await ConfigService.get('RESEND_API_KEY', process.env.RESEND_API_KEY || '');
      const smtpHost = await ConfigService.get('SMTP_HOST', process.env.SMTP_HOST || 'smtp.gmail.com');
      const smtpPort = await ConfigService.get('SMTP_PORT', process.env.SMTP_PORT || '587');
      const smtpSecure = await ConfigService.get('SMTP_SECURE', process.env.SMTP_SECURE || 'false');
      const smtpUser = await ConfigService.get('SMTP_USER', process.env.SMTP_USER || '');
      const rawPass = await ConfigService.get('SMTP_PASS', process.env.SMTP_PASS || '');
      const emailFrom = await ConfigService.get('EMAIL_FROM', process.env.EMAIL_FROM || '"SeatMap Corporativo" <nao-responda@seatmap.local>');

      // Determina provedor ativo (padrão RESEND se chave configurada ou se SMTP_PASS começar com re_)
      const activeProvider = emailProvider
        ? emailProvider
        : (resendApiKeyRaw.length > 0 || rawPass.startsWith('re_') ? 'RESEND' : 'SMTP');

      // Configurações de MFA
      const mfaExpiracao = await ConfigService.getNumber('MFA_EXPIRACAO_MINUTOS', 10);
      const mfaMaxTentativas = await ConfigService.getNumber('MFA_MAX_TENTATIVAS', 3);
      const mfaPolicy = await ConfigService.get('MFA_POLICY', 'DESATIVADO'); // DESATIVADO, OPCIONAL, OBRIGATORIO_RH, OBRIGATORIO_TODOS
      const mfaEmailEnabled = (await ConfigService.get('MFA_EMAIL_ENABLED', 'true')) === 'true';
      const mfaTotpEnabled = (await ConfigService.get('MFA_TOTP_ENABLED', 'true')) === 'true';

      // Configurações de SSO Corporativo
      const ssoEnabled = (await ConfigService.get('SSO_ENABLED', 'false')) === 'true';
      const ssoAllowedDomains = await ConfigService.get('SSO_ALLOWED_DOMAINS', '');
      const ssoAutoProvision = (await ConfigService.get('SSO_AUTO_PROVISION', 'true')) === 'true';
      const ssoDefaultRole = await ConfigService.get('SSO_DEFAULT_ROLE', 'COLABORADOR');
      const ssoEnforceForDomains = (await ConfigService.get('SSO_ENFORCE_FOR_DOMAINS', 'false')) === 'true';

      // Microsoft Entra ID / Azure AD
      const ssoAzureEnabled = (await ConfigService.get('SSO_AZURE_ENABLED', 'false')) === 'true';
      const ssoAzureTenantType = await ConfigService.get('SSO_AZURE_TENANT_TYPE', 'single_tenant');
      const ssoAzureTenantId = await ConfigService.get('SSO_AZURE_TENANT_ID', '');
      const ssoAzureClientId = await ConfigService.get('SSO_AZURE_CLIENT_ID', '');
      const azureSecretRaw = await ConfigService.get('SSO_AZURE_CLIENT_SECRET', '');
      const ssoAzureScopes = await ConfigService.get('SSO_AZURE_SCOPES', 'openid profile email User.Read');
      const ssoAzureSecurityGroup = await ConfigService.get('SSO_AZURE_SECURITY_GROUP', '');
      const ssoAzureRedirectUri = await ConfigService.get('SSO_AZURE_REDIRECT_URI', '');

      // Configurações de Auto-Lock por Inatividade (Segurança Bancária)
      const autoLockAtivo = (await ConfigService.get('AUTO_LOCK_ATIVO', 'true')) === 'true';
      const autoLockMinutos = await ConfigService.getNumber('AUTO_LOCK_MINUTOS', 15);

      const smtpPayload = {
        host: smtpHost,
        port: parseInt(smtpPort, 10),
        secure: smtpSecure === 'true',
        user: smtpUser,
        passConfigured: rawPass.length > 0 && !rawPass.startsWith('re_'),
        emailFrom
      };

      res.status(200).json({
        email: {
          provider: activeProvider,
          emailFrom,
          resend: {
            apiKeyConfigured: resendApiKeyRaw.length > 0 || rawPass.startsWith('re_')
          },
          smtp: smtpPayload
        },
        smtp: smtpPayload,
        mfa: {
          expiracaoMinutos: mfaExpiracao,
          maxTentativas: mfaMaxTentativas,
          policy: mfaPolicy,
          emailEnabled: mfaEmailEnabled,
          totpEnabled: mfaTotpEnabled
        },
        autoLock: {
          ativo: autoLockAtivo,
          minutos: autoLockMinutos
        },
        sso: {
          enabled: ssoEnabled,
          allowedDomains: ssoAllowedDomains,
          autoProvision: ssoAutoProvision,
          defaultRole: ssoDefaultRole,
          enforceForDomains: ssoEnforceForDomains,
          azure: {
            enabled: ssoAzureEnabled,
            tenantType: ssoAzureTenantType,
            tenantId: ssoAzureTenantId,
            clientId: ssoAzureClientId,
            clientSecretConfigured: azureSecretRaw.length > 0,
            scopes: ssoAzureScopes,
            securityGroup: ssoAzureSecurityGroup,
            redirectUri: ssoAzureRedirectUri
          }
        },
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.error('[TiController.getConfiguracoesTi Error]:', { correlationId: (req as any).correlationId, error });
      res.status(500).json({ error: 'Erro ao buscar configurações de TI.' });
    }
  }

  /**
   * Salva configurações de TI com validação e criptografia AES-256-GCM
   */
  public static async updateConfiguracoesTi(req: Request, res: Response): Promise<void> {
    try {
      const {
        emailProvider,
        resendApiKey,
        smtpHost,
        smtpPort,
        smtpSecure,
        smtpUser,
        smtpPass,
        emailFrom,
        mfaPolicy,
        mfaEmailEnabled,
        mfaTotpEnabled,
        mfaExpiracaoMinutos,
        mfaMaxTentativas,
        autoLockAtivo,
        autoLockMinutos,
        ssoEnabled,
        ssoAllowedDomains,
        ssoAutoProvision,
        ssoDefaultRole,
        ssoEnforceForDomains,
        ssoAzureEnabled,
        ssoAzureTenantType,
        ssoAzureTenantId,
        ssoAzureClientId,
        ssoAzureClientSecret,
        ssoAzureScopes,
        ssoAzureSecurityGroup,
        ssoAzureRedirectUri
      } = req.body;

      if (emailProvider !== undefined) {
        await ConfigService.set('EMAIL_PROVIDER', String(emailProvider).toUpperCase().trim(), 'Provedor de E-mail (RESEND ou SMTP)');
      }
      if (resendApiKey !== undefined && resendApiKey !== '••••••••••••' && resendApiKey.trim() !== '') {
        const cleanKey = String(resendApiKey).replace(/\s+/g, '');
        await ConfigService.set('RESEND_API_KEY', cleanKey, 'Chave de API do Resend AES-256');
      }
      if (smtpHost !== undefined) await ConfigService.set('SMTP_HOST', String(smtpHost).trim(), 'Servidor SMTP');
      if (smtpPort !== undefined) await ConfigService.set('SMTP_PORT', String(smtpPort).trim(), 'Porta SMTP');
      if (smtpSecure !== undefined) await ConfigService.set('SMTP_SECURE', String(smtpSecure), 'Conexão segura SSL/TLS');
      if (smtpUser !== undefined) await ConfigService.set('SMTP_USER', String(smtpUser).trim(), 'Usuário SMTP');
      if (smtpPass !== undefined && smtpPass !== '••••••••••••' && smtpPass.trim() !== '') {
        const cleanPass = String(smtpPass).replace(/\s+/g, '');
        await ConfigService.set('SMTP_PASS', cleanPass, 'Senha SMTP Criptografada AES-256');
      }
      if (emailFrom !== undefined) await ConfigService.set('EMAIL_FROM', String(emailFrom).trim(), 'Remetente padrão');

      // MFA
      if (mfaPolicy !== undefined) await ConfigService.set('MFA_POLICY', String(mfaPolicy), 'Política de MFA');
      if (mfaEmailEnabled !== undefined) await ConfigService.set('MFA_EMAIL_ENABLED', String(mfaEmailEnabled), 'MFA por E-mail');
      if (mfaTotpEnabled !== undefined) await ConfigService.set('MFA_TOTP_ENABLED', String(mfaTotpEnabled), 'MFA por TOTP App');
      if (mfaExpiracaoMinutos !== undefined) await ConfigService.set('MFA_EXPIRACAO_MINUTOS', String(mfaExpiracaoMinutos), 'Expiração MFA');
      if (mfaMaxTentativas !== undefined) await ConfigService.set('MFA_MAX_TENTATIVAS', String(mfaMaxTentativas), 'Tentativas MFA');

      // Auto-Lock por Inatividade
      if (autoLockAtivo !== undefined) await ConfigService.set('AUTO_LOCK_ATIVO', String(autoLockAtivo), 'Bloqueio de Sessão por Inatividade');
      if (autoLockMinutos !== undefined) await ConfigService.set('AUTO_LOCK_MINUTOS', String(autoLockMinutos), 'Tempo limite de inatividade em minutos');

      // SSO Governance
      if (ssoEnabled !== undefined) await ConfigService.set('SSO_ENABLED', String(ssoEnabled), 'SSO Ativo');
      if (ssoAllowedDomains !== undefined) await ConfigService.set('SSO_ALLOWED_DOMAINS', String(ssoAllowedDomains).trim(), 'Domínios SSO');
      if (ssoAutoProvision !== undefined) await ConfigService.set('SSO_AUTO_PROVISION', String(ssoAutoProvision), 'Auto Provisionamento SSO');
      if (ssoDefaultRole !== undefined) await ConfigService.set('SSO_DEFAULT_ROLE', String(ssoDefaultRole).trim(), 'Perfil Padrão SSO');
      if (ssoEnforceForDomains !== undefined) await ConfigService.set('SSO_ENFORCE_FOR_DOMAINS', String(ssoEnforceForDomains), 'Forçar SSO para Domínios');

      // Azure / Microsoft SSO
      if (ssoAzureEnabled !== undefined) await ConfigService.set('SSO_AZURE_ENABLED', String(ssoAzureEnabled), 'Microsoft Azure SSO');
      if (ssoAzureTenantType !== undefined) await ConfigService.set('SSO_AZURE_TENANT_TYPE', String(ssoAzureTenantType).trim(), 'Azure Tenant Type');
      if (ssoAzureTenantId !== undefined) await ConfigService.set('SSO_AZURE_TENANT_ID', String(ssoAzureTenantId).trim(), 'Azure Tenant ID');
      if (ssoAzureClientId !== undefined) await ConfigService.set('SSO_AZURE_CLIENT_ID', String(ssoAzureClientId).trim(), 'Azure Client ID');
      if (ssoAzureClientSecret !== undefined && ssoAzureClientSecret !== '••••••••••••' && ssoAzureClientSecret.trim() !== '') {
        await ConfigService.set('SSO_AZURE_CLIENT_SECRET', String(ssoAzureClientSecret).trim(), 'Azure Client Secret AES-256');
      }
      if (ssoAzureScopes !== undefined) await ConfigService.set('SSO_AZURE_SCOPES', String(ssoAzureScopes).trim(), 'Azure Scopes');
      if (ssoAzureSecurityGroup !== undefined) await ConfigService.set('SSO_AZURE_SECURITY_GROUP', String(ssoAzureSecurityGroup).trim(), 'Azure Security Group');
      if (ssoAzureRedirectUri !== undefined) await ConfigService.set('SSO_AZURE_REDIRECT_URI', String(ssoAzureRedirectUri).trim(), 'Azure Redirect URI');

      ConfigService.invalidateCache();
      EmailService.resetTransporter();

      res.status(200).json({
        message: 'Configurações de infraestrutura, segurança e SSO atualizadas com sucesso!',
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.error('[TiController.updateConfiguracoesTi Error]:', { correlationId: (req as any).correlationId, error });
      res.status(500).json({ error: 'Erro ao atualizar configurações de TI.' });
    }
  }

  /**
   * Envia e-mail de teste de conectividade
   */
  public static async testarConexaoEmail(req: Request, res: Response): Promise<void> {
    try {
      const { emailDestino } = req.body;
      const RFC5322_EMAIL_REGEX = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$/;
      if (!emailDestino || typeof emailDestino !== 'string' || !RFC5322_EMAIL_REGEX.test(emailDestino.trim()) || emailDestino.includes('\n') || emailDestino.includes('\r')) {
        res.status(400).json({ error: 'E-mail de destino válido (RFC 5322) é obrigatório para o teste.' });
        return;
      }

      const inicio = performance.now();
      const resultado = await EmailService.enviarEmailTeste(
        emailDestino,
        (req as any).user?.nome || 'Administrador TI'
      );
      const latenciaMs = Math.round(performance.now() - inicio);

      if (resultado.success) {
        res.status(200).json({
          success: true,
          message: resultado.message,
          latenciaMs,
          detalhes: resultado.detalhes
        });
      } else {
        res.status(502).json({
          success: false,
          error: resultado.message || 'Falha ao autenticar ou enviar através do servidor SMTP configurado.',
          detalhes: resultado.detalhes
        });
      }
    } catch (error: any) {
      logger.error('[TiController.testarConexaoEmail Error]:', { correlationId: (req as any).correlationId, error });
      res.status(500).json({
        success: false,
        error: 'Erro ao testar conexão SMTP. Verifique as credenciais e tente novamente.'
      });
    }
  }

  /**
   * Obtém métricas e telemetria de saúde do sistema
   */
  public static async getStatusSistema(req: Request, res: Response): Promise<void> {
    try {
      const inicioDb = performance.now();
      await pool.query('SELECT 1');
      const latenciaDbMs = Math.round(performance.now() - inicioDb);

      const memUsage = process.memoryUsage();
      const totalRamMb = Math.round(memUsage.rss / 1024 / 1024);
      const heapUsedMb = Math.round(memUsage.heapUsed / 1024 / 1024);
      const heapTotalMb = Math.round(memUsage.heapTotal / 1024 / 1024);

      const poolTotal = pool.totalCount;
      const poolIdle = pool.idleCount;
      const poolWaiting = pool.waitingCount;

      const wsClients = wsManager.getClientCount();

      res.status(200).json({
        status: 'ONLINE',
        timestamp: new Date().toISOString(),
        uptimeSegundos: Math.round(process.uptime()),
        database: {
          status: 'HEALTHY',
          latenciaMs: latenciaDbMs,
          pool: { total: poolTotal, idle: poolIdle, waiting: poolWaiting }
        },
        memory: {
          rssMb: totalRamMb,
          heapUsedMb,
          heapTotalMb
        },
        websocket: {
          conexoesAtivas: wsClients,
          status: 'CONNECTED'
        },
        server: {
          nodeVersion: process.version,
          platform: process.platform,
          env: process.env.NODE_ENV || 'development'
        }
      });
    } catch (error) {
      logger.error('[TiController.getStatusSistema Error]:', { correlationId: (req as any).correlationId, error });
      res.status(500).json({
        status: 'DEGRADED',
        error: 'Erro ao coletar diagnóstico do sistema.'
      });
    }
  }

  /**
   * Obtém a trilha de auditoria completa de acessos e segurança
   */
  public static async getAuditoriaAcessos(req: Request, res: Response): Promise<void> {
    try {
      const pagina = parseInt(String(req.query.pagina || '1'), 10);
      const limite = parseInt(String(req.query.limite || '25'), 10);
      const tipoEvento = req.query.tipoEvento ? String(req.query.tipoEvento) : undefined;
      const termo = req.query.termo ? String(req.query.termo) : undefined;
      const sucesso = req.query.sucesso !== undefined ? req.query.sucesso === 'true' : undefined;

      const resultado = await AuditService.getLogs({
        pagina,
        limite,
        tipoEvento,
        termo,
        sucesso
      });

      res.status(200).json(resultado);
    } catch (error) {
      logger.error('[TiController.getAuditoriaAcessos Error]:', { correlationId: (req as any).correlationId, error });
      res.status(500).json({ error: 'Erro ao buscar trilha de auditoria de acessos.' });
    }
  }

  /**
   * Obtém histórico de auditoria de códigos MFA legado
   */
  public static async getAuditoriaMfa(req: Request, res: Response): Promise<void> {
    try {
      const result = await pool.query(`
        SELECT 
          m.id,
          m.usuario_id,
          u.nome as usuario_nome,
          u.email as usuario_email,
          u.perfil as usuario_perfil,
          'MFA_EMAIL' as tipo,
          m.criado_em,
          m.expira_em,
          CASE WHEN m.utilizado = true THEN m.expira_em ELSE NULL END as utilizado_em,
          m.utilizado
        FROM auth_mfa_codes m
        LEFT JOIN usuarios u ON u.id = m.usuario_id
        ORDER BY m.criado_em DESC
        LIMIT 50
      `);

      res.status(200).json({
        auditoria: result.rows
      });
    } catch (error) {
      logger.error('[TiController.getAuditoriaMfa Error]:', { correlationId: (req as any).correlationId, error });
      res.status(500).json({ error: 'Erro ao buscar auditoria de MFA.' });
    }
  }
}
