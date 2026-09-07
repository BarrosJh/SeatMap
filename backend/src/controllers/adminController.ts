import { Response } from 'express';
import bcrypt from 'bcrypt';
import { DateTime } from 'luxon';
import pool from '../config/db';
import { AuthenticatedRequest } from '../middleware/auth';
import { ConfigService } from '../services/configService';
import { CronService } from '../services/cronService';
import { EmailService } from '../services/emailService';
import { ReservaHistoryService } from '../services/reservaHistoryService';
import { wsManager } from '../websocket/wsServer';


export class AdminController {
  // ==========================================
  // 1. CONFIGURAÇÕES E PARÂMETROS
  // ==========================================
  public static async getParametros(req: AuthenticatedRequest, res: Response) {
    try {
      const parametros = await ConfigService.getAll();
      return res.status(200).json(parametros);
    } catch (error) {
      console.error('[AdminController.getParametros] Erro:', error);
      return res.status(500).json({ error: 'Erro ao buscar parâmetros do sistema.' });
    }
  }

  public static async updateParametros(req: AuthenticatedRequest, res: Response) {
    const { configuracoes } = req.body;

    if (!configuracoes) {
      return res.status(400).json({ error: 'Nenhuma configuração enviada para atualização.' });
    }

    try {
      if (Array.isArray(configuracoes)) {
        for (const item of configuracoes) {
          if (item.chave && item.valor !== undefined) {
            await ConfigService.set(item.chave, item.valor.toString(), item.descricao);
          }
        }
      } else if (typeof configuracoes === 'object') {
        for (const [chave, valor] of Object.entries(configuracoes)) {
          await ConfigService.set(chave, String(valor));
        }
      }

      const atualizadas = await ConfigService.getAll();
      const avisoAtualizado = await ConfigService.get('AVISO_GLOBAL_SISTEMA', '');
      wsManager.broadcastToAll({
        tipo: 'AVISO_GLOBAL_ATUALIZADO',
        aviso: avisoAtualizado
      });

      return res.status(200).json({
        message: 'Configurações atualizadas com sucesso.',
        parametros: atualizadas
      });
    } catch (error) {
      console.error('[AdminController.updateParametros] Erro:', error);
      return res.status(500).json({ error: 'Erro ao atualizar configurações.' });
    }
  }

  public static async executarLimpezaNoShow(req: AuthenticatedRequest, res: Response) {
    const { data } = req.body;
    try {
      const resultado = await CronService.cancelExpiredNoShows(data);
      return res.status(200).json({
        message: 'Rotina de limpeza de No-Show executada com sucesso.',
        totalExpiradas: resultado.totalExpiradas,
        detalhes: resultado.reservas
      });
    } catch (error) {
      console.error('[AdminController.executarLimpezaNoShow] Erro:', error);
      return res.status(500).json({ error: 'Erro ao executar limpeza de No-Show.' });
    }
  }

  public static async exportarRelatorioCsv(req: AuthenticatedRequest, res: Response) {
    const dataQuery = req.query.data as string;
    const dataAlvo = dataQuery || DateTime.now().setZone('America/Sao_Paulo').toISODate()!;

    try {
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
          `"${row.matricula || ''}"`,
          `"${row.colaborador || ''}"`,
          `"${row.departamento || ''}"`,
          `"${row.escritorio || ''}"`,
          `"${row.baia || ''}"`,
          `"${row.assento || ''}"`,
          `"${dataReservaFormatada}"`,
          `"${row.status}"`,
          `"${row.checkin_realizado ? 'SIM' : 'NÃO'}"`,
          `"${checkinFormatado}"`
        ];
        csvLines.push(line.join(';'));
      }

