import pool from '../config/db';
import { DateTime } from 'luxon';
import { normalizeIsoDate } from '../utils/workWeekUtils';

export class RelatorioService {
  private static readonly DATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;

  /**
   * Helper para construir cláusula WHERE e parâmetros dinâmicos com validação estrita de datas
   */
  public static buildWhereClause(query: any) {
    const { dataInicio: rawInicio, dataFim: rawFim } = query;

    if (rawInicio && (typeof rawInicio !== 'string' || !RelatorioService.DATE_REGEX.test(rawInicio) || !DateTime.fromISO(rawInicio).isValid)) {
      const err: any = new Error('Parâmetro dataInicio inválido. Utilize o formato YYYY-MM-DD.');
      err.statusCode = 400;
      throw err;
    }

    if (rawFim && (typeof rawFim !== 'string' || !RelatorioService.DATE_REGEX.test(rawFim) || !DateTime.fromISO(rawFim).isValid)) {
      const err: any = new Error('Parâmetro dataFim inválido. Utilize o formato YYYY-MM-DD.');
      err.statusCode = 400;
      throw err;
    }

    const dataInicio = (rawInicio as string) || DateTime.now().setZone('America/Sao_Paulo').startOf('month').toISODate()!;
    const dataFim = (rawFim as string) || DateTime.now().setZone('America/Sao_Paulo').toISODate()!;
    const escritorioId = query.escritorioId as string;
    const departamentoId = query.departamentoId as string;
    const status = query.status as string;
    const checkinStatus = query.checkinStatus as string;
    const busca = query.busca as string;

    const conditions: string[] = ['r.data_reserva >= $1 AND r.data_reserva <= $2'];
    const params: any[] = [dataInicio, dataFim];
    let paramIndex = 3;

    if (escritorioId && escritorioId !== 'todos') {
      conditions.push(`e.id = $${paramIndex}`);
      params.push(parseInt(escritorioId, 10));
      paramIndex++;
    }

    if (departamentoId && departamentoId !== 'todos') {
      conditions.push(`u.departamento_id = $${paramIndex}`);
      params.push(parseInt(departamentoId, 10));
      paramIndex++;
    }

    if (status && status !== 'todos') {
      conditions.push(`r.status = $${paramIndex}`);
      params.push(status);
      paramIndex++;
    }

    if (checkinStatus && checkinStatus !== 'todos') {
      if (checkinStatus === 'confirmado') {
        conditions.push(`r.checkin_realizado = true`);
      } else if (checkinStatus === 'pendente') {
        conditions.push(`r.checkin_realizado = false AND r.status = 'ATIVA' AND r.data_reserva >= CURRENT_DATE`);
      } else if (checkinStatus === 'noshow') {
        conditions.push(`(r.status = 'EXPIRADA_NOSHOW' OR (r.data_reserva < CURRENT_DATE AND r.checkin_realizado = false AND r.status = 'ATIVA'))`);
      }
    }

    if (busca && busca.trim().length > 0) {
      const term = `%${busca.trim()}%`;
      conditions.push(`(u.nome ILIKE $${paramIndex} OR u.matricula ILIKE $${paramIndex} OR u.email ILIKE $${paramIndex} OR c.identificador ILIKE $${paramIndex} OR r.codigo_comprovante ILIKE $${paramIndex})`);
      params.push(term);
      paramIndex++;
    }

    return {
      whereClause: conditions.join(' AND '),
      params,
      dataInicio,
      dataFim
    };
  }

