import pool from '../config/db';
import { logger } from '../utils/logger';

export type TipoEventoAuditoria =
  | 'LOGIN_SUCESSO'
  | 'LOGIN_FALHA_SENHA'
  | 'LOGIN_CONTA_BLOQUEADA'
  | 'LOGIN_USUARIO_INATIVO'
  | 'LOGIN_USUARIO_NAO_ENCONTRADO'
  | 'LOGIN_SSO_EXIGIDO'
  | 'MFA_SOLICITADO_EMAIL'
  | 'MFA_VALIDADO_EMAIL'
  | 'MFA_FALHA_EMAIL'
  | 'TOTP_SOLICITADO'
  | 'TOTP_ATIVADO'
  | 'TOTP_DESATIVADO'
  | 'TOTP_VALIDADO'
  | 'TOTP_FALHA'
  | 'TOTP_BACKUP_USADO'
  | 'SSO_LOGIN_SUCESSO'
  | 'SSO_LOGIN_FALHA'
  | 'SSO_FALHA'
  | 'SSO_DOMINIO_BLOQUEADO'
  | 'SSO_PROVISIONAMENTO_DESATIVADO'
  | 'SSO_USUARIO_PROVISIONADO'
  | 'LOGOUT'
  | 'LOGOUT_GLOBAL'
  | 'SESSAO_SIMULTANEA_REVOGADA'
  | 'REFRESH_TOKEN_ROTACAO'
  | 'REFRESH_TOKEN_REUSO_SUSPEITO'
  | 'SENHA_ALTERADA'
  | 'SENHA_RESET_SOLICITADO'
  | 'SENHA_RESET_CONCLUIDO'
  | 'USUARIO_CRIADO'
  | 'USUARIO_ATUALIZADO'
  | 'USUARIO_STATUS_ALTERADO'
  | 'SENHA_RESETADA'
  | 'CONFIGURACAO_ALTERADA'
  | 'WEBAUTHN_REGISTRADO'
  | 'WEBAUTHN_LOGIN_SUCESSO'
  | 'WEBAUTHN_LOGIN_FALHA'
  | 'ABUSO_API_BLOQUEADO'
  | 'ABUSO_EXPORTACAO_BLOQUEADO'
  | 'ABUSO_LOTE_BLOQUEADO';

export interface AuditLogParams {
  usuarioId?: number | null;
  loginInformado?: string;
  tipoEvento: TipoEventoAuditoria;
  sucesso: boolean;
  ip?: string;
  userAgent?: string;
  detalhes?: Record<string, any>;
}

export class AuditService {
  private static buffer: AuditLogParams[] = [];
  private static flushTimer: NodeJS.Timeout | null = null;
  private static isFlushing = false;
  private static readonly MAX_BUFFER_SIZE = 50;
  private static readonly FLUSH_INTERVAL_MS = 1500;

  static {
    // Inicializa timer de flush periódico para garantir persistência contínua
    this.startFlushTimer();
  }

  private static startFlushTimer(): void {
    if (!this.flushTimer) {
      this.flushTimer = setInterval(() => {
        this.flush().catch(err => {
          logger.error('[AuditService.flushTimer] Falha no flush periódico de auditoria:', { error: err });
        });
      }, this.FLUSH_INTERVAL_MS);
      if (typeof this.flushTimer.unref === 'function') {
        this.flushTimer.unref();
      }
    }
  }

  /**
   * Adiciona um evento de auditoria ao buffer em memória para gravação em lote (REL-01).
   */
  public static log(params: AuditLogParams): void {
    this.buffer.push(params);

    // Se o buffer atingir o limite máximo, dispara flush imediato
    if (this.buffer.length >= this.MAX_BUFFER_SIZE) {
      this.flush().catch(err => {
        logger.error('[AuditService.log] Falha no flush síncrono por estouro de buffer:', { error: err });
      });
    }
  }

