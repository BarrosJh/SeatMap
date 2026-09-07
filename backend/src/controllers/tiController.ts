import { Request, Response } from 'express';
import pool from '../config/db';
import { ConfigService } from '../services/configService';
import { EmailService } from '../services/emailService';
import { AuditService } from '../services/auditService';
import { wsManager } from '../websocket/wsServer';
import { performance } from 'perf_hooks';

export class TiController {
  /**
   * Obtém as configurações de TI (SMTP, MFA e SSO Corporativo)
   */
  public static async getConfiguracoesTi(req: Request, res: Response): Promise<void> {
    try {
      const smtpHost = await ConfigService.get('SMTP_HOST', process.env.SMTP_HOST || 'smtp.gmail.com');
      const smtpPort = await ConfigService.get('SMTP_PORT', process.env.SMTP_PORT || '587');
      const smtpSecure = await ConfigService.get('SMTP_SECURE', process.env.SMTP_SECURE || 'false');
      const smtpUser = await ConfigService.get('SMTP_USER', process.env.SMTP_USER || '');
      const rawPass = await ConfigService.get('SMTP_PASS', process.env.SMTP_PASS || '');
      const emailFrom = await ConfigService.get('EMAIL_FROM', process.env.EMAIL_FROM || '"SeatMap Corporativo" <nao-responda@seatmap.local>');

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

      // Google Workspace
      const ssoGoogleEnabled = (await ConfigService.get('SSO_GOOGLE_ENABLED', 'false')) === 'true';
      const ssoGoogleClientId = await ConfigService.get('SSO_GOOGLE_CLIENT_ID', '');
      const googleSecretRaw = await ConfigService.get('SSO_GOOGLE_CLIENT_SECRET', '');
      const ssoGoogleHd = await ConfigService.get('SSO_GOOGLE_HD', '');
      const ssoGoogleRedirectUri = await ConfigService.get('SSO_GOOGLE_REDIRECT_URI', '');

      // Microsoft Entra ID / Azure AD
      const ssoAzureEnabled = (await ConfigService.get('SSO_AZURE_ENABLED', 'false')) === 'true';
      const ssoAzureTenantType = await ConfigService.get('SSO_AZURE_TENANT_TYPE', 'single_tenant');
      const ssoAzureTenantId = await ConfigService.get('SSO_AZURE_TENANT_ID', '');
      const ssoAzureClientId = await ConfigService.get('SSO_AZURE_CLIENT_ID', '');
      const azureSecretRaw = await ConfigService.get('SSO_AZURE_CLIENT_SECRET', '');
      const ssoAzureScopes = await ConfigService.get('SSO_AZURE_SCOPES', 'openid profile email User.Read');
      const ssoAzureSecurityGroup = await ConfigService.get('SSO_AZURE_SECURITY_GROUP', '');
      const ssoAzureRedirectUri = await ConfigService.get('SSO_AZURE_REDIRECT_URI', '');

      // Okta / SAML 2.0
      const ssoOktaEnabled = (await ConfigService.get('SSO_OKTA_ENABLED', 'false')) === 'true';
      const ssoOktaDomain = await ConfigService.get('SSO_OKTA_DOMAIN', '');
      const ssoOktaClientId = await ConfigService.get('SSO_OKTA_CLIENT_ID', '');
      const oktaSecretRaw = await ConfigService.get('SSO_OKTA_CLIENT_SECRET', '');

      res.status(200).json({
        smtp: {
          host: smtpHost,
          port: parseInt(smtpPort, 10),
          secure: smtpSecure === 'true' || smtpPort === '465',
          user: smtpUser,
          passConfigurada: rawPass.length > 0,
          passMasked: rawPass.length > 0 ? '••••••••••••' : '',
          from: emailFrom
        },
        mfa: {
          policy: mfaPolicy,
          emailEnabled: mfaEmailEnabled,
          totpEnabled: mfaTotpEnabled,
          expiracaoMinutos: mfaExpiracao,
          maxTentativas: mfaMaxTentativas
        },
        sso: {
          enabled: ssoEnabled,
          allowedDomains: ssoAllowedDomains,
          autoProvision: ssoAutoProvision,
          defaultRole: ssoDefaultRole,
          enforceForDomains: ssoEnforceForDomains,
          google: {
            enabled: ssoGoogleEnabled,
            clientId: ssoGoogleClientId,
            secretConfigured: googleSecretRaw.length > 0,
            hd: ssoGoogleHd,
            redirectUri: ssoGoogleRedirectUri
          },
          azure: {
            enabled: ssoAzureEnabled,
            tenantType: ssoAzureTenantType,
            tenantId: ssoAzureTenantId,
            clientId: ssoAzureClientId,
            secretConfigured: azureSecretRaw.length > 0,
            scopes: ssoAzureScopes,
            securityGroup: ssoAzureSecurityGroup,
            redirectUri: ssoAzureRedirectUri
          },
          okta: {
            enabled: ssoOktaEnabled,
            domain: ssoOktaDomain,
            clientId: ssoOktaClientId,
            secretConfigured: oktaSecretRaw.length > 0
          }
        }
      });
    } catch (error) {
      console.error('[TiController.getConfiguracoesTi Error]:', error);
      res.status(500).json({ error: 'Erro ao buscar configurações de TI.' });
    }
  }

