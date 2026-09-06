import { Response } from 'express';
import { DateTime } from 'luxon';
import pool from '../config/db';
import { AuthenticatedRequest } from '../middleware/auth';
import { getMondayOfCurrentWorkWeek, isProximaSemanaLiberada } from '../utils/workWeekUtils';

export class EscritorioController {
  public static async listar(req: AuthenticatedRequest, res: Response) {
    try {
      const result = await pool.query('SELECT id, nome, cidade, ativo FROM escritorios WHERE ativo = true ORDER BY id ASC');
      return res.status(200).json(result.rows);
    } catch (error) {
      console.error('[EscritorioController.listar] Erro:', error);
      return res.status(500).json({ error: 'Erro ao listar escritórios.' });
    }
  }

  public static async getMapa(req: AuthenticatedRequest, res: Response) {
    const escritorioId = parseInt(req.params.id, 10);
    const dataQuery = req.query.data as string;
    const currentUserId = req.user?.userId;

    if (isNaN(escritorioId)) {
      return res.status(400).json({ error: 'ID de escritório inválido.' });
    }

    const dataReserva = dataQuery || DateTime.now().setZone('America/Sao_Paulo').toISODate()!;

    try {
      // 1. Obter dados do escritório
      const escRes = await pool.query('SELECT id, nome, cidade FROM escritorios WHERE id = $1 AND ativo = true', [escritorioId]);
      if (escRes.rowCount === 0) {
        return res.status(404).json({ error: 'Escritório não encontrado ou inativo.' });
      }
      const escritorio = escRes.rows[0];

      // 2. Obter todas as baias do escritório
      const baiasRes = await pool.query('SELECT id, nome FROM baias WHERE escritorio_id = $1 ORDER BY id ASC', [escritorioId]);

      // 3. Obter todas as cadeiras do escritório com suas reservas ativas na data
      const cadeirasRes = await pool.query(`
        SELECT 
          c.id AS cadeira_id,
          c.baia_id,
          c.identificador,
          c.posicao_x,
          c.posicao_y,
          c.ativa,
          r.id AS reserva_id,
          r.usuario_id,
          r.checkin_realizado,
          r.checkin_em,
          r.status AS reserva_status,
          u.nome AS ocupante_nome,
          u.matricula AS ocupante_matricula,
          u.perfil AS ocupante_perfil,
          u.departamento_id AS ocupante_departamento_id,
          d.nome AS ocupante_departamento_nome
        FROM cadeiras c
        JOIN baias b ON c.baia_id = b.id
        LEFT JOIN reservas r ON c.id = r.cadeira_id AND r.data_reserva = $2 AND r.status = 'ATIVA'
        LEFT JOIN usuarios u ON r.usuario_id = u.id
        LEFT JOIN departamentos d ON u.departamento_id = d.id
        WHERE b.escritorio_id = $1 AND c.ativa = true
        ORDER BY c.baia_id ASC, c.id ASC
      `, [escritorioId, dataReserva]);

      // 4. Organizar cadeiras por baia e calcular distribuição percentual por departamento
      const baiasMap: Record<number, any> = {};

      for (const baia of baiasRes.rows) {
        baiasMap[baia.id] = {
          id: baia.id,
          nome: baia.nome,
          totalCadeiras: 0,
          totalOcupadas: 0,
          totalLivres: 0,
          distribuicaoDepartamentos: {} as Record<string, { count: number; percentual: number }>,
          resumoOcupacao: '',
          cadeiras: []
        };
      }

      for (const row of cadeirasRes.rows) {
        const baia = baiasMap[row.baia_id];
        if (!baia) continue;

        baia.totalCadeiras++;

        let status: 'livre' | 'ocupada' | 'minha_reserva' = 'livre';
        let ocupante = null;

        if (row.reserva_id && row.reserva_status === 'ATIVA') {
          if (currentUserId && row.usuario_id === currentUserId) {
            status = 'minha_reserva';
          } else {
            status = 'ocupada';
          }

          baia.totalOcupadas++;
          const deptoNome = row.ocupante_departamento_nome || 'Sem Departamento';
          if (!baia.distribuicaoDepartamentos[deptoNome]) {
            baia.distribuicaoDepartamentos[deptoNome] = { count: 0, percentual: 0 };
          }
          baia.distribuicaoDepartamentos[deptoNome].count++;

          ocupante = {
            usuarioId: row.usuario_id,
            nome: row.ocupante_nome,
            matricula: row.ocupante_matricula,
            perfil: row.ocupante_perfil,
            departamentoId: row.ocupante_departamento_id,
            departamento: row.ocupante_departamento_nome,
            checkinRealizado: row.checkin_realizado,
            checkinEm: row.checkin_em
          };
        } else {
          baia.totalLivres++;
        }

        baia.cadeiras.push({
          id: row.cadeira_id,
          identificador: row.identificador,
          posicaoX: row.posicao_x,
          posicaoY: row.posicao_y,
          status,
          reservaId: row.reserva_id || null,
          ocupante
        });
      }

      // Calcular percentuais finais e gerar resumo textual (ex: "50% Jurídico | 25% TI | 25% Livre")
      const baiasArray = Object.values(baiasMap).map((baia: any) => {
        const total = baia.totalCadeiras;
        const partesResumo: string[] = [];

        if (total > 0) {
          for (const [depto, dados] of Object.entries(baia.distribuicaoDepartamentos as Record<string, any>)) {
            const perc = Math.round((dados.count / total) * 100);
            dados.percentual = perc;
            partesResumo.push(`${perc}% ${depto}`);
          }
          const percLivre = Math.round((baia.totalLivres / total) * 100);
          partesResumo.push(`${percLivre}% Livre`);
        }

        baia.resumoOcupacao = partesResumo.length > 0 ? partesResumo.join(' | ') : '100% Livre';
        return baia;
      });

      return res.status(200).json({
        escritorio,
        data: dataReserva,
        baias: baiasArray
      });
    } catch (error) {
      console.error('[EscritorioController.getMapa] Erro:', error);
      return res.status(500).json({ error: 'Erro ao carregar mapa de assentos.' });
    }
  }

