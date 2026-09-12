import { Request, Response } from 'express';
import bcrypt from 'bcrypt';
import crypto from 'crypto';
import pool from '../config/db';
import { TokenService } from '../services/tokenService';
import { logger } from '../utils/logger';
import { BCRYPT_SALT_ROUNDS } from '../config/securityConstants';

const SCIM_USER_SCHEMA = 'urn:ietf:params:scim:schemas:core:2.0:User';
const SCIM_LIST_SCHEMA = 'urn:ietf:params:scim:api:messages:2.0:ListResponse';
const SCIM_ERROR_SCHEMA = 'urn:ietf:params:scim:api:messages:2.0:Error';
const SCIM_CONFIG_SCHEMA = 'urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig';

function formatScimUser(user: any, baseUrl = '/api/scim/v2/Users') {
  const nameParts = (user.nome || '').trim().split(' ');
  const givenName = nameParts[0] || '';
  const familyName = nameParts.slice(1).join(' ') || '';

  return {
    schemas: [SCIM_USER_SCHEMA],
    id: String(user.id),
    externalId: user.matricula || String(user.id),
    userName: user.email,
    displayName: user.nome,
    name: {
      formatted: user.nome,
      givenName,
      familyName
    },
    emails: [
      {
        value: user.email,
        type: 'work',
        primary: true
      }
    ],
    active: Boolean(user.ativo),
    meta: {
      resourceType: 'User',
      created: user.criado_em ? new Date(user.criado_em).toISOString() : new Date().toISOString(),
      lastModified: user.atualizado_em ? new Date(user.atualizado_em).toISOString() : new Date().toISOString(),
      location: `${baseUrl}/${user.id}`
    }
  };
}

export class ScimController {
  /**
   * GET /api/scim/v2/ServiceProviderConfig
   * RFC 7644 §5: Discovery Specification
   */
  public static async getServiceProviderConfig(req: Request, res: Response) {
    return res.status(200).json({
      schemas: [SCIM_CONFIG_SCHEMA],
      documentationUri: 'https://datatracker.ietf.org/doc/html/rfc7644',
      patch: { supported: true },
      bulk: { supported: false, maxOperations: 0, maxPayloadSize: 0 },
      filter: { supported: true, maxResults: 500 },
      changePassword: { supported: false },
      sort: { supported: false },
      etag: { supported: false },
      authenticationSchemes: [
        {
          name: 'OAuth Bearer Token',
          description: 'Authentication scheme using the OAuth Bearer Standard RFC 6750',
          specUri: 'https://tools.ietf.org/html/rfc6750',
          type: 'oauthbearertoken',
          primary: true
        }
      ],
      meta: {
        resourceType: 'ServiceProviderConfig',
        created: new Date().toISOString(),
        lastModified: new Date().toISOString(),
        location: '/api/scim/v2/ServiceProviderConfig'
      }
    });
  }

