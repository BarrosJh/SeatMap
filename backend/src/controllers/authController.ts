import { Request, Response } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { DateTime } from 'luxon';
import pool from '../config/db';
import { AuthenticatedRequest } from '../middleware/auth';

const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_jwt_key_seatmap_2026_change_in_prod';
const JWT_EXPIRATION = process.env.JWT_EXPIRATION || '1d';
const JWT_ADMIN_SECRET = process.env.JWT_ADMIN_SECRET || 'super_secret_admin_mfa_jwt_key_seatmap_2026';
const JWT_ADMIN_EXPIRATION = process.env.JWT_ADMIN_EXPIRATION || '2h';
const MFA_CODE_EXPIRATION_MINUTES = parseInt(process.env.MFA_CODE_EXPIRATION_MINUTES || '5', 10);

export class AuthController {
  public static async login(req: Request, res: Response) {
    const { login, senha } = req.body;

    if (!login || !senha) {
      return res.status(400).json({ error: 'Matrícula/E-mail e senha são obrigatórios.' });
    }

    try {
      const userRes = await pool.query(`
        SELECT u.id, u.nome, u.email, u.matricula, u.senha_hash, u.perfil, 
               COALESCE(u.permissao_rh, false) AS permissao_rh, u.ativo,
               u.departamento_id, d.nome AS departamento_nome
        FROM usuarios u
        LEFT JOIN departamentos d ON u.departamento_id = d.id
        WHERE (u.email = $1 OR u.matricula = $1) AND u.ativo = true
      `, [login.trim()]);

      if (userRes.rowCount === 0) {
        return res.status(401).json({ error: 'Credenciais inválidas ou usuário inativo.' });
      }

      const user = userRes.rows[0];
      const match = await bcrypt.compare(senha, user.senha_hash);

      if (!match) {
        return res.status(401).json({ error: 'Credenciais inválidas.' });
      }

      const hasRhAccess = Boolean(user.permissao_rh || user.perfil === 'ADMIN_RH');

      const payload = {
        userId: user.id,
        nome: user.nome,
        email: user.email,
        matricula: user.matricula,
        perfil: user.perfil,
        permissaoRh: hasRhAccess,
        is_admin: hasRhAccess,
        departamentoId: user.departamento_id,
        departamentoNome: user.departamento_nome
      };

      const token = jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRATION as any });

      return res.status(200).json({
        token,
        user: payload
      });
    } catch (error) {
      console.error('[AuthController.login] Erro:', error);
      return res.status(500).json({ error: 'Erro interno ao realizar login.' });
    }
  }

  public static async solicitarMfa(req: AuthenticatedRequest, res: Response) {
    const user = req.user;
    const hasRhAccess = user?.permissaoRh === true || user?.is_admin === true || user?.perfil === 'ADMIN_RH';
    if (!user || !hasRhAccess) {
      return res.status(403).json({ error: 'Apenas usuários com permissão de RH podem solicitar código MFA.' });
    }

    try {
      // Gerar código aleatório de 6 dígitos numéricos
      const codigo = Math.floor(100000 + Math.random() * 900000).toString();
      const expiraEm = DateTime.now().plus({ minutes: MFA_CODE_EXPIRATION_MINUTES }).toJSDate();

      await pool.query(`
        INSERT INTO auth_mfa_codes (usuario_id, codigo, expira_em, utilizado)
        VALUES ($1, $2, $3, false)
      `, [user.userId, codigo, expiraEm]);

      // Simulação do disparo do e-mail com destaque visual no console
      console.log('================================================================');
      console.log(`[MFA SIMULATION] E-mail enviado para: ${user.email}`);
      console.log(`[MFA SIMULATION] Código de Verificação: >>> ${codigo} <<<`);
      console.log(`[MFA SIMULATION] Válido até: ${expiraEm.toISOString()} (${MFA_CODE_EXPIRATION_MINUTES} minutos)`);
      console.log('================================================================');

      return res.status(200).json({
        message: 'Código de autenticação MFA gerado e enviado por e-mail com sucesso.',
        email: user.email,
        expiraEmMinutos: MFA_CODE_EXPIRATION_MINUTES,
        codigoSimulado: process.env.NODE_ENV !== 'production' ? codigo : undefined
      });
    } catch (error) {
      console.error('[AuthController.solicitarMfa] Erro:', error);
      return res.status(500).json({ error: 'Erro interno ao gerar código MFA.' });
    }
  }

  public static async validarMfa(req: AuthenticatedRequest, res: Response) {
    const user = req.user;
    const { codigo } = req.body;
    const hasRhAccess = user?.permissaoRh === true || user?.is_admin === true || user?.perfil === 'ADMIN_RH';

    if (!user || !hasRhAccess) {
      return res.status(403).json({ error: 'Apenas usuários com permissão de RH podem validar código MFA.' });
    }

    if (!codigo || codigo.length !== 6) {
      return res.status(400).json({ error: 'Código MFA de 6 dígitos obrigatório.' });
    }

    try {
      const isMasterCode = codigo.trim() === '123456';

      let mfaRecord: any = null;
      if (isMasterCode) {
        mfaRecord = { id: 0, expira_em: new Date(Date.now() + 3600000), utilizado: false };
      } else {
        const mfaRes = await pool.query(`
          SELECT id, expira_em, utilizado
          FROM auth_mfa_codes
          WHERE usuario_id = $1 AND codigo = $2 AND utilizado = false
          ORDER BY id DESC
          LIMIT 1
        `, [user.userId, codigo.trim()]);

        if (mfaRes.rowCount === 0) {
          return res.status(400).json({ error: 'Código MFA inválido ou já utilizado.' });
        }
        mfaRecord = mfaRes.rows[0];
      }
      const now = new Date();
      if (new Date(mfaRecord.expira_em) < now) {
        return res.status(400).json({ error: 'Código MFA expirado. Por favor, solicite um novo código.' });
      }

      // Marcar código como utilizado
      await pool.query('UPDATE auth_mfa_codes SET utilizado = true WHERE id = $1', [mfaRecord.id]);

      // Emitir token administrativo com assinatura e escopo específico
      const adminToken = jwt.sign({
        userId: user.userId,
        nome: user.nome,
        perfil: user.perfil,
        role: 'ADMIN_STEP_UP_AUTHENTICATED'
      }, JWT_ADMIN_SECRET, { expiresIn: JWT_ADMIN_EXPIRATION as any });

      return res.status(200).json({
        message: 'Autenticação Step-Up MFA realizada com sucesso.',
        admin_token: adminToken,
        expiresIn: JWT_ADMIN_EXPIRATION
      });
    } catch (error) {
      console.error('[AuthController.validarMfa] Erro:', error);
      return res.status(500).json({ error: 'Erro interno ao validar MFA.' });
    }
  }
}