  /**
   * Obtém métricas e KPIs analíticos do período
   */
  public static async getAnalytics(query: any) {
    const { whereClause, params, dataInicio, dataFim } = RelatorioService.buildWhereClause(query);

    // 1. Resumo Geral de Reservas & Ocupação
    const resumoQuery = `
      SELECT
        COUNT(r.id)::int AS total_reservas,
        COUNT(CASE WHEN r.checkin_realizado = true THEN 1 END)::int AS total_checkins,
        COUNT(CASE WHEN r.status = 'CANCELADA' THEN 1 END)::int AS total_canceladas,
        COUNT(CASE WHEN r.status = 'EXPIRADA_NOSHOW' OR (r.data_reserva < CURRENT_DATE AND r.checkin_realizado = false AND r.status = 'ATIVA') THEN 1 END)::int AS total_noshows,
        COUNT(CASE WHEN r.status = 'ATIVA' AND r.checkin_realizado = false AND r.data_reserva >= CURRENT_DATE THEN 1 END)::int AS total_pendentes
      FROM reservas r
      JOIN usuarios u ON r.usuario_id = u.id
      JOIN cadeiras c ON r.cadeira_id = c.id
      JOIN baias b ON c.baia_id = b.id
      JOIN escritorios e ON b.escritorio_id = e.id
      WHERE ${whereClause}
    `;
    const resumoResult = await pool.query(resumoQuery, params);
    const resumo = resumoResult.rows[0] || {
      total_reservas: 0,
      total_checkins: 0,
      total_canceladas: 0,
      total_noshows: 0,
      total_pendentes: 0
    };

    const totalCheckins = resumo.total_checkins;
    const totalReservas = resumo.total_reservas;
    const taxaPresenca = totalReservas > 0 ? Number(((totalCheckins / totalReservas) * 100).toFixed(1)) : 0;
    const taxaNoShow = totalReservas > 0 ? Number(((resumo.total_noshows / totalReservas) * 100).toFixed(1)) : 0;

    // 2. Agrupamento por Escritório
    const escritorioQuery = `
      SELECT
        e.id,
        e.nome AS escritorio,
        e.cidade,
        COUNT(r.id)::int AS total_reservas,
        COUNT(CASE WHEN r.checkin_realizado = true THEN 1 END)::int AS total_checkins,
        COUNT(CASE WHEN r.status = 'EXPIRADA_NOSHOW' OR (r.data_reserva < CURRENT_DATE AND r.checkin_realizado = false AND r.status = 'ATIVA') THEN 1 END)::int AS total_noshows,
        COUNT(DISTINCT c.id)::int AS total_mesas_utilizadas
      FROM reservas r
      JOIN usuarios u ON r.usuario_id = u.id
      JOIN cadeiras c ON r.cadeira_id = c.id
      JOIN baias b ON c.baia_id = b.id
      JOIN escritorios e ON b.escritorio_id = e.id
      WHERE ${whereClause}
      GROUP BY e.id, e.nome, e.cidade
      ORDER BY total_reservas DESC
    `;
    const escritorioResult = await pool.query(escritorioQuery, params);

    // 3. Agrupamento por Departamento
    const deptoQuery = `
      SELECT
        COALESCE(d.nome, 'Sem Departamento') AS departamento,
        COUNT(r.id)::int AS total_reservas,
        COUNT(CASE WHEN r.checkin_realizado = true THEN 1 END)::int AS total_checkins,
        COUNT(CASE WHEN r.status = 'EXPIRADA_NOSHOW' OR (r.data_reserva < CURRENT_DATE AND r.checkin_realizado = false AND r.status = 'ATIVA') THEN 1 END)::int AS total_noshows
      FROM reservas r
      JOIN usuarios u ON r.usuario_id = u.id
      LEFT JOIN departamentos d ON u.departamento_id = d.id
      JOIN cadeiras c ON r.cadeira_id = c.id
      JOIN baias b ON c.baia_id = b.id
      JOIN escritorios e ON b.escritorio_id = e.id
      WHERE ${whereClause}
      GROUP BY d.nome
      ORDER BY total_reservas DESC
    `;
    const deptoResult = await pool.query(deptoQuery, params);

    // 4. Tendência Diária no Período
    const diarioQuery = `
      SELECT
        r.data_reserva,
        COUNT(r.id)::int AS total_reservas,
        COUNT(CASE WHEN r.checkin_realizado = true THEN 1 END)::int AS total_checkins,
        COUNT(CASE WHEN r.status IN ('EXPIRADA_NOSHOW', 'CANCELADA_POR_FALTA') OR (r.data_reserva < CURRENT_DATE AND r.checkin_realizado = false AND r.status = 'ATIVA') THEN 1 END)::int AS total_noshows
      FROM reservas r
      JOIN usuarios u ON r.usuario_id = u.id
      JOIN cadeiras c ON r.cadeira_id = c.id
      JOIN baias b ON c.baia_id = b.id
      JOIN escritorios e ON b.escritorio_id = e.id
      WHERE ${whereClause}
      GROUP BY r.data_reserva
      ORDER BY r.data_reserva ASC
    `;
    const diarioResult = await pool.query(diarioQuery, params);

    const diarioFormatado = diarioResult.rows.map((row: any) => ({
      data: normalizeIsoDate(row.data_reserva),
      totalReservas: row.total_reservas,
      totalCheckins: row.total_checkins,
      totalNoShows: row.total_noshows
    }));

    return {
      kpis: {
        totalReservas,
        totalCheckins,
        totalCanceladas: resumo.total_canceladas,
        totalNoShows: resumo.total_noshows,
        totalPendentes: resumo.total_pendentes,
        taxaPresenca,
        taxaNoShow
      },
      porEscritorio: escritorioResult.rows,
      porDepartamento: deptoResult.rows,
      tendenciaDiaria: diarioFormatado,
      periodo: { dataInicio, dataFim }
    };
  }

