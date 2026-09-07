import pool from '../config/db';

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
  | 'REFRESH_TOKEN_ROTACAO'
  | 'REFRESH_TOKEN_REUSO_SUSPEITO'
  | 'SENHA_ALTERADA'
  | 'SENHA_RESET_SOLICITADO'
  | 'SENHA_RESET_CONCLUIDO';

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
  /**
   * Registra um evento de segurança/acesso no banco de forma assíncrona
   */
  public static log(params: AuditLogParams): void {
    const {
      usuarioId = null,
      loginInformado = '',
      tipoEvento,
      sucesso,
      ip = 'Desconhecido',
      userAgent = 'Desconhecido',
      detalhes = {}
    } = params;

    // Executa em segundo plano sem bloquear a resposta HTTP do usuário
    pool.query(`
      INSERT INTO auditoria_acessos (
        usuario_id, login_informado, tipo_evento, sucesso, ip, user_agent, detalhes, criado_em
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
    `, [
      usuarioId,
      loginInformado ? loginInformado.substring(0, 255) : null,
      tipoEvento,
      sucesso,
      ip ? ip.substring(0, 100) : 'Desconhecido',
      userAgent || 'Desconhecido',
      JSON.stringify(detalhes)
    ]).catch(err => {
      console.error('[AuditService.log Error]: Falha ao persistir log de auditoria:', err);
    });
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

    if (options.termo) {
      conditions.push(`(a.login_informado ILIKE $${idx} OR u.nome ILIKE $${idx} OR u.email ILIKE $${idx} OR a.ip ILIKE $${idx})`);
      values.push(`%${options.termo}%`);
      idx++;
    }

    if (options.dataInicio) {
      conditions.push(`a.criado_em >= $${idx++}`);
      values.push(options.dataInicio);
    }

    if (options.dataFim) {
      conditions.push(`a.criado_em <= $${idx++}`);
      values.push(options.dataFim);
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    const countQuery = `
      SELECT COUNT(*) AS total
      FROM auditoria_acessos a
      LEFT JOIN usuarios u ON a.usuario_id = u.id
      ${whereClause}
    `;

    const dataQuery = `
      SELECT 
        a.id,
        a.usuario_id AS "usuarioId",
        u.nome AS "usuarioNome",
        u.email AS "usuarioEmail",
        u.perfil AS "usuarioPerfil",
        a.login_informado AS "loginInformado",
        a.tipo_evento AS "tipoEvento",
        a.sucesso,
        a.ip,
        a.user_agent AS "userAgent",
        a.detalhes,
        a.criado_em AS "criadoEm"
      FROM auditoria_acessos a
      LEFT JOIN usuarios u ON a.usuario_id = u.id
      ${whereClause}
      ORDER BY a.criado_em DESC
      LIMIT $${idx++} OFFSET $${idx++}
    `;

    values.push(limite, offset);

    const [countRes, dataRes] = await Promise.all([
      pool.query(countQuery, values.slice(0, idx - 3)),
      pool.query(dataQuery, values)
    ]);

    const total = parseInt(countRes.rows[0]?.total || '0', 10);
    const totalPaginas = Math.ceil(total / limite);

    return {
      pagina,
      limite,
      total,
      totalPaginas,
      logs: dataRes.rows
    };
  }

  /**
   * Helper para extrair IP do cliente a partir da Request do Express
   */
  public static getClientIp(req: any): string {
    const forwarded = req.headers['x-forwarded-for'];
    let ip = '';
    if (forwarded) {
      ip = (typeof forwarded === 'string' ? forwarded : forwarded[0]).split(',')[0].trim();
    } else {
      ip = req.ip || req.socket?.remoteAddress || '127.0.0.1';
    }

    // Normaliza IPv6 localhost
    if (ip === '::1') {
      return '127.0.0.1';
    }

    // Remove prefixo IPv6-mapped IPv4 (ex: ::ffff:172.18.0.1 -> 172.18.0.1)
    if (ip.startsWith('::ffff:')) {
      return ip.substring(7);
    }

    return ip;
  }

  /**
   * Helper para extrair User Agent
   */
  public static getUserAgent(req: any): string {
    return req.headers['user-agent'] || 'Desconhecido';
  }
}

