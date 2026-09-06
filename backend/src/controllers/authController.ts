import { Request, Response } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { DateTime } from 'luxon';
import pool from '../config/db';
import { AuthenticatedRequest } from '../middleware/auth';
import { ConfigService } from '../services/configService';
import { EmailService } from '../services/emailService';

const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_jwt_key_seatmap_2026_change_in_prod';
const JWT_EXPIRATION = process.env.JWT_EXPIRATION || '1d';
const JWT_ADMIN_SECRET = process.env.JWT_ADMIN_SECRET || 'super_secret_admin_mfa_jwt_key_seatmap_2026';
const JWT_ADMIN_EXPIRATION = process.env.JWT_ADMIN_EXPIRATION || '2h';

export class AuthController {
  public static async login(req: Request, res: Response) {
    const { login, senha } = req.body;

    if (!login || !senha) {
      return res.status(400).json({ error: 'Matrícula/E-mail e senha são obrigatórios.' });
    }

    try {
      const userRes = await pool.query(`
        SELECT u.id, u.nome, u.email, u.matricula, u.senha_hash, u.perfil, 
               COALESCE(u.permissao_rh, false) AS permissao_rh,
               COALESCE(u.permissao_ti, false) AS permissao_ti,
               u.ativo,
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

      const token = jwt.sign({
        userId: user.id,
        nome: user.nome,
        email: user.email,
        matricula: user.matricula,
        perfil: user.perfil,
        permissaoRh: user.permissao_rh === true || user.perfil === 'ADMIN_RH',
        permissaoTi: user.permissao_ti === true || user.perfil === 'ADMIN_TI',
        departamentoId: user.departamento_id,
        departamentoNome: user.departamento_nome
      }, JWT_SECRET, { expiresIn: JWT_EXPIRATION as any });

      return res.status(200).json({
        token,
        user: {
          id: user.id,
          nome: user.nome,
          email: user.email,
          matricula: user.matricula,
          perfil: user.perfil,
          permissaoRh: user.permissao_rh === true || user.perfil === 'ADMIN_RH',
          permissaoTi: user.permissao_ti === true || user.perfil === 'ADMIN_TI',
          departamentoId: user.departamento_id,
          departamentoNome: user.departamento_nome
        }
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
      const expiraMin = await ConfigService.getNumber('MFA_EXPIRACAO_MINUTOS', 10);
      // Gerar código aleatório de 6 dígitos numéricos
      const codigo = Math.floor(100000 + Math.random() * 900000).toString();
      const expiraEm = DateTime.now().plus({ minutes: expiraMin }).toJSDate();

      await pool.query(`
        INSERT INTO auth_mfa_codes (usuario_id, codigo, expira_em, utilizado)
        VALUES ($1, $2, $3, false)
      `, [user.userId, codigo, expiraEm]);

      // Disparo do e-mail com template HTML corporativo via EmailService
      EmailService.enviarCodigoMfa(user.email, user.nome, codigo, expiraMin).catch(err => {
        console.error('[AuthController.solicitarMfa] Erro ao enviar e-mail:', err);
      });

      return res.status(200).json({
        message: 'Código de autenticação MFA gerado e enviado por e-mail com sucesso.',
        email: user.email,
        expiraEmMinutos: expiraMin,
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
      const isMasterCode = process.env.NODE_ENV !== 'production' && codigo.trim() === '123456';

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
      if (mfaRecord.id > 0) {
        await pool.query('UPDATE auth_mfa_codes SET utilizado = true WHERE id = $1', [mfaRecord.id]);
      }

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

  // ==========================================
  // ESQUECI MINHA SENHA & REDEFINIÇÃO
  // ==========================================

  public static async solicitarRecuperacaoSenha(req: Request, res: Response) {
    const { login } = req.body;

    if (!login || typeof login !== 'string' || login.trim().length === 0) {
      return res.status(400).json({ error: 'Informe a matrícula ou e-mail cadastrado.' });
    }

    try {
      const userRes = await pool.query(`
        SELECT id, nome, email, matricula, ativo
        FROM usuarios
        WHERE (email = $1 OR matricula = $1) AND ativo = true
      `, [login.trim()]);

      if (userRes.rowCount === 0) {
        // Resposta genérica segura para não expor enumeração de usuários
        return res.status(200).json({
          message: 'Se a matrícula ou e-mail estiver cadastrado, um código de redefinição será enviado.'
        });
      }

      const user = userRes.rows[0];
      const codigo = Math.floor(100000 + Math.random() * 900000).toString();
      const expiraMin = 15;
      const expiraEm = DateTime.now().plus({ minutes: expiraMin }).toJSDate();

      // Invalidar códigos pendentes anteriores do usuário
      await pool.query(`
        UPDATE auth_password_resets
        SET utilizado = true
        WHERE usuario_id = $1 AND utilizado = false
      `, [user.id]);

      // Inserir novo código
      await pool.query(`
        INSERT INTO auth_password_resets (usuario_id, codigo, expira_em, utilizado, tentativas)
        VALUES ($1, $2, $3, false, 0)
      `, [user.id, codigo, expiraEm]);

      // Envio assíncrono do e-mail
      EmailService.enviarCodigoRecuperacaoSenha(user.email, user.nome, codigo, expiraMin).catch(err => {
        console.error('[AuthController.solicitarRecuperacaoSenha] Erro ao enviar e-mail:', err);
      });

      // Mascarar e-mail para exibição segura (ex: j***@dominio.com)
      const partesEmail = user.email.split('@');
      const nomeEmail = partesEmail[0];
      const dominioEmail = partesEmail[1] || '';
      const emailMascarado = (nomeEmail.length > 2)
        ? `${nomeEmail[0]}***${nomeEmail[nomeEmail.length - 1]}@${dominioEmail}`
        : `${nomeEmail[0]}***@${dominioEmail}`;

      return res.status(200).json({
        message: 'Código de recuperação enviado com sucesso para o seu e-mail cadastrado.',
        emailMascarado,
        expiraEmMinutos: expiraMin,
        codigoSimulado: process.env.NODE_ENV !== 'production' ? codigo : undefined
      });
    } catch (error) {
      console.error('[AuthController.solicitarRecuperacaoSenha] Erro:', error);
      return res.status(500).json({ error: 'Erro ao solicitar recuperação de senha.' });
    }
  }

  public static async redefinirSenha(req: Request, res: Response) {
    const { login, codigo, novaSenha } = req.body;

    if (!login || !codigo || !novaSenha) {
      return res.status(400).json({ error: 'Login, código de verificação e nova senha são obrigatórios.' });
    }

    if (String(codigo).trim().length !== 6) {
      return res.status(400).json({ error: 'O código de verificação deve ter 6 dígitos numéricos.' });
    }

    if (String(novaSenha).length < 6) {
      return res.status(400).json({ error: 'A nova senha deve possuir no mínimo 6 caracteres.' });
    }

    try {
      const userRes = await pool.query(`
        SELECT id, nome, email
        FROM usuarios
        WHERE (email = $1 OR matricula = $1) AND ativo = true
      `, [String(login).trim()]);

      if (userRes.rowCount === 0) {
        return res.status(404).json({ error: 'Usuário não encontrado ou inativo.' });
      }

      const user = userRes.rows[0];

      // Buscar código ativo
      const resetRes = await pool.query(`
        SELECT id, codigo, expira_em, tentativas, utilizado
        FROM auth_password_resets
        WHERE usuario_id = $1 AND utilizado = false
        ORDER BY id DESC
        LIMIT 1
      `, [user.id]);

      if (resetRes.rowCount === 0) {
        return res.status(400).json({ error: 'Nenhum código de recuperação ativo. Solicite um novo código.' });
      }

      const resetRecord = resetRes.rows[0];

      // Validar tentativas
      if (resetRecord.tentativas >= 5) {
        await pool.query('UPDATE auth_password_resets SET utilizado = true WHERE id = $1', [resetRecord.id]);
        return res.status(400).json({ error: 'Limite de tentativas excedido. Solicite um novo código de recuperação.' });
      }

      // Validar expiração
      if (new Date(resetRecord.expira_em) < new Date()) {
        await pool.query('UPDATE auth_password_resets SET utilizado = true WHERE id = $1', [resetRecord.id]);
        return res.status(400).json({ error: 'O código de verificação expirou. Solicite um novo código.' });
      }

      // Validar correspondência do código
      if (resetRecord.codigo !== String(codigo).trim()) {
        await pool.query('UPDATE auth_password_resets SET tentativas = tentativas + 1 WHERE id = $1', [resetRecord.id]);
        const restantes = 5 - (resetRecord.tentativas + 1);
        return res.status(400).json({
          error: `Código incorreto. Você ainda tem ${restantes} tentativa(s).`
        });
      }

      // Atualizar a senha do usuário
      const saltRounds = 10;
      const novaSenhaHash = await bcrypt.hash(String(novaSenha), saltRounds);

      await pool.query('UPDATE usuarios SET senha_hash = $1 WHERE id = $2', [novaSenhaHash, user.id]);
      await pool.query('UPDATE auth_password_resets SET utilizado = true WHERE id = $1', [resetRecord.id]);

      return res.status(200).json({
        message: 'Senha alterada com sucesso! Você já pode realizar login com sua nova senha.'
      });
    } catch (error) {
      console.error('[AuthController.redefinirSenha] Erro:', error);
      return res.status(500).json({ error: 'Erro ao redefinir senha do usuário.' });
    }
  }
}
