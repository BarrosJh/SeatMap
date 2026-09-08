import { Response } from 'express';
import { DateTime } from 'luxon';
import ExcelJS from 'exceljs';
import PDFDocument from 'pdfkit';
import pool from '../config/db';
import { sanitizeCsvCell } from '../utils/sanitizer';
import { normalizeIsoDate } from '../utils/workWeekUtils';
import { logger } from '../utils/logger';

export class ExportService {
  /**
   * Exporta a planilha Excel completa com formatação visual corporativa
   */
  public static async exportarExcel(data: { rows: any[]; dataInicio: string; dataFim: string }, res: Response) {
    const { rows, dataInicio, dataFim } = data;

    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'SeatMap RH';
    workbook.created = new Date();

    const worksheet = workbook.addWorksheet('Reservas & Presenças', {
      views: [{ showGridLines: true }]
    });

    // Título do Relatório
    const titleRow = worksheet.getRow(1);
    titleRow.values = ['SEATMAP - RELATÓRIO GERAL DE RESERVAS E FREQUÊNCIA'];
    titleRow.font = { name: 'Calibri', size: 14, bold: true, color: { argb: 'FFFFFFFF' } };
    titleRow.fill = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: 'FF1E3A8A' }
    };
    titleRow.height = 30;
    titleRow.alignment = { vertical: 'middle', horizontal: 'left', indent: 1 };
    worksheet.mergeCells('A1:L1');

    // Subtítulo com período e emissão
    const subRow = worksheet.getRow(2);
    const agoraFormatado = DateTime.now().setZone('America/Sao_Paulo').toFormat('dd/MM/yyyy HH:mm:ss');
    subRow.values = [`Período: ${DateTime.fromISO(dataInicio).toFormat('dd/MM/yyyy')} até ${DateTime.fromISO(dataFim).toFormat('dd/MM/yyyy')} | Emitido em: ${agoraFormatado} (Horário de Brasília)`];
    subRow.font = { name: 'Calibri', size: 10, italic: true, color: { argb: 'FF475569' } };
    subRow.fill = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: 'FFF1F5F9' }
    };
    subRow.height = 20;
    subRow.alignment = { vertical: 'middle', horizontal: 'left', indent: 1 };
    worksheet.mergeCells('A2:L2');

    // Linha de Cabeçalho da Tabela
    const headerRow = worksheet.getRow(4);
    headerRow.values = [
      'Data da Reserva',
      'Matrícula',
      'Colaborador',
      'E-mail',
      'Departamento',
      'Escritório',
      'Baia',
      'Assento',
      'Status Reserva',
      'Situação Presença',
      'Horário Check-in',
      'Comprovante'
    ];
    headerRow.font = { name: 'Calibri', size: 11, bold: true, color: { argb: 'FFFFFFFF' } };
    headerRow.fill = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: 'FF2563EB' }
    };
    headerRow.height = 24;
    headerRow.alignment = { vertical: 'middle', horizontal: 'center' };

    // Inserção das Linhas de Dados
    let rowIndex = 5;
    const hojeIso = DateTime.now().setZone('America/Sao_Paulo').toISODate()!;

    for (const row of rows) {
      const dataIso = normalizeIsoDate(row.data_reserva);
      const dataFormatada = DateTime.fromISO(dataIso).toFormat('dd/MM/yyyy');
      const checkinFormatado = row.checkin_em ? DateTime.fromJSDate(row.checkin_em).setZone('America/Sao_Paulo').toFormat('dd/MM/yyyy HH:mm:ss') : 'N/A';

      let situacaoPresenca = 'Pendente';
      if (row.checkin_realizado) {
        situacaoPresenca = 'Presença Confirmada';
      } else if (row.status === 'CANCELADA') {
        situacaoPresenca = 'Cancelada';
      } else if (row.status === 'EXPIRADA_NOSHOW' || row.status === 'CANCELADA_POR_FALTA' || dataIso < hojeIso) {
        situacaoPresenca = 'Não Compareceu (No-Show)';
      }

      const dataRow = worksheet.getRow(rowIndex);
      dataRow.values = [
        dataFormatada,
        sanitizeCsvCell(row.matricula || ''),
        sanitizeCsvCell(row.colaborador || ''),
        sanitizeCsvCell(row.email || ''),
        sanitizeCsvCell(row.departamento || ''),
        sanitizeCsvCell(row.escritorio || ''),
        sanitizeCsvCell(row.baia || ''),
        sanitizeCsvCell(row.assento || ''),
        row.status,
        situacaoPresenca,
        checkinFormatado,
        row.codigo_comprovante || ''
      ];

      const isEven = rowIndex % 2 === 0;
      dataRow.eachCell({ includeEmpty: true }, (cell, colNumber) => {
        cell.font = { name: 'Calibri', size: 10, color: { argb: 'FF1E293B' } };
        cell.fill = {
          type: 'pattern',
          pattern: 'solid',
          fgColor: { argb: isEven ? 'FFF8FAFC' : 'FFFFFFFF' }
        };
        cell.border = {
          bottom: { style: 'thin', color: { argb: 'FFE2E8F0' } },
          right: { style: 'thin', color: { argb: 'FFE2E8F0' } }
        };

        if (colNumber === 1 || colNumber === 2 || colNumber === 8 || colNumber === 11 || colNumber === 12) {
          cell.alignment = { vertical: 'middle', horizontal: 'center' };
        } else {
          cell.alignment = { vertical: 'middle', horizontal: 'left' };
        }

        if (colNumber === 10) {
          if (row.checkin_realizado) {
            cell.font = { name: 'Calibri', size: 10, bold: true, color: { argb: 'FF16A34A' } };
          } else if (situacaoPresenca.includes('No-Show') || row.status === 'CANCELADA') {
            cell.font = { name: 'Calibri', size: 10, bold: true, color: { argb: 'FFDC2626' } };
          }
        }
      });

      dataRow.height = 20;
      rowIndex++;
    }

    worksheet.columns = [
      { width: 14 },
      { width: 15 },
      { width: 28 },
      { width: 28 },
      { width: 22 },
      { width: 20 },
      { width: 16 },
      { width: 12 },
      { width: 15 },
      { width: 26 },
      { width: 20 },
      { width: 24 }
    ];

    const filename = `relatorio_reservas_${dataInicio}_a_${dataFim}.xlsx`;
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);

    await workbook.xlsx.write(res);
    return res.end();
  }

  /**
   * Exporta o relatório executivo em PDF diagramado em A4 Landscape
   */
  public static async exportarPdf(
    data: { rows: any[]; rowCount: number; dataInicio: string; dataFim: string },
    res: Response,
    correlationId?: string
  ) {
    const { rows, rowCount, dataInicio, dataFim } = data;

    const total = rowCount;
    const totalCheckins = rows.filter((r: any) => r.checkin_realizado).length;
    const totalCanceladas = rows.filter((r: any) => r.status === 'CANCELADA').length;
    const hojeIso = DateTime.now().setZone('America/Sao_Paulo').toISODate()!;
    const totalNoShows = rows.filter((r: any) => {
      const dataIso = normalizeIsoDate(r.data_reserva);
      return r.status === 'EXPIRADA_NOSHOW' || r.status === 'CANCELADA_POR_FALTA' || (!r.checkin_realizado && r.status === 'ATIVA' && dataIso < hojeIso);
    }).length;
    const taxaPresenca = total > 0 ? ((totalCheckins / total) * 100).toFixed(1) : '0';

    const doc = new PDFDocument({
      layout: 'landscape',
      size: 'A4',
      margin: 30,
      bufferPages: true
    });

    doc.on('error', (err) => {
      logger.error('[ExportService.exportarPdf PDFKit Error]:', { correlationId, error: err });
      if (!res.headersSent) {
        res.status(500).json({ error: 'Erro ao renderizar relatório em PDF.' });
      } else {
        res.destroy();
      }
    });

    const filename = `relatorio_reservas_${dataInicio}_a_${dataFim}.pdf`;
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    doc.pipe(res);

    const drawHeader = (currentPage: number) => {
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
        const cardY = 82;
        const cardWidth = 188;
        const cardHeight = 36;

        doc.rect(30, cardY, cardWidth, cardHeight).fillAndStroke('#EFF6FF', '#BFDBFE');
        doc.fillColor('#1E40AF').fontSize(8).font('Helvetica-Bold').text('TOTAL DE RESERVAS', 40, cardY + 6);
        doc.fillColor('#1E3A8A').fontSize(14).font('Helvetica-Bold').text(`${total}`, 40, cardY + 18);

        doc.rect(228, cardY, cardWidth, cardHeight).fillAndStroke('#F0FDF4', '#BBF7D0');
        doc.fillColor('#166534').fontSize(8).font('Helvetica-Bold').text('PRESENÇAS CONFIRMADAS', 238, cardY + 6);
        doc.fillColor('#15803D').fontSize(14).font('Helvetica-Bold').text(`${totalCheckins} (${taxaPresenca}%)`, 238, cardY + 18);

        doc.rect(426, cardY, cardWidth, cardHeight).fillAndStroke('#FEF2F2', '#FECACA');
        doc.fillColor('#991B1B').fontSize(8).font('Helvetica-Bold').text('NÃO COMPARECEU (NO-SHOW)', 436, cardY + 6);
        doc.fillColor('#DC2626').fontSize(14).font('Helvetica-Bold').text(`${totalNoShows}`, 436, cardY + 18);

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

    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];

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

      const dataReservaIso = normalizeIsoDate(row.data_reserva);
      const dataFormatada = DateTime.fromISO(dataReservaIso).toFormat('dd/MM/yyyy');

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

      doc.rect(30, y + rowHeight - 1, 782, 1).fill('#E2E8F0');
      y += rowHeight;
    }

    const range = doc.bufferedPageRange();
    for (let p = range.start; p < range.start + range.count; p++) {
      doc.switchToPage(p);
      doc.rect(30, 560, 782, 20).fill('#F8FAFC');
      doc.fillColor('#64748B').fontSize(7.5).font('Helvetica')
        .text(`Página ${p + 1} de ${range.count}  |  SeatMap RH - Documento Confidencial de Auditoria Interna`, 30, 566, { align: 'center', width: 782 });
    }

    doc.end();
  }

  /**
   * Exporta o relatório CSV de parâmetros/ocupação diária com cabeçalhos e sanitização anti formula injection
   */
  public static async exportarCsvParametros(dataAlvo: string, res: Response) {
    const result = await pool.query(`
      SELECT 
        u.matricula,
        u.nome AS colaborador,
        d.nome AS departamento,
        e.nome AS escritorio,
        b.nome AS baia,
        c.identificador AS assento,
        r.data_reserva,
        r.status,
        r.checkin_realizado,
        r.checkin_em
      FROM reservas r
      JOIN usuarios u ON r.usuario_id = u.id
      LEFT JOIN departamentos d ON u.departamento_id = d.id
      JOIN cadeiras c ON r.cadeira_id = c.id
      JOIN baias b ON c.baia_id = b.id
      JOIN escritorios e ON b.escritorio_id = e.id
      WHERE r.data_reserva = $1
      ORDER BY e.nome ASC, b.nome ASC, c.identificador ASC
    `, [dataAlvo]);

    const headers = ['Matrícula', 'Colaborador', 'Departamento', 'Escritório', 'Baia', 'Assento', 'Data Reserva', 'Status', 'Check-in Realizado', 'Horário Check-in'];
    const csvLines = [headers.join(';')];

    for (const row of result.rows) {
      const checkinFormatado = row.checkin_em ? DateTime.fromJSDate(row.checkin_em).setZone('America/Sao_Paulo').toFormat('dd/MM/yyyy HH:mm:ss') : 'N/A';
      const dataReservaFormatada = typeof row.data_reserva === 'string'
        ? row.data_reserva
        : DateTime.fromJSDate(row.data_reserva).toFormat('dd/MM/yyyy');

      const line = [
        sanitizeCsvCell(row.matricula || ''),
        sanitizeCsvCell(row.colaborador || ''),
        sanitizeCsvCell(row.departamento || ''),
        sanitizeCsvCell(row.escritorio || ''),
        sanitizeCsvCell(row.baia || ''),
        sanitizeCsvCell(row.assento || ''),
        sanitizeCsvCell(dataReservaFormatada),
        sanitizeCsvCell(row.status),
        sanitizeCsvCell(row.checkin_realizado ? 'SIM' : 'NÃO'),
        sanitizeCsvCell(checkinFormatado)
      ];
      csvLines.push(line.join(';'));
    }

    const csvContent = '\uFEFF' + csvLines.join('\r\n');

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename=relatorio_reservas_${dataAlvo}.csv`);
    return res.status(200).send(csvContent);
  }
}

