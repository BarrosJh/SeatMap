import { Request, Response } from 'express';
import crypto from 'crypto';
import bcrypt from 'bcrypt';
import { DateTime } from 'luxon';
import pool from '../../config/db';
import { EmailService } from '../../services/emailService';
import { AuditService } from '../../services/auditService';
import { validatePasswordPolicy } from '../../utils/passwordValidator';
import { TokenService } from '../../services/tokenService';

export class PasswordResetController {
  public static async solicitarRecuperacaoSenha(req: Request, res: Response) {
    const { login } = req.body;
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

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
        return res.status(200).json({
          message: 'Se a matrícula ou e-mail estiver cadastrado, um código de redefinição será enviado.'
        });
      }

      const user = userRes.rows[0];
      const codigo = crypto.randomInt(100000, 1000000).toString();
      const expiraMin = 15;
      const expiraEm = DateTime.now().plus({ minutes: expiraMin }).toJSDate();

      await pool.query(`
        UPDATE auth_password_resets
        SET utilizado = true
        WHERE usuario_id = $1 AND utilizado = false
      `, [user.id]);

      await pool.query(`
        INSERT INTO auth_password_resets (usuario_id, codigo, expira_em, utilizado, tentativas)
        VALUES ($1, $2, $3, false, 0)
      `, [user.id, codigo, expiraEm]);

      EmailService.enviarCodigoRecuperacaoSenha(user.email, user.nome, codigo, expiraMin).catch(err => {
        console.error('[PasswordResetController.solicitarRecuperacaoSenha] Erro ao enviar e-mail:', err);
      });

      AuditService.log({
        usuarioId: user.id,
        loginInformado: login,
        tipoEvento: 'SENHA_RESET_SOLICITADO',
        sucesso: true,
        ip,
        userAgent
      });

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
      console.error('[PasswordResetController.solicitarRecuperacaoSenha] Erro:', error);
      return res.status(500).json({ error: 'Erro ao solicitar recuperação de senha.' });
    }
  }

  public static async redefinirSenha(req: Request, res: Response) {
    const { login, codigo, novaSenha } = req.body;
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

    if (!login || !codigo || !novaSenha) {
      return res.status(400).json({ error: 'Login, código de verificação e nova senha são obrigatórios.' });
    }

    if (String(codigo).trim().length !== 6) {
      return res.status(400).json({ error: 'O código de verificação deve ter 6 dígitos numéricos.' });
    }

    const pwCheck = validatePasswordPolicy(novaSenha);
    if (!pwCheck.valid) {
      return res.status(400).json({ error: pwCheck.message });
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

      if (resetRecord.tentativas >= 5) {
        await pool.query('UPDATE auth_password_resets SET utilizado = true WHERE id = $1', [resetRecord.id]);
        return res.status(400).json({ error: 'Limite de tentativas excedido. Solicite um novo código de recuperação.' });
      }

      if (new Date(resetRecord.expira_em) < new Date()) {
        await pool.query('UPDATE auth_password_resets SET utilizado = true WHERE id = $1', [resetRecord.id]);
        return res.status(400).json({ error: 'O código de verificação expirou. Solicite um novo código.' });
      }

      if (resetRecord.codigo !== String(codigo).trim()) {
        await pool.query('UPDATE auth_password_resets SET tentativas = tentativas + 1 WHERE id = $1', [resetRecord.id]);
        const restantes = 5 - (resetRecord.tentativas + 1);
        return res.status(400).json({
          error: `Código incorreto. Você ainda tem ${restantes} tentativa(s).`
        });
      }

      const saltRounds = 10;
      const novaSenhaHash = await bcrypt.hash(String(novaSenha), saltRounds);

      await pool.query('UPDATE usuarios SET senha_hash = $1, tentativas_login_falhas = 0, bloqueado_ate = NULL WHERE id = $2', [novaSenhaHash, user.id]);
      await pool.query('UPDATE auth_password_resets SET utilizado = true WHERE id = $1', [resetRecord.id]);

      // Revoga instantaneamente todas as sessões anteriores após redefinição de senha
      await TokenService.incrementarTokenVersion(user.id);

      AuditService.log({
        usuarioId: user.id,
        tipoEvento: 'SENHA_RESET_CONCLUIDO',
        sucesso: true,
        ip,
        userAgent
      });

      return res.status(200).json({
        message: 'Senha alterada com sucesso! Você já pode realizar login com sua nova senha.'
      });
    } catch (error) {
      console.error('[PasswordResetController.redefinirSenha] Erro:', error);
      return res.status(500).json({ error: 'Erro ao redefinir senha do usuário.' });
    }
  }
}