      const csvContent = '\uFEFF' + csvLines.join('\r\n');

      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename=relatorio_reservas_${dataAlvo}.csv`);
      return res.status(200).send(csvContent);
    } catch (error) {
      console.error('[AdminController.exportarRelatorioCsv] Erro:', error);
      return res.status(500).json({ error: 'Erro ao gerar relatório CSV.' });
    }
  }

  // ==========================================
  // 2. GESTÃO DE USUÁRIOS
  // ==========================================
  public static async getUsuarios(req: AuthenticatedRequest, res: Response) {
    try {
      const { busca, departamentoId, perfil, ativo, limit = 100, offset = 0 } = req.query;

      const conditions: string[] = [];
      const values: any[] = [];
      let idx = 1;

      if (busca && typeof busca === 'string' && busca.trim().length > 0) {
        conditions.push(`(u.nome ILIKE $${idx} OR u.email ILIKE $${idx} OR u.matricula ILIKE $${idx})`);
        values.push(`%${busca.trim()}%`);
        idx++;
      }

      if (departamentoId && departamentoId !== 'todos') {
        conditions.push(`u.departamento_id = $${idx}`);
        values.push(parseInt(departamentoId as string, 10));
        idx++;
      }

      if (perfil && perfil !== 'todos') {
        conditions.push(`u.perfil = $${idx}`);
        values.push(perfil);
        idx++;
      }

      if (ativo !== undefined && ativo !== 'todos') {
        conditions.push(`u.ativo = $${idx}`);
        values.push(String(ativo) === 'true');
        idx++;
      }

      const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

      const countRes = await pool.query(`
        SELECT COUNT(*) AS total
        FROM usuarios u
        ${whereClause}
      `, values);

      const total = parseInt(countRes.rows[0].total, 10);

      const dataQuery = `
        SELECT 
          u.id,
          u.nome,
          u.email,
          u.matricula,
          u.perfil,
          COALESCE(u.permissao_rh, false) AS permissao_rh,
          COALESCE(u.permissao_ti, false) AS permissao_ti,
          COALESCE(u.exigir_mfa, false) AS exigir_mfa,
          COALESCE(u.totp_ativo, false) AS totp_ativo,
          u.ativo,
          u.departamento_id,
          d.nome AS departamento_nome,
          (SELECT COUNT(*) FROM reservas r WHERE r.usuario_id = u.id AND r.status = 'ATIVA') AS total_reservas_ativas
        FROM usuarios u
        LEFT JOIN departamentos d ON u.departamento_id = d.id
        ${whereClause}
        ORDER BY u.nome ASC
        LIMIT $${idx} OFFSET $${idx + 1}
      `;

      values.push(parseInt(limit as string, 10) || 100);
      values.push(parseInt(offset as string, 10) || 0);

      const result = await pool.query(dataQuery, values);

      return res.status(200).json({
        total,
        usuarios: result.rows
      });
    } catch (error) {
      console.error('[AdminController.getUsuarios] Erro:', error);
      return res.status(500).json({ error: 'Erro ao listar usuários.' });
    }
  }

  public static async criarUsuario(req: AuthenticatedRequest, res: Response) {
    try {
      const { 
        nome, 
        email, 
        matricula, 
        senha, 
        departamentoId, 
        perfil = 'COLABORADOR', 
        permissaoRh, 
        permissao_rh, 
        permissaoTi,
        permissao_ti,
        exigirMfa,
        exigir_mfa,
        ativo = true 
      } = req.body;

      if (!nome || !email || !matricula || !senha) {
        return res.status(400).json({ error: 'Nome, e-mail, matrícula e senha são obrigatórios.' });
      }

      if (!['COLABORADOR', 'GESTAO', 'ADMIN_RH', 'ADMIN_TI'].includes(perfil)) {
        return res.status(400).json({ error: 'Perfil inválido. Deve ser COLABORADOR, GESTAO, ADMIN_RH ou ADMIN_TI.' });
      }

      const hasRh = permissaoRh !== undefined 
        ? Boolean(permissaoRh) 
        : (permissao_rh !== undefined ? Boolean(permissao_rh) : perfil === 'ADMIN_RH');
      const hasTi = permissaoTi !== undefined
        ? Boolean(permissaoTi)
        : (permissao_ti !== undefined ? Boolean(permissao_ti) : perfil === 'ADMIN_TI');
      const needsMfa = exigirMfa !== undefined
        ? Boolean(exigirMfa)
        : (exigir_mfa !== undefined ? Boolean(exigir_mfa) : false);
      const perfilFinal = perfil === 'ADMIN_RH' ? 'GESTAO' : (perfil === 'ADMIN_TI' ? 'ADMIN_TI' : perfil);

      // Checar duplicidade
      const checkExists = await pool.query(`
        SELECT id FROM usuarios WHERE email = $1 OR matricula = $2
      `, [email.trim().toLowerCase(), matricula.trim()]);

      if (checkExists.rowCount! > 0) {
        return res.status(400).json({ error: 'Já existe um usuário com este e-mail ou matrícula.' });
      }

      const senhaHash = await bcrypt.hash(senha, 10);

      const insertRes = await pool.query(`
        INSERT INTO usuarios (nome, email, matricula, senha_hash, departamento_id, perfil, permissao_rh, permissao_ti, exigir_mfa, ativo)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        RETURNING id, nome, email, matricula, departamento_id, perfil, permissao_rh, permissao_ti, exigir_mfa, ativo
      `, [
        nome.trim(),
        email.trim().toLowerCase(),
        matricula.trim(),
        senhaHash,
        departamentoId ? parseInt(departamentoId, 10) : null,
        perfilFinal,
        hasRh,
        hasTi,
        needsMfa,
        ativo !== undefined ? Boolean(ativo) : true
      ]);

      const novoUsuario = insertRes.rows[0];

      return res.status(201).json({
        message: 'Usuário cadastrado com sucesso.',
        usuario: novoUsuario
      });
    } catch (error) {
      console.error('[AdminController.criarUsuario] Erro:', error);
      return res.status(500).json({ error: 'Erro ao criar usuário.' });
    }
  }

  public static async updateUsuario(req: AuthenticatedRequest, res: Response) {
    try {
      const { id } = req.params;
      const { 
        nome, 
        email, 
        matricula, 
        departamentoId, 
        perfil, 
        permissaoRh, 
        permissao_rh, 
        permissaoTi,
        permissao_ti,
        exigirMfa,
        exigir_mfa,
        ativo 
      } = req.body;

      const userExists = await pool.query('SELECT id FROM usuarios WHERE id = $1', [id]);
      if (userExists.rowCount === 0) {
        return res.status(404).json({ error: 'Usuário não encontrado.' });
      }

      // Validar duplicidade se email ou matricula foram alterados
      if (email || matricula) {
        const checkDuplicate = await pool.query(`
          SELECT id FROM usuarios WHERE (email = $1 OR matricula = $2) AND id != $3
        `, [email ? email.trim().toLowerCase() : '', matricula ? matricula.trim() : '', id]);

        if (checkDuplicate.rowCount! > 0) {
          return res.status(400).json({ error: 'E-mail ou matrícula já pertencem a outro usuário.' });
        }
      }

      const hasRh = permissaoRh !== undefined 
        ? Boolean(permissaoRh) 
        : (permissao_rh !== undefined ? Boolean(permissao_rh) : (perfil === 'ADMIN_RH' ? true : null));
      const hasTi = permissaoTi !== undefined
        ? Boolean(permissaoTi)
        : (permissao_ti !== undefined ? Boolean(permissao_ti) : (perfil === 'ADMIN_TI' ? true : null));
      const needsMfa = exigirMfa !== undefined
        ? Boolean(exigirMfa)
        : (exigir_mfa !== undefined ? Boolean(exigir_mfa) : null);
      const perfilFinal = perfil === 'ADMIN_RH' ? 'GESTAO' : (perfil === 'ADMIN_TI' ? 'ADMIN_TI' : (perfil || null));

      const updateRes = await pool.query(`
        UPDATE usuarios
        SET 
          nome = COALESCE($1, nome),
          email = COALESCE($2, email),
          matricula = COALESCE($3, matricula),
          departamento_id = CASE WHEN $4::text IS NOT NULL THEN $5::int ELSE departamento_id END,
          perfil = COALESCE($6, perfil),
          permissao_rh = COALESCE($7, permissao_rh),
          permissao_ti = COALESCE($8, permissao_ti),
          exigir_mfa = COALESCE($9, exigir_mfa),
          ativo = COALESCE($10, ativo)
        WHERE id = $11
        RETURNING id, nome, email, matricula, departamento_id, perfil, permissao_rh, permissao_ti, exigir_mfa, ativo
      `, [
        nome ? nome.trim() : null,
        email ? email.trim().toLowerCase() : null,
        matricula ? matricula.trim() : null,
        departamentoId !== undefined ? String(departamentoId) : null,
        departamentoId ? parseInt(departamentoId, 10) : null,
        perfilFinal,
        hasRh,
        hasTi,
        needsMfa,
        ativo !== undefined ? Boolean(ativo) : null,
        id
      ]);

      return res.status(200).json({
        message: 'Usuário atualizado com sucesso.',
        usuario: updateRes.rows[0]
      });
    } catch (error) {
      console.error('[AdminController.updateUsuario] Erro:', error);
      return res.status(500).json({ error: 'Erro ao atualizar usuário.' });
    }
  }

  public static async toggleStatusUsuario(req: AuthenticatedRequest, res: Response) {
    try {
      const { id } = req.params;
      const { ativo } = req.body;

      let result;
      if (ativo !== undefined) {
        result = await pool.query(`
          UPDATE usuarios
          SET ativo = $1
          WHERE id = $2
          RETURNING id, nome, email, matricula, perfil, ativo
        `, [Boolean(ativo), id]);
      } else {
        result = await pool.query(`
          UPDATE usuarios
          SET ativo = NOT ativo
          WHERE id = $1
          RETURNING id, nome, email, matricula, perfil, ativo
        `, [id]);
      }

      if (result.rowCount === 0) {
        return res.status(404).json({ error: 'Usuário não encontrado.' });
      }

      return res.status(200).json({
        message: `Status do usuário alterado para ${result.rows[0].ativo ? 'Ativo' : 'Inativo'}.`,
        usuario: result.rows[0]
      });
    } catch (error) {
      console.error('[AdminController.toggleStatusUsuario] Erro:', error);
      return res.status(500).json({ error: 'Erro ao alterar status do usuário.' });
    }
  }

  public static async resetSenhaUsuario(req: AuthenticatedRequest, res: Response) {
    try {
      const { id } = req.params;
      const { novaSenha } = req.body;

      if (!novaSenha || novaSenha.trim().length < 4) {
        return res.status(400).json({ error: 'A nova senha deve possuir pelo menos 4 caracteres.' });
      }

      const senhaHash = await bcrypt.hash(novaSenha.trim(), 10);

      const result = await pool.query(`
        UPDATE usuarios
        SET senha_hash = $1
        WHERE id = $2
        RETURNING id, nome, email, matricula
      `, [senhaHash, id]);

      if (result.rowCount === 0) {
        return res.status(404).json({ error: 'Usuário não encontrado.' });
      }

      return res.status(200).json({
        message: 'Senha do usuário redefinida com sucesso.'
      });
    } catch (error) {
      console.error('[AdminController.resetSenhaUsuario] Erro:', error);
      return res.status(500).json({ error: 'Erro ao redefinir senha do usuário.' });
    }
  }

  // ==========================================
  // 3. IMPORTAÇÃO EM LOTE DE USUÁRIOS
  // ==========================================
  public static async importarLoteUsuarios(req: AuthenticatedRequest, res: Response) {
    const client = await pool.connect();
    try {
      const { usuarios, defaultSenha = 'Mudar@123' } = req.body;

      if (!Array.isArray(usuarios) || usuarios.length === 0) {
        return res.status(400).json({ error: 'Envie uma lista de usuários para importação.' });
      }

      // Buscar todos os departamentos para auto-resolução
      const depRes = await client.query('SELECT id, nome FROM departamentos');
      const depMap = new Map<string, number>();
      depRes.rows.forEach(d => depMap.set(d.nome.toLowerCase().trim(), d.id));

      const hashPadrao = await bcrypt.hash(defaultSenha, 10);

      let criados = 0;
      let atualizados = 0;
      const erros: Array<{ linha: number; email: string; matricula: string; erro: string }> = [];

      await client.query('BEGIN');

      for (let i = 0; i < usuarios.length; i++) {
        const u = usuarios[i];
        const linhaNum = i + 1;

        if (!u.nome || !u.email || !u.matricula) {
          erros.push({ linha: linhaNum, email: u.email || '', matricula: u.matricula || '', erro: 'Nome, e-mail e matrícula são obrigatórios.' });
          continue;
        }

        const nome = String(u.nome).trim();
        const email = String(u.email).trim().toLowerCase();
        const matricula = String(u.matricula).trim();
        const hasRh = u.permissaoRh !== undefined 
          ? Boolean(u.permissaoRh) 
          : (u.permissao_rh !== undefined ? Boolean(u.permissao_rh) : u.perfil === 'ADMIN_RH');
        const hasTi = u.permissaoTi !== undefined
          ? Boolean(u.permissaoTi)
          : (u.permissao_ti !== undefined ? Boolean(u.permissao_ti) : u.perfil === 'ADMIN_TI');
        const needsMfa = u.exigirMfa !== undefined
          ? Boolean(u.exigirMfa)
          : (u.exigir_mfa !== undefined ? Boolean(u.exigir_mfa) : false);
        const perfil = u.perfil === 'ADMIN_RH' ? 'GESTAO' : (u.perfil === 'ADMIN_TI' ? 'ADMIN_TI' : (['COLABORADOR', 'GESTAO'].includes(u.perfil) ? u.perfil : 'COLABORADOR'));
        const ativo = u.ativo !== undefined ? Boolean(u.ativo) : true;

        // Resolução do Departamento
        let depId: number | null = null;
        if (u.departamentoId) {
          depId = parseInt(u.departamentoId, 10);
        } else if (u.departamento && String(u.departamento).trim().length > 0) {
          const depNome = String(u.departamento).trim();
          const depKey = depNome.toLowerCase();
          if (depMap.has(depKey)) {
            depId = depMap.get(depKey)!;
          } else {
            // Criar novo departamento dinamicamente
            const novoDep = await client.query(
              'INSERT INTO departamentos (nome) VALUES ($1) ON CONFLICT (nome) DO UPDATE SET nome = EXCLUDED.nome RETURNING id',
              [depNome]
            );
            depId = novoDep.rows[0].id;
            depMap.set(depKey, depId!);
          }
        }

        const senhaHash = u.senha ? await bcrypt.hash(String(u.senha).trim(), 10) : hashPadrao;

        // Upsert na tabela de usuários
        const upsertRes = await client.query(`
          INSERT INTO usuarios (nome, email, matricula, senha_hash, departamento_id, perfil, permissao_rh, permissao_ti, exigir_mfa, ativo)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
          ON CONFLICT (email) DO UPDATE SET
            nome = EXCLUDED.nome,
            matricula = EXCLUDED.matricula,
            departamento_id = COALESCE(EXCLUDED.departamento_id, usuarios.departamento_id),
            perfil = EXCLUDED.perfil,
            permissao_rh = EXCLUDED.permissao_rh,
            permissao_ti = EXCLUDED.permissao_ti,
            exigir_mfa = COALESCE(EXCLUDED.exigir_mfa, usuarios.exigir_mfa),
            ativo = EXCLUDED.ativo
          RETURNING (xmax = 0) AS inserido
        `, [nome, email, matricula, senhaHash, depId, perfil, hasRh, hasTi, needsMfa, ativo]);

        if (upsertRes.rows[0].inserido) {
          criados++;
        } else {
          atualizados++;
        }
      }

      await client.query('COMMIT');

      return res.status(200).json({
        message: `Processamento concluído: ${criados} novos usuários criados, ${atualizados} atualizados.`,
        totalProcessados: usuarios.length,
        criados,
        atualizados,
        totalErros: erros.length,
        erros
      });
    } catch (error) {
      await client.query('ROLLBACK');
      console.error('[AdminController.importarLoteUsuarios] Erro:', error);
      return res.status(500).json({ error: 'Erro ao processar importação em lote.' });
    } finally {
      client.release();
    }
  }

  // ==========================================
  // 4. GESTÃO DE DEPARTAMENTOS
  // ==========================================
  public static async getDepartamentos(req: AuthenticatedRequest, res: Response) {
    try {
      const result = await pool.query(`
        SELECT 
          d.id,
          d.nome,
          COUNT(u.id) AS total_usuarios
        FROM departamentos d
        LEFT JOIN usuarios u ON u.departamento_id = d.id
        GROUP BY d.id, d.nome
        ORDER BY d.nome ASC
      `);

      return res.status(200).json(result.rows);
    } catch (error) {
      console.error('[AdminController.getDepartamentos] Erro:', error);
      return res.status(500).json({ error: 'Erro ao listar departamentos.' });
    }
  }

  public static async criarDepartamento(req: AuthenticatedRequest, res: Response) {
    try {
      const { nome } = req.body;
      if (!nome || typeof nome !== 'string' || nome.trim().length === 0) {
        return res.status(400).json({ error: 'O nome do departamento é obrigatório.' });
      }

      const result = await pool.query(`
        INSERT INTO departamentos (nome)
        VALUES ($1)
        ON CONFLICT (nome) DO NOTHING
        RETURNING id, nome
      `, [nome.trim()]);

      if (result.rowCount === 0) {
        return res.status(400).json({ error: 'Já existe um departamento com este nome.' });
      }

      return res.status(201).json({
        message: 'Departamento criado com sucesso.',
        departamento: result.rows[0]
      });
    } catch (error) {
      console.error('[AdminController.criarDepartamento] Erro:', error);
      return res.status(500).json({ error: 'Erro ao criar departamento.' });
    }
  }

  // ==========================================
  // 5. GESTÃO GLOBAL DE RESERVAS & CANCELAMENTO RH
  // ==========================================
  public static async getReservas(req: AuthenticatedRequest, res: Response) {
    try {
      const { dataInicio, dataFim, escritorioId, departamentoId, status, busca, limit = 100, offset = 0 } = req.query;

      const conditions: string[] = [];
      const values: any[] = [];
      let idx = 1;

      if (dataInicio) {
        conditions.push(`r.data_reserva >= $${idx}`);
        values.push(dataInicio);
        idx++;
      }

      if (dataFim) {
        conditions.push(`r.data_reserva <= $${idx}`);
        values.push(dataFim);
        idx++;
      }

      if (escritorioId && escritorioId !== 'todos') {
        conditions.push(`e.id = $${idx}`);
        values.push(parseInt(escritorioId as string, 10));
        idx++;
      }

      if (departamentoId && departamentoId !== 'todos') {
        conditions.push(`d.id = $${idx}`);
        values.push(parseInt(departamentoId as string, 10));
        idx++;
      }

      if (status && status !== 'todos') {
        conditions.push(`r.status = $${idx}`);
        values.push(status);
        idx++;
      }

      if (busca && typeof busca === 'string' && busca.trim().length > 0) {
        conditions.push(`(u.nome ILIKE $${idx} OR u.matricula ILIKE $${idx} OR c.identificador ILIKE $${idx} OR b.nome ILIKE $${idx})`);
        values.push(`%${busca.trim()}%`);
        idx++;
      }

      const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

      const countRes = await pool.query(`
        SELECT COUNT(*) AS total
        FROM reservas r
        JOIN usuarios u ON r.usuario_id = u.id
        LEFT JOIN departamentos d ON u.departamento_id = d.id
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        JOIN escritorios e ON b.escritorio_id = e.id
        ${whereClause}
      `, values);

      const total = parseInt(countRes.rows[0].total, 10);

      const dataQuery = `
        SELECT 
          r.id,
          r.cadeira_id,
          c.identificador AS assento,
          b.nome AS baia_nome,
          e.id AS escritorio_id,
          e.nome AS escritorio_nome,
          u.id AS usuario_id,
          u.nome AS usuario_nome,
          u.matricula,
          u.email AS usuario_email,
          d.nome AS departamento_nome,
          r.data_reserva,
          r.checkin_realizado,
          r.checkin_em,
          r.status,
          r.codigo_comprovante,
          r.criado_em
        FROM reservas r
        JOIN usuarios u ON r.usuario_id = u.id
        LEFT JOIN departamentos d ON u.departamento_id = d.id
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        JOIN escritorios e ON b.escritorio_id = e.id
        ${whereClause}
        ORDER BY r.data_reserva DESC, r.criado_em DESC
        LIMIT $${idx} OFFSET $${idx + 1}
      `;

      values.push(parseInt(limit as string, 10) || 100);
      values.push(parseInt(offset as string, 10) || 0);

      const result = await pool.query(dataQuery, values);

      return res.status(200).json({
        total,
        reservas: result.rows
      });
    } catch (error) {
      console.error('[AdminController.getReservas] Erro:', error);
      return res.status(500).json({ error: 'Erro ao consultar reservas.' });
    }
  }

  public static async cancelarReservaAdmin(req: AuthenticatedRequest, res: Response) {
    const user = req.user!;
    try {
      const { id } = req.params;
      const { justificativa } = req.body;

      // Buscar detalhes da reserva
      const resRes = await pool.query(`
        SELECT 
          r.id,
          r.usuario_id,
          r.cadeira_id,
          r.data_reserva,
          r.status,
          r.codigo_comprovante,
          b.escritorio_id,
          c.identificador AS cadeira_identificador,
          u.nome AS usuario_nome
        FROM reservas r
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        JOIN usuarios u ON r.usuario_id = u.id
        WHERE r.id = $1
      `, [id]);

      if (resRes.rowCount === 0) {
        return res.status(404).json({ error: 'Reserva não encontrada.' });
      }

      const reserva = resRes.rows[0];

      if (reserva.status !== 'ATIVA') {
        return res.status(400).json({ error: `Reserva não pode ser cancelada pois está com status ${reserva.status}.` });
      }

      // Cancelar reserva
      await pool.query(`
        UPDATE reservas
        SET status = 'CANCELADA'
        WHERE id = $1
      `, [id]);

      const dataFormatada = typeof reserva.data_reserva === 'string'
        ? reserva.data_reserva
        : DateTime.fromJSDate(reserva.data_reserva).toISODate()!;

      // Gravar na Linha do Tempo Forense
      await ReservaHistoryService.registrarEvento({
        reservaId: reserva.id,
        cadeiraId: reserva.cadeira_id,
        usuarioId: reserva.usuario_id,
        dataReserva: dataFormatada,
        tipoEvento: 'CANCELADA_GESTAO',
        executadoPorUsuarioId: user.userId,
        motivo: justificativa || 'Cancelamento administrativo realizado pelo RH/Gestor',
        detalhes: {
          comprovante: reserva.codigo_comprovante,
          cadeiraIdentificador: reserva.cadeira_identificador,
          justificativa: justificativa || 'Não informada'
        }
      });

      // Liberar cadeira via WebSocket em tempo real
      wsManager.broadcastSeatUpdate({
        evento: 'assento_atualizado',
        escritorioId: reserva.escritorio_id,
        cadeiraId: reserva.cadeira_id,
        data: dataFormatada,
        status: 'livre',
        ocupante: null
      });

      console.log(`[AdminController.cancelarReservaAdmin] Reserva ${id} do usuário ${reserva.usuario_nome} cancelada pelo RH. Justificativa: ${justificativa || 'Não informada'}`);

      return res.status(200).json({
        message: 'Reserva cancelada com sucesso pela gestão/RH.',
        reservaId: id
      });
    } catch (error) {
      console.error('[AdminController.cancelarReservaAdmin] Erro:', error);
      return res.status(500).json({ error: 'Erro ao cancelar reserva.' });
    }
  }

  // ==========================================
  // 6. GESTÃO OPERACIONAL DE ASSENTOS & MANUTENÇÃO (FACILITIES & TI)
  // ==========================================
  public static async colocarCadeiraEmManutencao(req: AuthenticatedRequest, res: Response) {
    const user = req.user!;
    const cadeiraId = parseInt(req.params.id, 10);
    const { motivo, previsaoRetorno } = req.body;

    if (isNaN(cadeiraId)) {
      return res.status(400).json({ error: 'ID de cadeira inválido.' });
    }

    if (!motivo || typeof motivo !== 'string' || motivo.trim().length === 0) {
      return res.status(400).json({ error: 'O motivo da manutenção é obrigatório (ex: monitor quebrado, tomada sem energia).' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // 1. Bloquear linha da cadeira
      const cadeiraRes = await client.query(`
        SELECT c.id, c.identificador, c.status_operacional, b.id AS baia_id, b.nome AS baia_nome, b.escritorio_id, e.nome AS escritorio_nome
        FROM cadeiras c
        JOIN baias b ON c.baia_id = b.id
        JOIN escritorios e ON b.escritorio_id = e.id
        WHERE c.id = $1
        FOR UPDATE
      `, [cadeiraId]);

      if (cadeiraRes.rowCount === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Cadeira não encontrada.' });
      }

      const cadeira = cadeiraRes.rows[0];

      // 2. Atualizar status da cadeira para EM_MANUTENCAO
      await client.query(`
        UPDATE cadeiras
        SET status_operacional = 'EM_MANUTENCAO',
            motivo_manutencao = $1,
            previsao_retorno = $2,
            manutencao_por_usuario_id = $3
        WHERE id = $4
      `, [
        motivo.trim(),
        previsaoRetorno ? new Date(previsaoRetorno) : null,
        user.userId,
        cadeiraId
      ]);

      // 3. Buscar todas as reservas ATIVAS futuras ou de hoje para esta cadeira
      const reservasAfetadasRes = await client.query(`
        SELECT r.id, r.usuario_id, r.data_reserva, r.codigo_comprovante, u.nome AS usuario_nome, u.email AS usuario_email
        FROM reservas r
        JOIN usuarios u ON r.usuario_id = u.id
        WHERE r.cadeira_id = $1
          AND r.data_reserva >= CURRENT_DATE
          AND r.status = 'ATIVA'
        FOR UPDATE
      `, [cadeiraId]);

      const reservasAfetadas = reservasAfetadasRes.rows;

      if (reservasAfetadas.length > 0) {
        const ids = reservasAfetadas.map(r => r.id);
        await client.query(`
          UPDATE reservas
          SET status = 'CANCELADA'
          WHERE id = ANY($1::int[])
        `, [ids]);

        // Registrar cancelamento preventivo de cada reserva no histórico
        for (const resItem of reservasAfetadas) {
          const dataIso = typeof resItem.data_reserva === 'string'
            ? resItem.data_reserva
            : DateTime.fromJSDate(resItem.data_reserva).toISODate()!;

          await ReservaHistoryService.registrarEvento({
            reservaId: resItem.id,
            cadeiraId: cadeira.id,
            usuarioId: resItem.usuario_id,
            dataReserva: dataIso,
            tipoEvento: 'CANCELADA_MANUTENCAO',
            executadoPorUsuarioId: user.userId,
            motivo: `Bloqueio operacional de manutenção do assento: ${motivo.trim()}`,
            detalhes: {
              motivoManutencao: motivo.trim(),
              previsaoRetorno: previsaoRetorno || null,
              comprovante: resItem.codigo_comprovante,
              cadeiraIdentificador: cadeira.identificador
            }
          }, client);
        }
      }

      await client.query('COMMIT');

      // 4. Pós-Commit: Notificações em tempo real e e-mails aos colaboradores afetados
      for (const resItem of reservasAfetadas) {
        const dataIso = typeof resItem.data_reserva === 'string'
          ? resItem.data_reserva
          : DateTime.fromJSDate(resItem.data_reserva).toISODate()!;

        // Broadcast de liberação/manutenção para a data da reserva
        wsManager.broadcastSeatUpdate({
          evento: 'assento_atualizado',
          escritorioId: cadeira.escritorio_id,
          cadeiraId: cadeira.id,
          data: dataIso,
          status: 'manutencao',
          ocupante: null
        });

        // Enviar e-mail de alerta preventivo
        EmailService.enviarAvisoCancelamentoManutencao(resItem.usuario_email, resItem.usuario_nome, {
          cadeiraIdentificador: cadeira.identificador,
          dataReserva: dataIso,
          escritorioNome: cadeira.escritorio_nome,
          motivo: motivo.trim(),
          previsaoRetorno: previsaoRetorno ? DateTime.fromISO(previsaoRetorno).setZone('America/Sao_Paulo').toFormat('dd/MM/yyyy HH:mm') : undefined
        }).catch(err => console.error('[AdminController] Erro ao despachar email de manutencao:', err));
      }

      // Broadcast geral informando mudança no mapa
      wsManager.broadcastToAll({
        tipo: 'STATUS_CADEIRA_ALTERADO',
        cadeiraId: cadeira.id,
        escritorioId: cadeira.escritorio_id,
        statusOperacional: 'EM_MANUTENCAO',
        motivo: motivo.trim()
      });

      return res.status(200).json({
        message: `Mesa ${cadeira.identificador} colocada em manutenção com sucesso.`,
        reservasCanceladas: reservasAfetadas.length,
        cadeira: {
          id: cadeira.id,
          identificador: cadeira.identificador,
          statusOperacional: 'EM_MANUTENCAO',
          motivoManutencao: motivo.trim(),
          previsaoRetorno
        }
      });
    } catch (error) {
      await client.query('ROLLBACK');
      console.error('[AdminController.colocarCadeiraEmManutencao] Erro:', error);
      return res.status(500).json({ error: 'Erro ao bloquear assento para manutenção.' });
    } finally {
      client.release();
    }
  }

  public static async liberarCadeiraManutencao(req: AuthenticatedRequest, res: Response) {
    const cadeiraId = parseInt(req.params.id, 10);

    if (isNaN(cadeiraId)) {
      return res.status(400).json({ error: 'ID de cadeira inválido.' });
    }

    try {
      const updateRes = await pool.query(`
        UPDATE cadeiras c
        SET status_operacional = 'DISPONIVEL',
            motivo_manutencao = NULL,
            previsao_retorno = NULL,
            manutencao_por_usuario_id = NULL
        FROM baias b
        WHERE c.id = $1 AND c.baia_id = b.id
        RETURNING c.id, c.identificador, b.escritorio_id
      `, [cadeiraId]);

      if (updateRes.rowCount === 0) {
        return res.status(404).json({ error: 'Cadeira não encontrada.' });
      }

      const cadeira = updateRes.rows[0];

      // Broadcast geral informando liberação
      wsManager.broadcastToAll({
        tipo: 'STATUS_CADEIRA_ALTERADO',
        cadeiraId: cadeira.id,
        escritorioId: cadeira.escritorio_id,
        statusOperacional: 'DISPONIVEL'
      });

      return res.status(200).json({
        message: `Mesa ${cadeira.identificador} liberada para reservas gerais.`,
        cadeiraId: cadeira.id,
        statusOperacional: 'DISPONIVEL'
      });
    } catch (error) {
      console.error('[AdminController.liberarCadeiraManutencao] Erro:', error);
      return res.status(500).json({ error: 'Erro ao liberar cadeira de manutenção.' });
    }
  }

  public static async getHistoricoCadeira(req: AuthenticatedRequest, res: Response) {
    const cadeiraId = parseInt(req.params.id, 10);
    const limit = parseInt(req.query.limit as string, 10) || 50;
    const offset = parseInt(req.query.offset as string, 10) || 0;

    if (isNaN(cadeiraId)) {
      return res.status(400).json({ error: 'ID de cadeira inválido.' });
    }

    try {
      const historico = await ReservaHistoryService.getHistoricoCadeira(cadeiraId, limit, offset);
      return res.status(200).json({
        cadeiraId,
        total: historico.length,
        historico
      });
    } catch (error) {
      console.error('[AdminController.getHistoricoCadeira] Erro:', error);
      return res.status(500).json({ error: 'Erro ao consultar linha do tempo do assento.' });
    }
  }

  public static async getCadeirasManutencao(req: AuthenticatedRequest, res: Response) {
    try {
      const { escritorioId, busca } = req.query;

      const conditions: string[] = ["c.ativa = true"];
      const values: any[] = [];
      let idx = 1;

      if (escritorioId && escritorioId !== 'todos') {
        conditions.push(`b.escritorio_id = $${idx}`);
        values.push(parseInt(escritorioId as string, 10));
        idx++;
      }

      if (busca && typeof busca === 'string' && busca.trim().length > 0) {
        conditions.push(`(c.identificador ILIKE $${idx} OR b.nome ILIKE $${idx} OR c.motivo_manutencao ILIKE $${idx} OR u.nome ILIKE $${idx})`);
        values.push(`%${busca.trim()}%`);
        idx++;
      }

      // 1. KPIs
      const kpiRes = await pool.query(`
        SELECT 
          COUNT(CASE WHEN c.status_operacional = 'EM_MANUTENCAO' THEN 1 END)::int AS total_bloqueadas,
          COUNT(CASE WHEN c.status_operacional = 'DISPONIVEL' OR c.status_operacional IS NULL THEN 1 END)::int AS total_operacionais,
          COUNT(CASE WHEN c.status_operacional = 'EM_MANUTENCAO' AND c.previsao_retorno IS NOT NULL AND c.previsao_retorno < NOW() THEN 1 END)::int AS total_atrasadas
        FROM cadeiras c
        JOIN baias b ON c.baia_id = b.id
        WHERE c.ativa = true
      `);

      const kpis = kpiRes.rows[0] || { total_bloqueadas: 0, total_operacionais: 0, total_atrasadas: 0 };

      // 2. Cadeiras em manutenção filtradas
      const listQuery = `
        SELECT 
          c.id,
          c.identificador,
          c.status_operacional,
          c.motivo_manutencao,
          c.previsao_retorno,
          c.manutencao_por_usuario_id,
          b.id AS baia_id,
          b.nome AS baia_nome,
          e.id AS escritorio_id,
          e.nome AS escritorio_nome,
          e.cidade AS escritorio_cidade,
          u.nome AS responsavel_nome,
          u.email AS responsavel_email,
          (
            SELECT MAX(h.criado_em) 
            FROM historico_reservas h 
            WHERE h.cadeira_id = c.id AND h.tipo_evento = 'CANCELADA_MANUTENCAO'
          ) AS data_bloqueio
        FROM cadeiras c
        JOIN baias b ON c.baia_id = b.id
        JOIN escritorios e ON b.escritorio_id = e.id
        LEFT JOIN usuarios u ON c.manutencao_por_usuario_id = u.id
        WHERE c.status_operacional = 'EM_MANUTENCAO' AND ${conditions.join(' AND ')}
        ORDER BY c.previsao_retorno ASC NULLS LAST, e.nome ASC, b.nome ASC, c.identificador ASC
      `;

      const listRes = await pool.query(listQuery, values);

      return res.status(200).json({
        kpis: {
          totalBloqueadas: kpis.total_bloqueadas,
          totalOperacionais: kpis.total_operacionais,
          totalAtrasadas: kpis.total_atrasadas
        },
        manutencoes: listRes.rows
      });
    } catch (error) {
      console.error('[AdminController.getCadeirasManutencao] Erro:', error);
      return res.status(500).json({ error: 'Erro ao buscar assentos em manutenção.' });
    }
  }

  public static async getTodasCadeiras(req: AuthenticatedRequest, res: Response) {
    try {
      const { escritorioId } = req.query;
      const conditions: string[] = ["c.ativa = true"];
      const values: any[] = [];

      if (escritorioId && escritorioId !== 'todos') {
        conditions.push(`b.escritorio_id = $1`);
        values.push(parseInt(escritorioId as string, 10));
      }

      const result = await pool.query(`
        SELECT 
          c.id,
          c.identificador,
          c.status_operacional,
          c.motivo_manutencao,
          c.previsao_retorno,
          b.id AS baia_id,
          b.nome AS baia_nome,
          e.id AS escritorio_id,
          e.nome AS escritorio_nome,
          e.cidade AS escritorio_cidade
        FROM cadeiras c
        JOIN baias b ON c.baia_id = b.id
        JOIN escritorios e ON b.escritorio_id = e.id
        WHERE ${conditions.join(' AND ')}
        ORDER BY e.nome ASC, b.nome ASC, c.identificador ASC
      `, values);

      return res.status(200).json(result.rows);
    } catch (error) {
      console.error('[AdminController.getTodasCadeiras] Erro:', error);
      return res.status(500).json({ error: 'Erro ao listar todas as cadeiras.' });
    }
  }
}


