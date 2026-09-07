import { Response } from 'express';
import pool from '../config/db';
import { AuthenticatedRequest } from '../middleware/auth';
import { DateTime } from 'luxon';
import ExcelJS from 'exceljs';
import PDFDocument from 'pdfkit';

export class RelatorioController {
  /**
   * Helper para construir cláusula WHERE e parâmetros dinâmicos
   */
  private static buildWhereClause(query: any) {
    const dataInicio = query.dataInicio as string || DateTime.now().setZone('America/Sao_Paulo').startOf('month').toISODate()!;
    const dataFim = query.dataFim as string || DateTime.now().setZone('America/Sao_Paulo').toISODate()!;
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
        conditions.push(`(r.status IN ('EXPIRADA_NOSHOW', 'CANCELADA_POR_FALTA') OR (r.data_reserva < CURRENT_DATE AND r.checkin_realizado = false AND r.status != 'CANCELADA'))`);
      }
    }

    if (busca && busca.trim().length > 0) {
      conditions.push(`(u.nome ILIKE $${paramIndex} OR u.matricula ILIKE $${paramIndex} OR u.email ILIKE $${paramIndex} OR c.identificador ILIKE $${paramIndex} OR r.codigo_comprovante ILIKE $${paramIndex})`);
      params.push(`%${busca.trim()}%`);
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
   * 1. GET /api/admin/relatorios/analytics
   * Retorna os KPIs e resumos agregados para visualização nos cards de BI
   */
  public static async getAnalytics(req: AuthenticatedRequest, res: Response) {
    try {
      const { whereClause, params, dataInicio, dataFim } = RelatorioController.buildWhereClause(req.query);

      // 1. Resumo Global
      const resumoQuery = `
        SELECT
          COUNT(r.id)::int AS total_reservas,
          COUNT(CASE WHEN r.checkin_realizado = true THEN 1 END)::int AS total_checkins,
          COUNT(CASE WHEN r.status = 'CANCELADA' THEN 1 END)::int AS total_canceladas,
          COUNT(CASE WHEN r.status IN ('EXPIRADA_NOSHOW', 'CANCELADA_POR_FALTA') OR (r.data_reserva < CURRENT_DATE AND r.checkin_realizado = false AND r.status = 'ATIVA') THEN 1 END)::int AS total_noshows,
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

      const totalReservas = resumo.total_reservas;
      const totalCheckins = resumo.total_checkins;
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
          COUNT(CASE WHEN r.status IN ('EXPIRADA_NOSHOW', 'CANCELADA_POR_FALTA') OR (r.data_reserva < CURRENT_DATE AND r.checkin_realizado = false AND r.status = 'ATIVA') THEN 1 END)::int AS total_noshows,
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
          COUNT(CASE WHEN r.status IN ('EXPIRADA_NOSHOW', 'CANCELADA_POR_FALTA') OR (r.data_reserva < CURRENT_DATE AND r.checkin_realizado = false AND r.status = 'ATIVA') THEN 1 END)::int AS total_noshows
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
        data: typeof row.data_reserva === 'string' ? row.data_reserva : DateTime.fromJSDate(row.data_reserva).toISODate()!,
        totalReservas: row.total_reservas,
        totalCheckins: row.total_checkins,
        totalNoShows: row.total_noshows
      }));

      return res.status(200).json({
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
      });
    } catch (error) {
      console.error('[RelatorioController.getAnalytics] Erro:', error);
      return res.status(500).json({ error: 'Erro ao consolidar analytics do relatório.' });
    }
  }

  /**
   * 2. GET /api/admin/relatorios/dados
   * Retorna os registros tabulares com paginação e busca para exibição em tabela
   */
  public static async getDadosRelatorio(req: AuthenticatedRequest, res: Response) {
    try {
      const { whereClause, params } = RelatorioController.buildWhereClause(req.query);

      const page = parseInt(req.query.page as string || '1', 10);
      const limit = parseInt(req.query.limit as string || '50', 10);
      const offset = (page - 1) * limit;

      // Total de registros para paginação
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

      // Lista paginada
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

      const rows = dataResult.rows.map((row: any) => {
        const dataIso = typeof row.data_reserva === 'string'
          ? row.data_reserva
          : DateTime.fromJSDate(row.data_reserva).toISODate()!;
        
        let situacaoPresenca = 'Pendente';
        if (row.checkin_realizado) {
          situacaoPresenca = 'Presença Confirmada';
        } else if (row.status === 'CANCELADA') {
          situacaoPresenca = 'Cancelada';
        } else if (row.status === 'EXPIRADA_NOSHOW' || row.status === 'CANCELADA_POR_FALTA' || (dataIso < DateTime.now().setZone('America/Sao_Paulo').toISODate()!)) {
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

      return res.status(200).json({
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
        registros: rows
      });
    } catch (error) {
      console.error('[RelatorioController.getDadosRelatorio] Erro:', error);
      return res.status(500).json({ error: 'Erro ao buscar dados do relatório.' });
    }
  }

  /**
   * 3. GET /api/admin/relatorios/exportar/xlsx
   * Gera uma planilha Excel formatada e profissional com exceljs
   */
  public static async exportarXlsx(req: AuthenticatedRequest, res: Response) {
    try {
      const { whereClause, params, dataInicio, dataFim } = RelatorioController.buildWhereClause(req.query);

      // Buscar todos os registros correspondentes aos filtros
      const query = `
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
      `;
      const result = await pool.query(query, params);

      const workbook = new ExcelJS.Workbook();
      workbook.creator = 'SeatMap RH';
      workbook.created = new Date();

      // -------------------------------------------------------------
      // Planilha 1: Detalhamento de Reservas
      // -------------------------------------------------------------
      const worksheet = workbook.addWorksheet('Reservas & Presenças', {
        views: [{ showGridLines: true }]
      });

      // Título do Relatório
      worksheet.mergeCells('A1:L1');
      const titleRow = worksheet.getCell('A1');
      titleRow.value = 'SEATMAP - RELATÓRIO GERAL DE RESERVAS E FREQUÊNCIA';
      titleRow.font = { name: 'Calibri', size: 16, bold: true, color: { argb: 'FFFFFFFF' } };
      titleRow.alignment = { vertical: 'middle', horizontal: 'center' };
      titleRow.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'FF1E3A8A' } // Navy Blue
      };
      worksheet.getRow(1).height = 34;

      // Metadados do Relatório
      worksheet.mergeCells('A2:L2');
      const metaRow = worksheet.getCell('A2');
      metaRow.value = `Período: ${DateTime.fromISO(dataInicio).toFormat('dd/MM/yyyy')} a ${DateTime.fromISO(dataFim).toFormat('dd/MM/yyyy')} | Gerado em: ${DateTime.now().setZone('America/Sao_Paulo').toFormat('dd/MM/yyyy HH:mm:ss')} | Total de Registros: ${result.rowCount}`;
      metaRow.font = { name: 'Calibri', size: 10, italic: true, color: { argb: 'FF475569' } };
      metaRow.alignment = { vertical: 'middle', horizontal: 'center' };
      metaRow.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'FFF1F5F9' }
      };
      worksheet.getRow(2).height = 20;

      // Cabeçalhos de Coluna
      const headers = [
        'Data',
        'Matrícula',
        'Colaborador',
        'E-mail',
        'Departamento',
        'Escritório',
        'Baia',
        'Mesa',
        'Status Reserva',
        'Presença / Check-in',
        'Horário Check-in',
        'Cód. Comprovante'
      ];

      worksheet.getRow(4).values = headers;
      const headerRow = worksheet.getRow(4);
      headerRow.height = 24;
      headerRow.eachCell((cell) => {
        cell.font = { name: 'Calibri', size: 11, bold: true, color: { argb: 'FFFFFFFF' } };
        cell.fill = {
          type: 'pattern',
          pattern: 'solid',
          fgColor: { argb: 'FF2563EB' } // Royal Blue
        };
        cell.alignment = { vertical: 'middle', horizontal: 'center' };
        cell.border = {
          top: { style: 'thin', color: { argb: 'FFCBD5E1' } },
          bottom: { style: 'medium', color: { argb: 'FF1E293B' } }
        };
      });

      // Linhas de Dados
      let rowIndex = 5;
      const hojeIso = DateTime.now().setZone('America/Sao_Paulo').toISODate()!;

      for (const row of result.rows) {
        const dataFormatada = typeof row.data_reserva === 'string'
          ? DateTime.fromISO(row.data_reserva).toFormat('dd/MM/yyyy')
          : DateTime.fromJSDate(row.data_reserva).toFormat('dd/MM/yyyy');
        
        const checkinFormatado = row.checkin_em
          ? DateTime.fromJSDate(row.checkin_em).setZone('America/Sao_Paulo').toFormat('dd/MM/yyyy HH:mm:ss')
          : '-';

        const dataReservaIso = typeof row.data_reserva === 'string'
          ? row.data_reserva
          : DateTime.fromJSDate(row.data_reserva).toISODate()!;

        let situacao = 'Pendente';
        if (row.checkin_realizado) {
          situacao = 'PRESENÇA CONFIRMADA';
        } else if (row.status === 'CANCELADA') {
          situacao = 'CANCELADA';
        } else if (row.status === 'EXPIRADA_NOSHOW' || row.status === 'CANCELADA_POR_FALTA' || dataReservaIso < hojeIso) {
          situacao = 'NÃO COMPARECEU (NO-SHOW)';
        }

        const dataRow = worksheet.getRow(rowIndex);
        dataRow.values = [
          dataFormatada,
          row.matricula || '',
          row.colaborador || '',
          row.email || '',
          row.departamento || '',
          row.escritorio || '',
          row.baia || '',
          row.assento || '',
          row.status,
          situacao,
          checkinFormatado,
          row.codigo_comprovante || ''
        ];

        // Zebra striping
        const isEven = rowIndex % 2 === 0;
        const bgColor = isEven ? 'FFF8FAFC' : 'FFFFFFFF';

        dataRow.eachCell((cell, colNumber) => {
          cell.font = { name: 'Calibri', size: 10, color: { argb: 'FF1E293B' } };
          cell.fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: bgColor }
          };
          cell.alignment = {
            vertical: 'middle',
            horizontal: [1, 2, 8, 9, 10, 11, 12].includes(colNumber) ? 'center' : 'left'
          };
          cell.border = {
            bottom: { style: 'thin', color: { argb: 'FFE2E8F0' } }
          };

          // Destaque visual na coluna de presença
          if (colNumber === 10) {
            if (situacao === 'PRESENÇA CONFIRMADA') {
              cell.font = { name: 'Calibri', size: 10, bold: true, color: { argb: 'FF16A34A' } };
            } else if (situacao.includes('NO-SHOW') || situacao === 'CANCELADA') {
              cell.font = { name: 'Calibri', size: 10, bold: true, color: { argb: 'FFDC2626' } };
            }
          }
        });

        dataRow.height = 20;
        rowIndex++;
      }

      // Larguras automáticas de colunas
      worksheet.columns = [
        { width: 14 }, // Data
        { width: 15 }, // Matrícula
        { width: 28 }, // Colaborador
        { width: 28 }, // E-mail
        { width: 22 }, // Departamento
        { width: 20 }, // Escritório
        { width: 16 }, // Baia
        { width: 12 }, // Mesa
        { width: 15 }, // Status
        { width: 26 }, // Presença
        { width: 20 }, // Horário
        { width: 24 }  // Comprovante
      ];

      // Enviar como Stream para download
      const filename = `relatorio_reservas_${dataInicio}_a_${dataFim}.xlsx`;
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);

      await workbook.xlsx.write(res);
      return res.end();
    } catch (error) {
      console.error('[RelatorioController.exportarXlsx] Erro:', error);
      return res.status(500).json({ error: 'Erro ao gerar planilha Excel.' });
    }
  }

  /**
   * 4. GET /api/admin/relatorios/exportar/pdf
   * Gera um relatório executivo em PDF diagramado em A4 Landscape com pdfkit
   */
  public static async exportarPdf(req: AuthenticatedRequest, res: Response) {
    try {
      const { whereClause, params, dataInicio, dataFim } = RelatorioController.buildWhereClause(req.query);

      // Buscar registros
      const query = `
        SELECT
          r.id,
          r.data_reserva,
          r.status,
          r.checkin_realizado,
          r.checkin_em,
          r.codigo_comprovante,
          u.matricula,
          u.nome AS colaborador,
          COALESCE(d.nome, 'Sem Departamento') AS departamento,
          e.nome AS escritorio,
          c.identificador AS assento
        FROM reservas r
        JOIN usuarios u ON r.usuario_id = u.id
        LEFT JOIN departamentos d ON u.departamento_id = d.id
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        JOIN escritorios e ON b.escritorio_id = e.id
        WHERE ${whereClause}
        ORDER BY r.data_reserva DESC, e.nome ASC, c.identificador ASC
      `;
      const result = await pool.query(query, params);

      // Métricas para o cabeçalho executivo
      const total = result.rowCount || 0;
      const totalCheckins = result.rows.filter((r: any) => r.checkin_realizado).length;
      const totalCanceladas = result.rows.filter((r: any) => r.status === 'CANCELADA').length;
      const hojeIso = DateTime.now().setZone('America/Sao_Paulo').toISODate()!;
      const totalNoShows = result.rows.filter((r: any) => {
        const dataIso = typeof r.data_reserva === 'string' ? r.data_reserva : DateTime.fromJSDate(r.data_reserva).toISODate()!;
        return r.status === 'EXPIRADA_NOSHOW' || r.status === 'CANCELADA_POR_FALTA' || (!r.checkin_realizado && r.status === 'ATIVA' && dataIso < hojeIso);
      }).length;
      const taxaPresenca = total > 0 ? ((totalCheckins / total) * 100).toFixed(1) : '0';

      const doc = new PDFDocument({
        layout: 'landscape',
        size: 'A4',
        margin: 30,
        bufferPages: true
      });

      const filename = `relatorio_reservas_${dataInicio}_a_${dataFim}.pdf`;
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
      doc.pipe(res);

      const drawHeader = (currentPage: number) => {
        // Faixa azul superior
        doc.rect(30, 30, 782, 45).fill('#1E3A8A');

        doc.fillColor('#FFFFFF')
          .fontSize(14)
          .font('Helvetica-Bold')
          .text('SEATMAP - GESTÃO DE ASSENTOS & PRESTIGIAR', 45, 40);

        doc.fontSize(9)
          .font('Helvetica')
          .text('Relatório Gerencial de Ocupação, Presenças e Auditoria RH', 45, 58);

        doc.fontSize(8)
          .font('Helvetica')
          .text(`Período: ${DateTime.fromISO(dataInicio).toFormat('dd/MM/yyyy')} a ${DateTime.fromISO(dataFim).toFormat('dd/MM/yyyy')}  |  Emitido em: ${DateTime.now().setZone('America/Sao_Paulo').toFormat('dd/MM/yyyy HH:mm')}`, 450, 48, { align: 'right', width: 350 });

        if (currentPage === 1) {
          // Cards de Métricas (Somente na página 1)
          const cardY = 82;
          const cardWidth = 188;
          const cardHeight = 36;

          // Card 1: Total
          doc.rect(30, cardY, cardWidth, cardHeight).fillAndStroke('#EFF6FF', '#BFDBFE');
          doc.fillColor('#1E40AF').fontSize(8).font('Helvetica-Bold').text('TOTAL DE RESERVAS', 40, cardY + 6);
          doc.fillColor('#1E3A8A').fontSize(14).font('Helvetica-Bold').text(`${total}`, 40, cardY + 18);

          // Card 2: Presenças
          doc.rect(228, cardY, cardWidth, cardHeight).fillAndStroke('#F0FDF4', '#BBF7D0');
          doc.fillColor('#166534').fontSize(8).font('Helvetica-Bold').text('PRESENÇAS CONFIRMADAS', 238, cardY + 6);
          doc.fillColor('#15803D').fontSize(14).font('Helvetica-Bold').text(`${totalCheckins} (${taxaPresenca}%)`, 238, cardY + 18);

          // Card 3: No-Shows
          doc.rect(426, cardY, cardWidth, cardHeight).fillAndStroke('#FEF2F2', '#FECACA');
          doc.fillColor('#991B1B').fontSize(8).font('Helvetica-Bold').text('NÃO COMPARECEU (NO-SHOW)', 436, cardY + 6);
          doc.fillColor('#DC2626').fontSize(14).font('Helvetica-Bold').text(`${totalNoShows}`, 436, cardY + 18);

          // Card 4: Canceladas
          doc.rect(624, cardY, cardWidth, cardHeight).fillAndStroke('#F8FAFC', '#E2E8F0');
          doc.fillColor('#475569').fontSize(8).font('Helvetica-Bold').text('CANCELAMENTOS', 634, cardY + 6);
          doc.fillColor('#334155').fontSize(14).font('Helvetica-Bold').text(`${totalCanceladas}`, 634, cardY + 18);
        }
      };

      const tableColumns = [
        { title: 'Data', x: 30, width: 65, align: 'center' },
        { title: 'Matrícula', x: 95, width: 65, align: 'center' },
        { title: 'Colaborador', x: 160, width: 170, align: 'left' },
        { title: 'Departamento', x: 330, width: 110, align: 'left' },
        { title: 'Escritório', x: 440, width: 95, align: 'left' },
        { title: 'Mesa', x: 535, width: 55, align: 'center' },
        { title: 'Situação / Check-in', x: 590, width: 110, align: 'center' },
        { title: 'Comprovante', x: 700, width: 112, align: 'center' }
      ];

      let currentPage = 1;
      let startY = 128;

      drawHeader(currentPage);

      const drawTableHeader = (y: number) => {
        doc.rect(30, y, 782, 18).fill('#2563EB');
        doc.fillColor('#FFFFFF').fontSize(8).font('Helvetica-Bold');
        for (const col of tableColumns) {
          doc.text(col.title, col.x + 4, y + 5, { width: col.width - 8, align: col.align as any });
        }
      };

      drawTableHeader(startY);
      let y = startY + 18;
      const rowHeight = 16;
      const maxY = 540;

      for (let i = 0; i < result.rows.length; i++) {
        const row = result.rows[i];

        if (y + rowHeight > maxY) {
          doc.addPage();
          currentPage++;
          drawHeader(currentPage);
          startY = 85;
          drawTableHeader(startY);
          y = startY + 18;
        }

        const isEven = i % 2 === 0;
        doc.rect(30, y, 782, rowHeight).fill(isEven ? '#F8FAFC' : '#FFFFFF');

        const dataFormatada = typeof row.data_reserva === 'string'
          ? DateTime.fromISO(row.data_reserva).toFormat('dd/MM/yyyy')
          : DateTime.fromJSDate(row.data_reserva).toFormat('dd/MM/yyyy');

        const dataReservaIso = typeof row.data_reserva === 'string'
          ? row.data_reserva
          : DateTime.fromJSDate(row.data_reserva).toISODate()!;

        let situacao = 'Pendente';
        let situacaoColor = '#64748B';
        if (row.checkin_realizado) {
          situacao = 'Confirmado';
          situacaoColor = '#16A34A';
        } else if (row.status === 'CANCELADA') {
          situacao = 'Cancelada';
          situacaoColor = '#DC2626';
        } else if (row.status === 'EXPIRADA_NOSHOW' || row.status === 'CANCELADA_POR_FALTA' || dataReservaIso < hojeIso) {
          situacao = 'No-Show';
          situacaoColor = '#DC2626';
        }

        doc.fillColor('#1E293B').fontSize(7.5).font('Helvetica');

        doc.text(dataFormatada, tableColumns[0].x + 4, y + 4, { width: tableColumns[0].width - 8, align: 'center' });
        doc.text(row.matricula || '-', tableColumns[1].x + 4, y + 4, { width: tableColumns[1].width - 8, align: 'center' });
        doc.font('Helvetica-Bold').text(row.colaborador || '-', tableColumns[2].x + 4, y + 4, { width: tableColumns[2].width - 8, ellipsis: true });
        doc.font('Helvetica').text(row.departamento || '-', tableColumns[3].x + 4, y + 4, { width: tableColumns[3].width - 8, ellipsis: true });
        doc.text(row.escritorio || '-', tableColumns[4].x + 4, y + 4, { width: tableColumns[4].width - 8, ellipsis: true });
        doc.text(row.assento || '-', tableColumns[5].x + 4, y + 4, { width: tableColumns[5].width - 8, align: 'center' });

        doc.fillColor(situacaoColor).font('Helvetica-Bold').text(situacao, tableColumns[6].x + 4, y + 4, { width: tableColumns[6].width - 8, align: 'center' });
        doc.fillColor('#64748B').font('Helvetica').text(row.codigo_comprovante || '-', tableColumns[7].x + 4, y + 4, { width: tableColumns[7].width - 8, align: 'center', ellipsis: true });

        // Linha divisória fina
        doc.rect(30, y + rowHeight - 1, 782, 1).fill('#E2E8F0');

        y += rowHeight;
      }

      // Rodapé com número de páginas em todas as páginas
      const range = doc.bufferedPageRange();
      for (let p = range.start; p < range.start + range.count; p++) {
        doc.switchToPage(p);
        doc.rect(30, 560, 782, 20).fill('#F8FAFC');
        doc.fillColor('#64748B').fontSize(7.5).font('Helvetica')
          .text(`Página ${p + 1} de ${range.count}  |  SeatMap RH - Documento Confidencial de Auditoria Interna`, 30, 566, { align: 'center', width: 782 });
      }

      doc.end();
    } catch (error) {
      console.error('[RelatorioController.exportarPdf] Erro:', error);
      return res.status(500).json({ error: 'Erro ao gerar relatório em PDF.' });
    }
  }
}
