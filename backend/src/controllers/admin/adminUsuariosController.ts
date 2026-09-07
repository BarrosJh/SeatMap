import { Response } from 'express';
import bcrypt from 'bcrypt';
import pool from '../../config/db';
import { AuthenticatedRequest } from '../../middleware/auth';
import { validatePasswordPolicy } from '../../utils/passwordValidator';
import { TokenService } from '../../services/tokenService';

export class AdminUsuariosController {
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
      console.error('[AdminUsuariosController.getUsuarios] Erro:', error);
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

      const pwCheck = validatePasswordPolicy(senha);
      if (!pwCheck.valid) {
        return res.status(400).json({ error: pwCheck.message });
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
      const perfilFinal = perfil;

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
      console.error('[AdminUsuariosController.criarUsuario] Erro:', error);
      return res.status(500).json({ error: 'Erro ao criar usuário.' });
    }
  }

  public static async updateUsuario(req: AuthenticatedRequest, res: Response) {
    try {
      const { id } = req.params;
      const numericId = parseInt(id, 10);
      if (isNaN(numericId) || numericId <= 0) {
        return res.status(400).json({ error: 'ID de usuário inválido.' });
      }

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

      const userExists = await pool.query('SELECT id FROM usuarios WHERE id = $1', [numericId]);
      if (userExists.rowCount === 0) {
        return res.status(404).json({ error: 'Usuário não encontrado.' });
      }

      // Validar duplicidade se email ou matricula foram alterados
      const cleanEmail = email ? email.trim().toLowerCase() : null;
      const cleanMatricula = matricula ? matricula.trim() : null;

      if (cleanEmail || cleanMatricula) {
        const checkDuplicate = await pool.query(`
          SELECT id FROM usuarios 
          WHERE ((email = $1 AND $1 IS NOT NULL) OR (matricula = $2 AND $2 IS NOT NULL)) 
            AND id != $3
        `, [cleanEmail, cleanMatricula, numericId]);

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
      const perfilFinal = perfil || null;

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
        cleanEmail,
        cleanMatricula,
        departamentoId !== undefined ? String(departamentoId) : null,
        departamentoId ? parseInt(departamentoId, 10) : null,
        perfilFinal,
        hasRh,
        hasTi,
        needsMfa,
        ativo !== undefined ? Boolean(ativo) : null,
        numericId
      ]);

      if (ativo === false || perfilFinal || hasRh !== null || hasTi !== null) {
        await TokenService.incrementarTokenVersion(numericId);
      }

      return res.status(200).json({
        message: 'Usuário atualizado com sucesso.',
        usuario: updateRes.rows[0]
      });
    } catch (error) {
      console.error('[AdminUsuariosController.updateUsuario] Erro:', error);
      return res.status(500).json({ error: 'Erro ao atualizar usuário.' });
    }
  }

  public static async toggleStatusUsuario(req: AuthenticatedRequest, res: Response) {
    try {
      const { id } = req.params;
      const numericId = parseInt(id, 10);
      if (isNaN(numericId) || numericId <= 0) {
        return res.status(400).json({ error: 'ID de usuário inválido.' });
      }

      const { ativo } = req.body;

      let result;
      if (ativo !== undefined) {
        result = await pool.query(`
          UPDATE usuarios
          SET ativo = $1
          WHERE id = $2
          RETURNING id, nome, email, matricula, perfil, ativo
        `, [Boolean(ativo), numericId]);
      } else {
        result = await pool.query(`
          UPDATE usuarios
          SET ativo = NOT ativo
          WHERE id = $1
          RETURNING id, nome, email, matricula, perfil, ativo
        `, [numericId]);
      }

      if (result.rowCount === 0) {
        return res.status(404).json({ error: 'Usuário não encontrado.' });
      }

      // Se inativou ou alterou status, revoga sessões ativas imediatamente
      await TokenService.incrementarTokenVersion(numericId);

      return res.status(200).json({
        message: `Status do usuário alterado para ${result.rows[0].ativo ? 'Ativo' : 'Inativo'}.`,
        usuario: result.rows[0]
      });
    } catch (error) {
      console.error('[AdminUsuariosController.toggleStatusUsuario] Erro:', error);
      return res.status(500).json({ error: 'Erro ao alterar status do usuário.' });
    }
  }

  public static async resetSenhaUsuario(req: AuthenticatedRequest, res: Response) {
    try {
      const { id } = req.params;
      const numericId = parseInt(id, 10);
      if (isNaN(numericId) || numericId <= 0) {
        return res.status(400).json({ error: 'ID de usuário inválido.' });
      }

      const { novaSenha } = req.body;

      if (!novaSenha) {
        return res.status(400).json({ error: 'A nova senha é obrigatória.' });
      }

      const pwCheck = validatePasswordPolicy(novaSenha);
      if (!pwCheck.valid) {
        return res.status(400).json({ error: pwCheck.message });
      }

      const senhaHash = await bcrypt.hash(novaSenha.trim(), 10);

      const result = await pool.query(`
        UPDATE usuarios
        SET senha_hash = $1
        WHERE id = $2
        RETURNING id, nome, email, matricula
      `, [senhaHash, numericId]);

      if (result.rowCount === 0) {
        return res.status(404).json({ error: 'Usuário não encontrado.' });
      }

      // Invalida sessões anteriores após reset administrativo
      await TokenService.incrementarTokenVersion(numericId);

      return res.status(200).json({
        message: 'Senha do usuário redefinida com sucesso.'
      });
    } catch (error) {
      console.error('[AdminUsuariosController.resetSenhaUsuario] Erro:', error);
      return res.status(500).json({ error: 'Erro ao redefinir senha do usuário.' });
    }
  }

  public static async importarLoteUsuarios(req: AuthenticatedRequest, res: Response) {
    const client = await pool.connect();
    try {
      const { usuarios, defaultSenha = 'Mudar@123' } = req.body;

      if (!Array.isArray(usuarios) || usuarios.length === 0) {
        return res.status(400).json({ error: 'Envie uma lista de usuários para importação.' });
      }

      const defaultPwCheck = validatePasswordPolicy(defaultSenha);
      if (!defaultPwCheck.valid) {
        return res.status(400).json({ error: `Senha padrão inválida: ${defaultPwCheck.message}` });
      }

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

        if (u.senha) {
          const userPwCheck = validatePasswordPolicy(u.senha);
          if (!userPwCheck.valid) {
            erros.push({ linha: linhaNum, email: u.email || '', matricula: u.matricula || '', erro: `Senha inválida: ${userPwCheck.message}` });
            continue;
          }
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

        let depId: number | null = null;
        if (u.departamentoId) {
          depId = parseInt(u.departamentoId, 10);
        } else if (u.departamento && String(u.departamento).trim().length > 0) {
          const depNome = String(u.departamento).trim();
          const depKey = depNome.toLowerCase();
          if (depMap.has(depKey)) {
            depId = depMap.get(depKey)!;
          } else {
            const novoDep = await client.query(
              'INSERT INTO departamentos (nome) VALUES ($1) ON CONFLICT (nome) DO UPDATE SET nome = EXCLUDED.nome RETURNING id',
              [depNome]
            );
            depId = novoDep.rows[0].id;
            depMap.set(depKey, depId!);
          }
        }

        const senhaHash = u.senha ? await bcrypt.hash(String(u.senha).trim(), 10) : hashPadrao;

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
      console.error('[AdminUsuariosController.importarLoteUsuarios] Erro:', error);
      return res.status(500).json({ error: 'Erro ao processar importação em lote.' });
    } finally {
      client.release();
    }
  }
}