  public static async getOcupacaoSemanal(req: AuthenticatedRequest, res: Response) {
    try {
      const now = DateTime.now().setZone('America/Sao_Paulo');
      const mondayCurrent = getMondayOfCurrentWorkWeek(now); // Segunda-feira da semana de trabalho vigente
      const statusAbertura = await isProximaSemanaLiberada(req.user?.perfil || 'COLABORADOR', now);

      const diasSemanaNomes = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta'];
      const diasSemanaCurtos = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex'];

      // Montar listas de 5 dias úteis (Seg a Sex) para semana atual e próxima
      const semanaAtualDatas: Array<{ dataIso: string; diaSemana: string; diaCurto: string; dataFormatada: string }> = [];
      const proximaSemanaDatas: Array<{ dataIso: string; diaSemana: string; diaCurto: string; dataFormatada: string }> = [];

      for (let i = 0; i < 5; i++) {
        const dAtual = mondayCurrent.plus({ days: i });
        semanaAtualDatas.push({
          dataIso: dAtual.toISODate()!,
          diaSemana: diasSemanaNomes[i],
          diaCurto: diasSemanaCurtos[i],
          dataFormatada: dAtual.toFormat('dd/MM')
        });

        const dProx = mondayCurrent.plus({ days: 7 + i });
        proximaSemanaDatas.push({
          dataIso: dProx.toISODate()!,
          diaSemana: diasSemanaNomes[i],
          diaCurto: diasSemanaCurtos[i],
          dataFormatada: dProx.toFormat('dd/MM')
        });
      }

      const todasDatas = [
        ...semanaAtualDatas.map(d => d.dataIso),
        ...proximaSemanaDatas.map(d => d.dataIso)
      ];

      // 1. Obter escritórios ativos
      const escRes = await pool.query('SELECT id, nome, cidade FROM escritorios WHERE ativo = true ORDER BY id ASC');

      // 2. Obter total de cadeiras ativas por escritório
      const cadeirasCountRes = await pool.query(`
        SELECT b.escritorio_id, COUNT(c.id)::int AS total_cadeiras
        FROM cadeiras c
        JOIN baias b ON c.baia_id = b.id
        WHERE c.ativa = true
        GROUP BY b.escritorio_id
      `);
      const totalCadeirasPorEscritorio: Record<number, number> = {};
      for (const row of cadeirasCountRes.rows) {
        totalCadeirasPorEscritorio[row.escritorio_id] = row.total_cadeiras;
      }

      // 3. Obter contagem de reservas ativas por escritório e data
      const reservasRes = await pool.query(`
        SELECT 
          b.escritorio_id, 
          TO_CHAR(r.data_reserva, 'YYYY-MM-DD') AS data_reserva_str,
          COUNT(r.id)::int AS total_reservas
        FROM reservas r
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        WHERE r.status = 'ATIVA' AND r.data_reserva = ANY($1::date[])
        GROUP BY b.escritorio_id, r.data_reserva
      `, [todasDatas]);

      const reservasMap: Record<string, number> = {}; // key: "escritorioId_YYYY-MM-DD"
      for (const row of reservasRes.rows) {
        const key = `${row.escritorio_id}_${row.data_reserva_str}`;
        reservasMap[key] = row.total_reservas;
      }

      // 4. Montar resposta estruturada
      const resultado = escRes.rows.map(esc => {
        const totalCadeiras = totalCadeirasPorEscritorio[esc.id] || 0;

        const processarDia = (item: { dataIso: string; diaSemana: string; diaCurto: string; dataFormatada: string }) => {
          const key = `${esc.id}_${item.dataIso}`;
          const totalReservas = reservasMap[key] || 0;
          const livres = Math.max(0, totalCadeiras - totalReservas);
          const percentual = totalCadeiras > 0 ? Math.round((totalReservas / totalCadeiras) * 100) : 0;

          return {
            data: item.dataIso,
            diaSemana: item.diaSemana,
            diaCurto: item.diaCurto,
            dataFormatada: item.dataFormatada,
            totalCadeiras,
            totalReservas,
            livres,
            percentual
          };
        };

        const semanaAtual = semanaAtualDatas.map(processarDia);
        const proximaSemana = proximaSemanaDatas.map(processarDia);

        // Média da semana atual
        const somaPercAtual = semanaAtual.reduce((acc, curr) => acc + curr.percentual, 0);
        const mediaOcupacaoAtual = semanaAtual.length > 0 ? Math.round(somaPercAtual / semanaAtual.length) : 0;

        return {
          id: esc.id,
          nome: esc.nome,
          cidade: esc.cidade,
          totalCadeiras,
          mediaOcupacaoAtual,
          proximaSemanaAberta: statusAbertura.liberada,
          mensagemBloqueioProximaSemana: statusAbertura.mensagemBloqueio || null,
          semanaAtual,
          proximaSemana
        };
      });

      return res.status(200).json(resultado);
    } catch (error) {
      console.error('[EscritorioController.getOcupacaoSemanal] Erro:', error);
      return res.status(500).json({ error: 'Erro ao calcular ocupação semanal dos escritórios.' });
    }
  }
}