  /**
   * Obtém listagem paginada para tabela de relatórios
   */
  public static async getDadosRelatorio(query: any) {
    const { whereClause, params } = RelatorioService.buildWhereClause(query);

    const page = parseInt(query.page as string || '1', 10);
    const limit = parseInt(query.limit as string || '50', 10);
    const offset = (page - 1) * limit;

    const countQuery = `
      SELECT COUNT(r.id)::int AS total
      FROM reservas r
      JOIN usuarios u ON r.usuario_id = u.id
      JOIN cadeiras c ON r.cadeira_id = c.id
      JOIN baias b ON c.baia_id = b.id
      JOIN escritorios e ON b.escritorio_id = e.id
      WHERE ${whereClause}
    `;
    const countResult = await pool.query(countQuery, params);
    const total = countResult.rows[0]?.total || 0;

    const dataParams = [...params, limit, offset];
    const limitIndex = params.length + 1;
    const offsetIndex = params.length + 2;

    const dataQuery = `
      SELECT
        r.id,
        r.data_reserva,
        r.status,
        r.checkin_realizado,
        r.checkin_em,
        r.codigo_comprovante,
        r.criado_em,
        u.id AS usuario_id,
        u.nome AS usuario_nome,
        u.matricula AS usuario_matricula,
        u.email AS usuario_email,
        COALESCE(d.nome, 'Sem Departamento') AS departamento_nome,
        e.id AS escritorio_id,
        e.nome AS escritorio_nome,
        e.cidade AS escritorio_cidade,
        b.nome AS baia_nome,
        c.id AS cadeira_id,
        c.identificador AS cadeira_identificador
      FROM reservas r
      JOIN usuarios u ON r.usuario_id = u.id
      LEFT JOIN departamentos d ON u.departamento_id = d.id
      JOIN cadeiras c ON r.cadeira_id = c.id
      JOIN baias b ON c.baia_id = b.id
      JOIN escritorios e ON b.escritorio_id = e.id
      WHERE ${whereClause}
      ORDER BY r.data_reserva DESC, e.nome ASC, c.identificador ASC
      LIMIT $${limitIndex} OFFSET $${offsetIndex}
    `;
    const dataResult = await pool.query(dataQuery, dataParams);

    const hojeIso = DateTime.now().setZone('America/Sao_Paulo').toISODate()!;

    const rows = dataResult.rows.map((row: any) => {
      const dataIso = normalizeIsoDate(row.data_reserva);

      let situacaoPresenca = 'Pendente';
      if (row.checkin_realizado) {
        situacaoPresenca = 'Presença Confirmada';
      } else if (row.status === 'CANCELADA') {
        situacaoPresenca = 'Cancelada';
      } else if (row.status === 'EXPIRADA_NOSHOW' || row.status === 'CANCELADA_POR_FALTA' || dataIso < hojeIso) {
        situacaoPresenca = 'Não Compareceu (No-Show)';
      }

      return {
        id: row.id,
        dataReserva: dataIso,
        status: row.status,
        checkinRealizado: row.checkin_realizado,
        checkinEm: row.checkin_em ? DateTime.fromJSDate(row.checkin_em).setZone('America/Sao_Paulo').toISO() : null,
        codigoComprovante: row.codigo_comprovante,
        criadoEm: row.criado_em ? DateTime.fromJSDate(row.criado_em).setZone('America/Sao_Paulo').toISO() : null,
        situacaoPresenca,
        usuario: {
          id: row.usuario_id,
          nome: row.usuario_nome,
          matricula: row.usuario_matricula,
          email: row.usuario_email,
          departamento: row.departamento_nome
        },
        escritorio: {
          id: row.escritorio_id,
          nome: row.escritorio_nome,
          cidade: row.escritorio_cidade
        },
        assento: {
          id: row.cadeira_id,
          identificador: row.cadeira_identificador,
          baia: row.baia_nome
        }
      };
    });

    return {
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
      registros: rows
    };
  }

  /**
   * Obtém dataset completo para exportação
   */
  public static async getExportData(query: any, maxLimit = 10000) {
    const { whereClause, params, dataInicio, dataFim } = RelatorioService.buildWhereClause(query);

    const sql = `
      SELECT
        r.id,
        r.data_reserva,
        r.status,
        r.checkin_realizado,
        r.checkin_em,
        r.codigo_comprovante,
        r.criado_em,
        u.matricula,
        u.nome AS colaborador,
        u.email,
        COALESCE(d.nome, 'Sem Departamento') AS departamento,
        e.nome AS escritorio,
        e.cidade,
        b.nome AS baia,
        c.identificador AS assento
      FROM reservas r
      JOIN usuarios u ON r.usuario_id = u.id
      LEFT JOIN departamentos d ON u.departamento_id = d.id
      JOIN cadeiras c ON r.cadeira_id = c.id
      JOIN baias b ON c.baia_id = b.id
      JOIN escritorios e ON b.escritorio_id = e.id
      WHERE ${whereClause}
      ORDER BY r.data_reserva DESC, e.nome ASC, c.identificador ASC
      LIMIT $${params.length + 1}
    `;

    const result = await pool.query(sql, [...params, maxLimit]);
    return {
      rows: result.rows,
      rowCount: result.rowCount || 0,
      dataInicio,
      dataFim
    };
  }
}
