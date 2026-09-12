import bcrypt from 'bcrypt';
import crypto from 'crypto';
import pool from '../config/db';
import { getDbClient } from '../utils/dbClient';
import { validatePasswordPolicy } from '../utils/passwordValidator';
import { TokenService } from './tokenService';
import { escapeSqlWildcards } from '../utils/sanitizer';
import { AuditService } from './auditService';
import { BCRYPT_SALT_ROUNDS } from '../config/securityConstants';

export interface ListarUsuariosOptions {
  busca?: string;
  departamentoId?: string | number;
  perfil?: string;
  ativo?: string | boolean;
  limit?: number;
  offset?: number;
}

export interface CriarUsuarioInput {
  nome: string;
  email: string;
  matricula: string;
  senha: string;
  departamentoId?: number | null;
  perfil: string;
  permissaoRh?: boolean;
  permissao_rh?: boolean;
  permissaoTi?: boolean;
  permissao_ti?: boolean;
  exigirMfa?: boolean;
  exigir_mfa?: boolean;
}

export interface UpdateUsuarioInput {
  nome?: string;
  email?: string;
  matricula?: string;
  departamentoId?: number | null;
  perfil?: string;
  permissaoRh?: boolean;
  permissao_rh?: boolean;
  permissaoTi?: boolean;
  permissao_ti?: boolean;
  exigirMfa?: boolean;
  exigir_mfa?: boolean;
  ativo?: boolean;
}

