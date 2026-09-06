import { Request, Response } from 'express';
import pool from '../config/db';
import { ConfigService } from '../services/configService';
import { EmailService } from '../services/emailService';
import { wsManager } from '../websocket/wsServer';
import { performance } from 'perf_hooks';

export class TiController {
  /**
   * Obtém as configurações de TI (SMTP e MFA)
   */
  public static async getConfiguracoesTi(req: Request, res: Response): Promise<void> {
    try {
      const smtpHost = await ConfigService.get('SMTP_HOST', process.env.SMTP_HOST || 'smtp.gmail.com');
      const smtpPort = await ConfigService.get('SMTP_PORT', process.env.SMTP_PORT || '587');
      const smtpSecure = await ConfigService.get('SMTP_SECURE', process.env.SMTP_SECURE || 'false');
      const smtpUser = await ConfigService.get('SMTP_USER', process.env.SMTP_USER || '');
      const rawPass = await ConfigService.get('SMTP_PASS', process.env.SMTP_PASS || '');
      const emailFrom = await ConfigService.get('EMAIL_FROM', process.env.EMAIL_FROM || '"SeatMap Corporativo" <nao-responda@seatmap.local>');

      const mfaExpiracao = await ConfigService.getNumber('MFA_EXPIRACAO_MINUTOS', 10);
      const mfaMaxTentativas = await ConfigService.getNumber('MFA_MAX_TENTATIVAS', 3);

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
          expiracaoMinutos: mfaExpiracao,
          maxTentativas: mfaMaxTentativas
        }
      });
    } catch (error) {
      console.error('[TiController.getConfiguracoesTi Error]:', error);
      res.status(500).json({ error: 'Erro ao buscar configurações de TI.' });
    }
  }

  /**
   * Atualiza as configurações de TI (SMTP e MFA) com hot-reload imediato
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
        mfaExpiracaoMinutos,
        mfaMaxTentativas
      } = req.body;

      if (smtpHost !== undefined) {
        await ConfigService.set('SMTP_HOST', String(smtpHost).trim(), 'Servidor SMTP para envio de e-mails');
      }

      if (smtpPort !== undefined) {
        await ConfigService.set('SMTP_PORT', String(smtpPort).trim(), 'Porta do servidor SMTP (587 TLS, 465 SSL)');
      }

      if (smtpSecure !== undefined) {
        await ConfigService.set('SMTP_SECURE', String(smtpSecure), 'Uso de conexão segura SSL/TLS direta');
      }

      if (smtpUser !== undefined) {
        await ConfigService.set('SMTP_USER', String(smtpUser).trim(), 'Usuário/Conta de autenticação SMTP');
      }

      if (smtpPass !== undefined && smtpPass !== '••••••••••••' && smtpPass.trim() !== '') {
        await ConfigService.set('SMTP_PASS', String(smtpPass).trim(), 'Senha ou App Password do servidor SMTP');
      }

      if (emailFrom !== undefined) {
        await ConfigService.set('EMAIL_FROM', String(emailFrom).trim(), 'Remetente padrão dos e-mails institucionais');
      }

      if (mfaExpiracaoMinutos !== undefined) {
        const exp = parseInt(String(mfaExpiracaoMinutos), 10);
        if (!isNaN(exp) && exp > 0) {
          await ConfigService.set('MFA_EXPIRACAO_MINUTOS', String(exp), 'Tempo de expiração do código MFA em minutos');
        }
      }

      if (mfaMaxTentativas !== undefined) {
        const tentativas = parseInt(String(mfaMaxTentativas), 10);
        if (!isNaN(tentativas) && tentativas > 0) {
          await ConfigService.set('MFA_MAX_TENTATIVAS', String(tentativas), 'Número máximo de tentativas incorretas de MFA');
        }
      }

      // Hot-reload do transportador de e-mail
      EmailService.resetTransporter();

      res.status(200).json({
        message: 'Configurações de infraestrutura e segurança atualizadas com sucesso!',
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      console.error('[TiController.updateConfiguracoesTi Error]:', error);
      res.status(500).json({ error: 'Erro ao atualizar configurações de TI.' });
    }
  }

  /**
   * Dispara um teste real de e-mail para o operador de TI conectado
   */
  public static async testarConexaoEmail(req: Request, res: Response): Promise<void> {
    try {
      const user = (req as any).user;
      const targetEmail = req.body.emailDestino || user.email;
      const targetNome = req.body.nomeDestino || user.nome;

      if (!targetEmail) {
        res.status(400).json({ error: 'E-mail de destino não fornecido.' });
        return;
      }

      const resultado = await EmailService.enviarEmailTeste(targetEmail, targetNome);

      if (resultado.success) {
        res.status(200).json({
          success: true,
          message: resultado.message,
          destinatario: targetEmail,
          detalhes: resultado.detalhes
        });
      } else {
        res.status(400).json({
          success: false,
          error: resultado.message,
          detalhes: resultado.detalhes
        });
      }
    } catch (error: any) {
      console.error('[TiController.testarConexaoEmail Error]:', error);
      res.status(500).json({ error: error.message || 'Erro ao executar teste de envio SMTP.' });
    }
  }

  /**
   * Obtém métricas reais de saúde, diagnóstico, latência e conectividade
   */
  public static async getStatusSistema(req: Request, res: Response): Promise<void> {
    try {
      // 1. Latência do PostgreSQL
      const startPg = performance.now();
      await pool.query('SELECT 1');
      const pgLatencyMs = Math.round((performance.now() - startPg) * 10) / 10;

      // 2. Pool de Conexões do PostgreSQL
      const poolInfo = {
        totalConnections: (pool as any).totalCount || 0,
        idleConnections: (pool as any).idleCount || 0,
        waitingRequests: (pool as any).waitingCount || 0
      };

      // 3. WebSockets ativos
      const wsInfo = wsManager.getRoomsInfo();

      // 4. Memória do Processo Node.js
      const memory = process.memoryUsage();
      const memoryFormatted = {
        rssMb: Math.round((memory.rss / (1024 * 1024)) * 10) / 10,
        heapTotalMb: Math.round((memory.heapTotal / (1024 * 1024)) * 10) / 10,
        heapUsedMb: Math.round((memory.heapUsed / (1024 * 1024)) * 10) / 10,
        externalMb: Math.round((memory.external / (1024 * 1024)) * 10) / 10
      };

      // 5. Uptime
      const uptimeSeconds = Math.floor(process.uptime());

      res.status(200).json({
        status: 'OPERATIONAL',
        database: {
          status: 'CONNECTED',
          latencyMs: pgLatencyMs,
          pool: poolInfo
        },
        websockets: {
          activeClients: wsInfo.totalClients,
          activeRooms: wsInfo.activeRooms
        },
        memory: memoryFormatted,
        uptimeSeconds,
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
   * Obtém histórico de auditoria de códigos MFA
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
          'MFA_RH' as tipo,
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