  /**
   * GET /api/scim/v2/Users
   * RFC 7644 §3.4.2: List/Query Users
   */
  public static async getUsers(req: Request, res: Response) {
    try {
      const startIndex = Math.max(parseInt(req.query.startIndex as string, 10) || 1, 1);
      const count = Math.min(Math.max(parseInt(req.query.count as string, 10) || 100, 1), 500);
      const filter = typeof req.query.filter === 'string' ? req.query.filter.trim() : '';

      const conditions: string[] = [];
      const values: any[] = [];
      let idx = 1;

      // Suporte a filtros comuns do SCIM: userName eq "foo@bar.com" ou emails.value eq "foo@bar.com"
      if (filter) {
        const userNameMatch = filter.match(/(?:userName|emails\.value)\s+eq\s+["']([^"']+)["']/i);
        const externalIdMatch = filter.match(/externalId\s+eq\s+["']([^"']+)["']/i);

        if (userNameMatch) {
          conditions.push(`email = $${idx}`);
          values.push(userNameMatch[1].trim().toLowerCase());
          idx++;
        } else if (externalIdMatch) {
          conditions.push(`matricula = $${idx}`);
          values.push(externalIdMatch[1].trim());
          idx++;
        } else {
          return res.status(400).json({
            schemas: [SCIM_ERROR_SCHEMA],
            scimType: 'invalidFilter',
            status: '400',
            detail: `The specified SCIM filter '${filter}' is not supported. Supported attributes: userName eq, emails.value eq, externalId eq.`
          });
        }
      }

      const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

      const countRes = await pool.query(`SELECT COUNT(*) AS total FROM usuarios ${whereClause}`, values);
      const totalResults = parseInt(countRes.rows[0].total, 10);

      const offset = startIndex - 1;
      const dataQuery = `
        SELECT id, nome, email, matricula, ativo, criado_em, atualizado_em
        FROM usuarios
        ${whereClause}
        ORDER BY id ASC
        LIMIT $${idx} OFFSET $${idx + 1}
      `;

      values.push(count);
      values.push(offset);

      const result = await pool.query(dataQuery, values);
      const resources = result.rows.map(row => formatScimUser(row));

      return res.status(200).json({
        schemas: [SCIM_LIST_SCHEMA],
        totalResults,
        startIndex,
        itemsPerPage: resources.length,
        Resources: resources
      });
    } catch (error) {
      logger.error('[ScimController.getUsers] Erro:', { correlationId: (req as any).correlationId, error });
      return res.status(500).json({
        schemas: [SCIM_ERROR_SCHEMA],
        status: '500',
        detail: 'Erro interno ao consultar usuários SCIM.'
      });
    }
  }