  /**
   * Executa a gravação em lote (Batch Insert) de todos os eventos retidos no buffer.
   */
  public static async flush(): Promise<void> {
    if (this.buffer.length === 0 || this.isFlushing) {
      return;
    }

    this.isFlushing = true;
    const items = this.buffer.splice(0, this.buffer.length);

    try {
      // Monta query parametrizada de inserção em lote
      const values: any[] = [];
      const rowPlaceholders: string[] = [];

      items.forEach((item, index) => {
        const offset = index * 7;
        rowPlaceholders.push(`($${offset + 1}, $${offset + 2}, $${offset + 3}, $${offset + 4}, $${offset + 5}, $${offset + 6}, $${offset + 7}, NOW())`);
        values.push(
          item.usuarioId || null,
          item.loginInformado ? item.loginInformado.substring(0, 255) : null,
          item.tipoEvento,
          item.sucesso,
          item.ip ? item.ip.substring(0, 100) : 'Desconhecido',
          item.userAgent || 'Desconhecido',
          JSON.stringify(item.detalhes || {})
        );
      });

      const query = `
        INSERT INTO auditoria_acessos (
          usuario_id, login_informado, tipo_evento, sucesso, ip, user_agent, detalhes, criado_em
        ) VALUES ${rowPlaceholders.join(', ')}
      `;

      await pool.query(query, values);
    } catch (err) {
      logger.error('[AuditService.flush Error]: Falha ao persistir lote de auditoria:', { error: err, count: items.length });
    } finally {
      this.isFlushing = false;
    }
  }

  /**
   * Finaliza o serviço de auditoria aguardando o flush do buffer durante o graceful shutdown.
   */
  public static async shutdown(): Promise<void> {
    if (this.flushTimer) {
      clearInterval(this.flushTimer);
      this.flushTimer = null;
    }
    await this.flush();
  }

  /**
   * Consulta a trilha de auditoria com paginação e filtros
   */
  public static async getLogs(options: {
    pagina?: number;
    limite?: number;
    tipoEvento?: string;
    sucesso?: boolean;
    termo?: string;
    dataInicio?: string;
    dataFim?: string;
  }) {
    const pagina = Math.max(1, options.pagina || 1);
    const limite = Math.min(100, Math.max(10, options.limite || 30));
    const offset = (pagina - 1) * limite;

    const conditions: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (options.tipoEvento) {
      conditions.push(`a.tipo_evento = $${idx++}`);
      values.push(options.tipoEvento);
    }

    if (options.sucesso !== undefined) {
      conditions.push(`a.sucesso = $${idx++}`);
      values.push(options.sucesso);
    }

    if (options.termo && options.termo.trim().length > 0) {
      conditions.push(`(
        a.login_informado ILIKE $${idx} OR 
        u.nome ILIKE $${idx} OR 
        u.email ILIKE $${idx} OR 
        a.ip ILIKE $${idx}
      )`);
      values.push(`%${options.termo.trim()}%`);
      idx++;
    }

    if (options.dataInicio) {
      conditions.push(`a.criado_em >= $${idx++}`);
      values.push(new Date(`${options.dataInicio}T00:00:00`));
    }

    if (options.dataFim) {
      conditions.push(`a.criado_em <= $${idx++}`);
      values.push(new Date(`${options.dataFim}T23:59:59`));
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    const countQuery = `
      SELECT COUNT(*)::int as total
      FROM auditoria_acessos a
      LEFT JOIN usuarios u ON a.usuario_id = u.id
      ${whereClause}
    `;

    const dataQuery = `
      SELECT 
        a.id,
        a.usuario_id,
        a.login_informado,
        a.tipo_evento,
        a.sucesso,
        a.ip,
        a.user_agent,
        a.detalhes,
        a.criado_em,
        u.nome as usuario_nome,
        u.email as usuario_email,
        u.perfil as usuario_perfil,
        u.matricula as usuario_matricula
      FROM auditoria_acessos a
      LEFT JOIN usuarios u ON a.usuario_id = u.id
      ${whereClause}
      ORDER BY a.criado_em DESC
      LIMIT $${idx++} OFFSET $${idx++}
    `;

    const countRes = await pool.query(countQuery, values);
    const total = countRes.rows[0]?.total || 0;

    values.push(limite, offset);
    const dataRes = await pool.query(dataQuery, values);

    return {
      pagina,
      limite,
      total,
      totalPaginas: Math.ceil(total / limite),
      logs: dataRes.rows
    };
  }

  public static getClientIp(req: any): string {
    const forwarded = req.headers['x-forwarded-for'];
    if (forwarded && typeof forwarded === 'string') {
      return forwarded.split(',')[0].trim();
    }
    return req.socket?.remoteAddress || req.ip || '127.0.0.1';
  }

  public static getUserAgent(req: any): string {
    return req.headers['user-agent'] || 'Desconhecido';
  }
}