  /**
   * Atualiza as configurações de TI (SMTP, MFA e SSO)
   */
  public static async updateConfiguracoesTi(req: Request, res: Response): Promise<void> {
    try {
      const {
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
        ssoEnabled,
        ssoAllowedDomains,
        ssoAutoProvision,
        ssoDefaultRole,
        ssoEnforceForDomains,
        ssoGoogleEnabled,
        ssoGoogleClientId,
        ssoGoogleClientSecret,
        ssoGoogleHd,
        ssoGoogleRedirectUri,
        ssoAzureEnabled,
        ssoAzureTenantType,
        ssoAzureTenantId,
        ssoAzureClientId,
        ssoAzureClientSecret,
        ssoAzureScopes,
        ssoAzureSecurityGroup,
        ssoAzureRedirectUri,
        ssoOktaEnabled,
        ssoOktaDomain,
        ssoOktaClientId,
        ssoOktaClientSecret
      } = req.body;

      if (smtpHost !== undefined) await ConfigService.set('SMTP_HOST', String(smtpHost).trim(), 'Servidor SMTP');
      if (smtpPort !== undefined) await ConfigService.set('SMTP_PORT', String(smtpPort).trim(), 'Porta SMTP');
      if (smtpSecure !== undefined) await ConfigService.set('SMTP_SECURE', String(smtpSecure), 'Conexão segura SSL/TLS');
      if (smtpUser !== undefined) await ConfigService.set('SMTP_USER', String(smtpUser).trim(), 'Usuário SMTP');
      if (smtpPass !== undefined && smtpPass !== '••••••••••••' && smtpPass.trim() !== '') {
        await ConfigService.set('SMTP_PASS', String(smtpPass).trim(), 'Senha SMTP Criptografada AES-256');
      }
      if (emailFrom !== undefined) await ConfigService.set('EMAIL_FROM', String(emailFrom).trim(), 'Remetente padrão');

      // MFA
      if (mfaPolicy !== undefined) await ConfigService.set('MFA_POLICY', String(mfaPolicy), 'Política de MFA');
      if (mfaEmailEnabled !== undefined) await ConfigService.set('MFA_EMAIL_ENABLED', String(mfaEmailEnabled), 'MFA por E-mail');
      if (mfaTotpEnabled !== undefined) await ConfigService.set('MFA_TOTP_ENABLED', String(mfaTotpEnabled), 'MFA por TOTP App');
      if (mfaExpiracaoMinutos !== undefined) await ConfigService.set('MFA_EXPIRACAO_MINUTOS', String(mfaExpiracaoMinutos), 'Expiração MFA');
      if (mfaMaxTentativas !== undefined) await ConfigService.set('MFA_MAX_TENTATIVAS', String(mfaMaxTentativas), 'Tentativas MFA');

      // SSO Governance
      if (ssoEnabled !== undefined) await ConfigService.set('SSO_ENABLED', String(ssoEnabled), 'SSO Ativo');
      if (ssoAllowedDomains !== undefined) await ConfigService.set('SSO_ALLOWED_DOMAINS', String(ssoAllowedDomains).trim(), 'Domínios SSO');
      if (ssoAutoProvision !== undefined) await ConfigService.set('SSO_AUTO_PROVISION', String(ssoAutoProvision), 'Auto Provisionamento SSO');
      if (ssoDefaultRole !== undefined) await ConfigService.set('SSO_DEFAULT_ROLE', String(ssoDefaultRole).trim(), 'Perfil Padrão SSO');
      if (ssoEnforceForDomains !== undefined) await ConfigService.set('SSO_ENFORCE_FOR_DOMAINS', String(ssoEnforceForDomains), 'Forçar SSO para Domínios');

      // Google SSO
      if (ssoGoogleEnabled !== undefined) await ConfigService.set('SSO_GOOGLE_ENABLED', String(ssoGoogleEnabled), 'Google SSO');
      if (ssoGoogleClientId !== undefined) await ConfigService.set('SSO_GOOGLE_CLIENT_ID', String(ssoGoogleClientId).trim(), 'Google Client ID');
      if (ssoGoogleClientSecret !== undefined && ssoGoogleClientSecret !== '••••••••••••' && ssoGoogleClientSecret.trim() !== '') {
        await ConfigService.set('SSO_GOOGLE_CLIENT_SECRET', String(ssoGoogleClientSecret).trim(), 'Google Client Secret AES-256');
      }
      if (ssoGoogleHd !== undefined) await ConfigService.set('SSO_GOOGLE_HD', String(ssoGoogleHd).trim(), 'Google Hosted Domain');
      if (ssoGoogleRedirectUri !== undefined) await ConfigService.set('SSO_GOOGLE_REDIRECT_URI', String(ssoGoogleRedirectUri).trim(), 'Google Redirect URI');

      // Azure SSO
      if (ssoAzureEnabled !== undefined) await ConfigService.set('SSO_AZURE_ENABLED', String(ssoAzureEnabled), 'Azure SSO');
      if (ssoAzureTenantType !== undefined) await ConfigService.set('SSO_AZURE_TENANT_TYPE', String(ssoAzureTenantType).trim(), 'Azure Tenant Type');
      if (ssoAzureTenantId !== undefined) await ConfigService.set('SSO_AZURE_TENANT_ID', String(ssoAzureTenantId).trim(), 'Azure Tenant ID');
      if (ssoAzureClientId !== undefined) await ConfigService.set('SSO_AZURE_CLIENT_ID', String(ssoAzureClientId).trim(), 'Azure Client ID');
      if (ssoAzureClientSecret !== undefined && ssoAzureClientSecret !== '••••••••••••' && ssoAzureClientSecret.trim() !== '') {
        await ConfigService.set('SSO_AZURE_CLIENT_SECRET', String(ssoAzureClientSecret).trim(), 'Azure Client Secret AES-256');
      }
      if (ssoAzureScopes !== undefined) await ConfigService.set('SSO_AZURE_SCOPES', String(ssoAzureScopes).trim(), 'Azure Scopes');
      if (ssoAzureSecurityGroup !== undefined) await ConfigService.set('SSO_AZURE_SECURITY_GROUP', String(ssoAzureSecurityGroup).trim(), 'Azure Security Group');
      if (ssoAzureRedirectUri !== undefined) await ConfigService.set('SSO_AZURE_REDIRECT_URI', String(ssoAzureRedirectUri).trim(), 'Azure Redirect URI');

      // Okta SSO
      if (ssoOktaEnabled !== undefined) await ConfigService.set('SSO_OKTA_ENABLED', String(ssoOktaEnabled), 'Okta SSO');
      if (ssoOktaDomain !== undefined) await ConfigService.set('SSO_OKTA_DOMAIN', String(ssoOktaDomain).trim(), 'Okta Domain / Issuer');
      if (ssoOktaClientId !== undefined) await ConfigService.set('SSO_OKTA_CLIENT_ID', String(ssoOktaClientId).trim(), 'Okta Client ID');
      if (ssoOktaClientSecret !== undefined && ssoOktaClientSecret !== '••••••••••••' && ssoOktaClientSecret.trim() !== '') {
        await ConfigService.set('SSO_OKTA_CLIENT_SECRET', String(ssoOktaClientSecret).trim(), 'Okta Client Secret AES-256');
      }

      EmailService.resetTransporter();

      res.status(200).json({
        message: 'Configurações de infraestrutura, segurança e SSO atualizadas com sucesso!',
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      console.error('[TiController.updateConfiguracoesTi Error]:', error);
      res.status(500).json({ error: 'Erro ao atualizar configurações de TI.' });
    }
  }

  /**
   * Envia e-mail de teste de conectividade
   */
  public static async testarConexaoEmail(req: Request, res: Response): Promise<void> {
    try {
      const { emailDestino } = req.body;
      if (!emailDestino || !emailDestino.includes('@')) {
        res.status(400).json({ error: 'E-mail de destino válido é obrigatório para o teste.' });
        return;
      }

      const inicio = performance.now();
      const enviado = await EmailService.enviarEmailGenerico(
        emailDestino,
        '🧪 Teste de Conectividade SMTP — SeatMap Enterprise',
        `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 560px; margin: 0 auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 28px;">
          <h2 style="color: #0f172a; margin-top: 0;">Conectividade SMTP Validada!</h2>
          <p style="color: #334155; font-size: 14px;">Este e-mail confirma que as credenciais do servidor SMTP foram validadas com sucesso pelo módulo de infraestrutura do <strong>SeatMap Enterprise</strong>.</p>
          <div style="background: #f8fafc; border-left: 4px solid #16a34a; padding: 12px 16px; border-radius: 4px; margin: 20px 0; font-size: 13px; color: #166534;">
            ✓ Criptografia AES-256-GCM ativa at-rest<br/>
            ✓ Conexão autenticada e entregue em tempo real
          </div>
          <p style="color: #94a3b8; font-size: 12px; margin-bottom: 0;">Disparado em: ${new Date().toLocaleString('pt-BR')}</p>
        </div>
        `
      );
      const latenciaMs = Math.round(performance.now() - inicio);

      if (enviado) {
        res.status(200).json({
          success: true,
          message: `E-mail de teste disparado com sucesso para ${emailDestino}.`,
          latenciaMs
        });
      } else {
        res.status(502).json({
          success: false,
          error: 'Falha ao autenticar ou enviar através do servidor SMTP configurado.'
        });
      }
    } catch (error: any) {
      console.error('[TiController.testarConexaoEmail Error]:', error);
      res.status(500).json({
        success: false,
        error: error.message || 'Erro inesperado ao testar conexão SMTP.'
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
      console.error('[TiController.getStatusSistema Error]:', error);
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
      console.error('[TiController.getAuditoriaAcessos Error]:', error);
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
      console.error('[TiController.getAuditoriaMfa Error]:', error);
      res.status(500).json({ error: 'Erro ao buscar auditoria de MFA.' });
    }
  }
}