  /**
   * GET /api/scim/v2/Users/:id
   * RFC 7644 §3.4.1: Retrieve User
   */
  public static async getUserById(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const numericId = parseInt(id, 10);
      if (isNaN(numericId) || numericId <= 0) {
        return res.status(400).json({
          schemas: [SCIM_ERROR_SCHEMA],
          scimType: 'invalidSyntax',
          status: '400',
          detail: `O ID de usuário '${id}' é inválido. Deve ser um número inteiro.`
        });
      }

      const result = await pool.query(`
        SELECT id, nome, email, matricula, ativo, criado_em, atualizado_em
        FROM usuarios
        WHERE id = $1
      `, [numericId]);

      if (result.rowCount === 0) {
        return res.status(404).json({
          schemas: [SCIM_ERROR_SCHEMA],
          status: '404',
          detail: `Usuário com ID ${id} não encontrado.`
        });
      }

      return res.status(200).json(formatScimUser(result.rows[0]));
    } catch (error) {
      logger.error('[ScimController.getUserById] Erro:', { correlationId: (req as any).correlationId, error });
      return res.status(500).json({
        schemas: [SCIM_ERROR_SCHEMA],
        status: '500',
        detail: 'Erro interno ao obter usuário SCIM.'
      });
    }
  }

  /**
   * POST /api/scim/v2/Users
   * RFC 7644 §3.3: Create User
   */
  public static async createUser(req: Request, res: Response) {
    try {
      const { userName, name, displayName, emails, externalId, active = true } = req.body;

      const email = (userName || (emails && emails[0] && emails[0].value) || '').trim().toLowerCase();
      const nome = (displayName || (name && name.formatted) || (name ? `${name.givenName || ''} ${name.familyName || ''}`.trim() : '') || email.split('@')[0]).trim();
      const matricula = (externalId || email.split('@')[0] || `SCIM_${Date.now()}`).trim();

      const RFC5322_EMAIL_REGEX = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$/;
      if (!email || !RFC5322_EMAIL_REGEX.test(email)) {
        return res.status(400).json({
          schemas: [SCIM_ERROR_SCHEMA],
          scimType: 'invalidValue',
          status: '400',
          detail: 'O campo userName ou emails deve conter um endereço de e-mail válido (RFC 5322).'
        });
      }

      // Checa duplicidade
      const checkExists = await pool.query('SELECT id, nome, email, matricula, ativo, criado_em, atualizado_em FROM usuarios WHERE email = $1', [email]);
      if (checkExists.rowCount! > 0) {
        return res.status(409).json({
          schemas: [SCIM_ERROR_SCHEMA],
          status: '409',
          detail: `Usuário com e-mail ${email} já existe no sistema.`
        });
      }

      const randomPassword = crypto.randomBytes(16).toString('hex') + 'A1!';
      const senhaHash = await bcrypt.hash(randomPassword, BCRYPT_SALT_ROUNDS);

      const insertRes = await pool.query(`
        INSERT INTO usuarios (nome, email, matricula, senha_hash, perfil, ativo, criado_em, atualizado_em)
        VALUES ($1, $2, $3, $4, 'COLABORADOR', $5, NOW(), NOW())
        RETURNING id, nome, email, matricula, ativo, criado_em, atualizado_em
      `, [nome, email, matricula, senhaHash, Boolean(active)]);

      const created = insertRes.rows[0];
      return res.status(201).json(formatScimUser(created));
    } catch (error) {
      logger.error('[ScimController.createUser] Erro:', { correlationId: (req as any).correlationId, error });
      return res.status(500).json({
        schemas: [SCIM_ERROR_SCHEMA],
        status: '500',
        detail: 'Erro interno ao provisionar usuário SCIM.'
      });
    }
  }

  /**
   * PUT /api/scim/v2/Users/:id
   * RFC 7644 §3.5.1: Replace User
   */
  public static async updateUser(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const numericId = parseInt(id, 10);
      if (isNaN(numericId) || numericId <= 0) {
        return res.status(400).json({
          schemas: [SCIM_ERROR_SCHEMA],
          scimType: 'invalidSyntax',
          status: '400',
          detail: `O ID de usuário '${id}' é inválido. Deve ser um número inteiro.`
        });
      }

      const { userName, name, displayName, emails, externalId, active } = req.body;

      const email = userName || (emails && emails[0] && emails[0].value);
      const nome = displayName || (name && name.formatted) || (name ? `${name.givenName || ''} ${name.familyName || ''}`.trim() : undefined);

      const updateRes = await pool.query(`
        UPDATE usuarios
        SET
          nome = COALESCE($1, nome),
          email = COALESCE($2, email),
          matricula = COALESCE($3, matricula),
          ativo = CASE WHEN $4::text IS NOT NULL THEN $5::boolean ELSE ativo END,
          atualizado_em = NOW()
        WHERE id = $6
        RETURNING id, nome, email, matricula, ativo, criado_em, atualizado_em
      `, [
        nome ? nome.trim() : null,
        email ? email.trim().toLowerCase() : null,
        externalId ? externalId.trim() : null,
        active !== undefined ? String(active) : null,
        active !== undefined ? Boolean(active) : null,
        numericId
      ]);

      if (updateRes.rowCount === 0) {
        return res.status(404).json({
          schemas: [SCIM_ERROR_SCHEMA],
          status: '404',
          detail: `Usuário ${id} não encontrado para atualização.`
        });
      }

      if (active === false) {
        await TokenService.incrementarTokenVersion(numericId);
      }

      return res.status(200).json(formatScimUser(updateRes.rows[0]));
    } catch (error) {
      logger.error('[ScimController.updateUser] Erro:', { correlationId: (req as any).correlationId, error });
      return res.status(500).json({
        schemas: [SCIM_ERROR_SCHEMA],
        status: '500',
        detail: 'Erro interno ao atualizar usuário SCIM.'
      });
    }
  }

  /**
   * PATCH /api/scim/v2/Users/:id
   * RFC 7644 §3.5.2: Modify User (ex: Desativação via active: false)
   */
  public static async patchUser(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const numericId = parseInt(id, 10);
      if (isNaN(numericId) || numericId <= 0) {
        return res.status(400).json({
          schemas: [SCIM_ERROR_SCHEMA],
          scimType: 'invalidSyntax',
          status: '400',
          detail: `O ID de usuário '${id}' é inválido. Deve ser um número inteiro.`
        });
      }

      const { Operations = [] } = req.body;

      let novoAtivo: boolean | null = null;
      let novoNome: string | null = null;
      let novoEmail: string | null = null;

      for (const op of Operations) {
        const opType = (op.op || '').toLowerCase();
        if (opType === 'replace' || opType === 'add') {
          if (typeof op.value === 'object' && op.value !== null) {
            if (op.value.active !== undefined) novoAtivo = Boolean(op.value.active);
            if (op.value.displayName) novoNome = String(op.value.displayName).trim();
            if (op.value.userName) novoEmail = String(op.value.userName).trim().toLowerCase();
          } else if (op.path) {
            const pathLower = op.path.toLowerCase();
            if (pathLower === 'active') novoAtivo = Boolean(op.value);
            if (pathLower === 'displayname' || pathLower === 'name.formatted') novoNome = String(op.value).trim();
            if (pathLower === 'username' || pathLower === 'emails[type eq "work"].value') novoEmail = String(op.value).trim().toLowerCase();
          }
        }
      }

      const updateRes = await pool.query(`
        UPDATE usuarios
        SET
          ativo = CASE WHEN $1::text IS NOT NULL THEN $2::boolean ELSE ativo END,
          nome = COALESCE($3, nome),
          email = COALESCE($4, email),
          atualizado_em = NOW()
        WHERE id = $5
        RETURNING id, nome, email, matricula, ativo, criado_em, atualizado_em
      `, [
        novoAtivo !== null ? String(novoAtivo) : null,
        novoAtivo !== null ? novoAtivo : null,
        novoNome,
        novoEmail,
        numericId
      ]);

      if (updateRes.rowCount === 0) {
        return res.status(404).json({
          schemas: [SCIM_ERROR_SCHEMA],
          status: '404',
          detail: `Usuário ${id} não encontrado para modificação.`
        });
      }

      if (novoAtivo === false) {
        await TokenService.incrementarTokenVersion(numericId);
      }

      return res.status(200).json(formatScimUser(updateRes.rows[0]));
    } catch (error) {
      logger.error('[ScimController.patchUser] Erro:', { correlationId: (req as any).correlationId, error });
      return res.status(500).json({
        schemas: [SCIM_ERROR_SCHEMA],
        status: '500',
        detail: 'Erro interno ao modificar usuário SCIM.'
      });
    }
  }

  /**
   * DELETE /api/scim/v2/Users/:id
   * RFC 7644 §3.6: Delete / Deprovision User (Safe Soft-Deactivate)
   */
  public static async deleteUser(req: Request, res: Response) {
    try {
      const { id } = req.params;
      const numericId = parseInt(id, 10);
      if (isNaN(numericId) || numericId <= 0) {
        return res.status(400).json({
          schemas: [SCIM_ERROR_SCHEMA],
          scimType: 'invalidSyntax',
          status: '400',
          detail: `O ID de usuário '${id}' é inválido. Deve ser um número inteiro.`
        });
      }

      const result = await pool.query(`
        UPDATE usuarios
        SET ativo = false, atualizado_em = NOW()
        WHERE id = $1
        RETURNING id
      `, [numericId]);

      if (result.rowCount === 0) {
        return res.status(404).json({
          schemas: [SCIM_ERROR_SCHEMA],
          status: '404',
          detail: `Usuário ${id} não encontrado para desprovisionamento.`
        });
      }

      // Revoga instantaneamente todas as sessões do usuário desprovisionado
      await TokenService.incrementarTokenVersion(numericId);

      return res.status(204).send();
    } catch (error) {
      logger.error('[ScimController.deleteUser] Erro:', { correlationId: (req as any).correlationId, error });
      return res.status(500).json({
        schemas: [SCIM_ERROR_SCHEMA],
        status: '500',
        detail: 'Erro interno ao desprovisionar usuário SCIM.'
      });
    }
  }
}