export class UsuarioService {
  /**
   * Consulta paginada com filtros seguros e escape de wildcards
   */
  public static async listarUsuarios(options: ListarUsuariosOptions) {
    const { busca, departamentoId, perfil, ativo, limit = 100, offset = 0 } = options;

    const conditions: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (busca && typeof busca === 'string' && busca.trim().length > 0) {
      conditions.push(`(u.nome ILIKE $${idx} OR u.email ILIKE $${idx} OR u.matricula ILIKE $${idx})`);
      values.push(`%${escapeSqlWildcards(busca.trim())}%`);
      idx++;
    }

    if (departamentoId && departamentoId !== 'todos') {
      conditions.push(`u.departamento_id = $${idx}`);
      values.push(parseInt(String(departamentoId), 10));
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

    const listQuery = `
      SELECT 
        u.id, 
        u.nome, 
        u.email, 
        u.matricula, 
        u.departamento_id, 
        d.nome AS departamento_nome,
        u.perfil, 
        COALESCE(u.permissao_rh, false) AS permissao_rh,
        COALESCE(u.permissao_ti, false) AS permissao_ti,
        COALESCE(u.exigir_mfa, false) AS exigir_mfa,
        COALESCE(u.totp_ativo, false) AS totp_ativo,
        u.ativo, 
        u.criado_em,
        u.ultimo_login
      FROM usuarios u
      LEFT JOIN departamentos d ON u.departamento_id = d.id
      ${whereClause}
      ORDER BY u.nome ASC
      LIMIT $${idx} OFFSET $${idx + 1}
    `;

    values.push(limit, offset);
    const listRes = await pool.query(listQuery, values);

    return {
      total,
      usuarios: listRes.rows
    };
  }

  /**
   * Cria um novo usuário com validação de duplicidade, políticas de senha e RBAC de TI
   */
  public static async criarUsuario(input: CriarUsuarioInput, operatorIsTi: boolean) {
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
      exigir_mfa 
    } = input;

    if (!nome || !email || !matricula || !senha) {
      return { success: false, code: 400, error: 'Nome, e-mail, matrícula e senha são obrigatórios.' };
    }

    const pwCheck = validatePasswordPolicy(senha);
    if (!pwCheck.valid) {
      return { success: false, code: 400, error: pwCheck.message };
    }

    if (!['COLABORADOR', 'GESTAO', 'ADMIN_RH', 'ADMIN_TI'].includes(perfil)) {
      return { success: false, code: 400, error: 'Perfil inválido. Deve ser COLABORADOR, GESTAO, ADMIN_RH ou ADMIN_TI.' };
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

    if ((hasTi || perfil === 'ADMIN_TI') && !operatorIsTi) {
      return { success: false, code: 403, error: 'Não é permitido conceder privilégios de Administrador de TI sem possuir a permissão correspondente.' };
    }

    const checkExists = await pool.query(`
      SELECT id FROM usuarios WHERE LOWER(email) = LOWER($1) OR LOWER(matricula) = LOWER($2)
    `, [email.trim().toLowerCase(), matricula.trim()]);

    if (checkExists.rowCount! > 0) {
      return { success: false, code: 400, error: 'Já existe um usuário com este e-mail ou matrícula.' };
    }

    const senhaHash = await bcrypt.hash(senha, BCRYPT_SALT_ROUNDS);

    const insertRes = await pool.query(`
      INSERT INTO usuarios (nome, email, matricula, senha_hash, departamento_id, perfil, permissao_rh, permissao_ti, exigir_mfa, ativo)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
      RETURNING id, nome, email, matricula, departamento_id, perfil, permissao_rh, permissao_ti, exigir_mfa, ativo
    `, [
      nome.trim(),
      email.trim().toLowerCase(),
      matricula.trim(),
      senhaHash,
      departamentoId || null,
      perfil,
      hasRh,
      hasTi,
      needsMfa,
      true
    ]);

    AuditService.log({
      usuarioId: insertRes.rows[0]?.id ?? null,
      loginInformado: insertRes.rows[0]?.email || email.trim().toLowerCase(),
      tipoEvento: 'USUARIO_CRIADO',
      sucesso: true,
      detalhes: {
        perfil,
        departamentoId: departamentoId || null,
        exigiuMfa: needsMfa,
        operadorTi: operatorIsTi
      }
    });

    return {
      success: true,
      code: 201,
      message: 'Usuário cadastrado com sucesso.',
      usuario: insertRes.rows[0]
    };
  }

  /**
   * Atualiza dados de um usuário existente com checagem de RBAC de TI e duplicidade
   */
  public static async updateUsuario(id: number, input: UpdateUsuarioInput, operatorIsTi: boolean) {
    const userExists = await pool.query('SELECT id, perfil, permissao_ti FROM usuarios WHERE id = $1', [id]);
    if (userExists.rowCount === 0) {
      return { success: false, code: 404, error: 'Usuário não encontrado.' };
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
    } = input;

    const cleanEmail = email ? email.trim().toLowerCase() : null;
    const cleanMatricula = matricula ? matricula.trim() : null;

    if (cleanEmail || cleanMatricula) {
      const checkDuplicate = await pool.query(`
        SELECT id FROM usuarios 
        WHERE ((LOWER(email) = LOWER($1) AND $1 IS NOT NULL) OR (LOWER(matricula) = LOWER($2) AND $2 IS NOT NULL)) 
          AND id != $3
      `, [cleanEmail, cleanMatricula, id]);

      if (checkDuplicate.rowCount! > 0) {
        return { success: false, code: 400, error: 'E-mail ou matrícula já pertencem a outro usuário.' };
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

    if ((hasTi === true || perfilFinal === 'ADMIN_TI') && !operatorIsTi) {
      return { success: false, code: 403, error: 'Não é permitido conceder privilégios de Administrador de TI sem possuir a permissão correspondente.' };
    }

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
      departamentoId ? parseInt(String(departamentoId), 10) : null,
      perfilFinal,
      hasRh,
      hasTi,
      needsMfa,
      ativo !== undefined ? Boolean(ativo) : null,
      id
    ]);

    AuditService.log({
      usuarioId: id,
      loginInformado: cleanEmail || cleanMatricula || undefined,
      tipoEvento: 'USUARIO_ATUALIZADO',
      sucesso: true,
      detalhes: {
        campos: Object.keys(input),
        perfilAnterior: userExists.rows[0]?.perfil,
        perfilNovo: perfil || userExists.rows[0]?.perfil,
        departamentoId: departamentoId !== undefined ? (departamentoId ?? null) : undefined,
        operadorTi: operatorIsTi
      }
    });

    return {
      success: true,
      code: 200,
      message: 'Usuário atualizado com sucesso.',
      usuario: updateRes.rows[0]
    };
  }

  /**
   * Altera status ativo/inativo e revoga sessões imediatamente
   */
  public static async toggleStatusUsuario(id: number, ativo?: boolean) {
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
      return { success: false, code: 404, error: 'Usuário não encontrado.' };
    }

    await TokenService.incrementarTokenVersion(id);

    AuditService.log({
      usuarioId: id,
      tipoEvento: 'USUARIO_STATUS_ALTERADO',
      sucesso: true,
      detalhes: {
        ativo: Boolean(ativo ?? result.rows[0].ativo)
      }
    });

    return {
      success: true,
      code: 200,
      message: `Status do usuário alterado para ${result.rows[0].ativo ? 'Ativo' : 'Inativo'}.`,
      usuario: result.rows[0]
    };
  }

  /**
   * Redefine a senha do usuário e invalida sessões anteriores
   */
  public static async resetSenhaUsuario(id: number, novaSenha: string) {
    if (!novaSenha) {
      return { success: false, code: 400, error: 'A nova senha é obrigatória.' };
    }

    const pwCheck = validatePasswordPolicy(novaSenha);
    if (!pwCheck.valid) {
      return { success: false, code: 400, error: pwCheck.message };
    }

    const senhaHash = await bcrypt.hash(novaSenha.trim(), BCRYPT_SALT_ROUNDS);

    const result = await pool.query(`
      UPDATE usuarios
      SET senha_hash = $1
      WHERE id = $2
      RETURNING id, nome, email, matricula
    `, [senhaHash, id]);

    if (result.rowCount === 0) {
      return { success: false, code: 404, error: 'Usuário não encontrado.' };
    }

    await TokenService.incrementarTokenVersion(id);

    AuditService.log({
      usuarioId: id,
      tipoEvento: 'SENHA_RESETADA',
      sucesso: true,
      detalhes: { motivo: 'Redefinição de senha por administrador' }
    });

    return {
      success: true,
      code: 200,
      message: 'Senha do usuário redefinida com sucesso.'
    };
  }

  /**
   * Importação em lote de usuários com transação atômica
   */
  public static async importarLoteUsuarios(usuarios: any[], defaultSenhaParam: string | undefined, operatorIsTi: boolean) {
    if (!Array.isArray(usuarios) || usuarios.length === 0) {
      return { success: false, code: 400, error: 'Envie uma lista de usuários para importação.' };
    }

    const fallbackPw = process.env.SEED_DEFAULT_PASSWORD || `Temp@${crypto.randomBytes(4).toString('hex')}123`;
    const defaultSenha = defaultSenhaParam || fallbackPw;

    const defaultPwCheck = validatePasswordPolicy(defaultSenha);
    if (!defaultPwCheck.valid) {
      return { success: false, code: 400, error: `Senha padrão inválida: ${defaultPwCheck.message}` };
    }

    const client = await getDbClient();
    try {
      await client.query('BEGIN');

      const depRes = await client.query('SELECT id, nome FROM departamentos');
      const depMap = new Map<string, number>();
      depRes.rows.forEach((d: any) => depMap.set(d.nome.toLowerCase().trim(), d.id));

      const hashPadrao = await bcrypt.hash(defaultSenha, BCRYPT_SALT_ROUNDS);

      let criados = 0;
      let atualizados = 0;
      const erros: any[] = [];

      for (const u of usuarios) {
        const nome = u.nome ? String(u.nome).trim() : '';
        const email = u.email ? String(u.email).trim().toLowerCase() : '';
        const matricula = u.matricula ? String(u.matricula).trim() : '';
        const departamentoNome = u.departamento ? String(u.departamento).trim() : '';
        const perfil = u.perfil ? String(u.perfil).trim().toUpperCase() : 'COLABORADOR';

        if (!nome || !email || !matricula) {
          erros.push({ usuario: u, erro: 'Nome, e-mail e matrícula são obrigatórios.' });
          continue;
        }

        if (!['COLABORADOR', 'GESTAO', 'ADMIN_RH', 'ADMIN_TI'].includes(perfil)) {
          erros.push({ usuario: u, erro: `Perfil '${perfil}' inválido.` });
          continue;
        }

        let deptoId: number | null = null;
        if (departamentoNome) {
          const deptoKey = departamentoNome.toLowerCase();
          if (depMap.has(deptoKey)) {
            deptoId = depMap.get(deptoKey)!;
          } else {
            const newDepRes = await client.query('INSERT INTO departamentos (nome) VALUES ($1) RETURNING id', [departamentoNome]);
            deptoId = Number(newDepRes.rows[0].id);
            depMap.set(deptoKey, deptoId);
          }
        }

        const wantsTi = u.permissao_ti === true || u.permissaoTi === true || perfil === 'ADMIN_TI';
        if (wantsTi && !operatorIsTi) {
          erros.push({ usuario: u, erro: 'Não é permitido conceder privilégios de Administrador de TI sem possuir a permissão correspondente.' });
          continue;
        }

        const hasRh = u.permissao_rh === true || u.permissaoRh === true || perfil === 'ADMIN_RH';
        const hasTi = wantsTi;

        const checkRes = await client.query('SELECT id FROM usuarios WHERE LOWER(email) = LOWER($1) OR LOWER(matricula) = LOWER($2)', [email, matricula]);

        if (checkRes.rowCount! > 0) {
          const existingId = checkRes.rows[0].id;
          await client.query(`
            UPDATE usuarios 
            SET nome = $1, departamento_id = COALESCE($2, departamento_id), perfil = $3, permissao_rh = $4, permissao_ti = $5
            WHERE id = $6
          `, [nome, deptoId, perfil, hasRh, hasTi, existingId]);
          await TokenService.incrementarTokenVersion(existingId);
          atualizados++;
        } else {
          await client.query(`
            INSERT INTO usuarios (nome, email, matricula, senha_hash, departamento_id, perfil, permissao_rh, permissao_ti, ativo)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true)
          `, [nome, email, matricula, hashPadrao, deptoId, perfil, hasRh, hasTi]);
          criados++;
        }
      }

      await client.query('COMMIT');

      return {
        success: true,
        code: 200,
        message: 'Importação processada com sucesso.',
        criados,
        atualizados,
        total: criados + atualizados,
        erros: erros.length > 0 ? erros : undefined
      };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}
