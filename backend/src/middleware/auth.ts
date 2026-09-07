import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import pool from '../config/db';
import { ConfigService } from '../services/configService';
import { env } from '../config/env';

export interface AuthUser {
  userId: number;
  nome: string;
  email: string;
  matricula: string;
  perfil: 'COLABORADOR' | 'GESTAO' | 'ADMIN_RH' | 'ADMIN_TI';
  permissaoRh?: boolean;
  permissaoTi?: boolean;
  is_admin?: boolean;
  departamentoId: number | null;
  departamentoNome?: string;
  tokenVersion?: number;
}

export interface AuthenticatedRequest extends Request {
  user?: AuthUser;
  isAdminMfaValidated?: boolean;
}

const JWT_SECRET = env.JWT_SECRET;
const JWT_ADMIN_SECRET = env.JWT_ADMIN_SECRET;

export const authenticateToken = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Token de autenticação não fornecido' });
  }

  jwt.verify(token, JWT_SECRET, async (err, decoded: any) => {
    if (err || !decoded || !decoded.userId) {
      return res.status(403).json({ error: 'Token inválido ou expirado' });
    }

    try {
      // Validação de Revogação Instantânea de Sessão e Status Ativo no Banco
      const userCheck = await pool.query(
        'SELECT ativo, COALESCE(token_version, 1) AS token_version FROM usuarios WHERE id = $1',
        [decoded.userId]
      );

      if (userCheck.rowCount === 0 || !userCheck.rows[0].ativo) {
        return res.status(401).json({ error: 'Conta de usuário desativada ou inexistente. Acesso revogado.' });
      }

      const dbTokenVersion = userCheck.rows[0].token_version;
      const tokenPayloadVersion = decoded.tokenVersion || 1;

      if (tokenPayloadVersion < dbTokenVersion) {
        return res.status(401).json({ error: 'Sessão revogada ou credenciais alteradas. Faça login novamente.' });
      }

      req.user = decoded as AuthUser;
      next();
    } catch (dbErr) {
      console.error('[authenticateToken] Erro ao validar status do usuário no banco:', dbErr);
      return res.status(503).json({ error: 'Serviço temporariamente indisponível para validação de credenciais.' });
    }
  });
};

export const authMiddleware = authenticateToken;

export const requireAdmin = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const hasAdminAccess = req.user?.permissaoRh === true || req.user?.is_admin === true || req.user?.perfil === 'ADMIN_RH';
  if (!req.user || !hasAdminAccess) {
    return res.status(403).json({ error: 'Acesso restrito à equipe de gestão e administração de RH' });
  }
  next();
};

export const requireTi = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const hasTiAccess = req.user?.permissaoTi === true || req.user?.perfil === 'ADMIN_TI';
  if (!req.user || !hasTiAccess) {
    return res.status(403).json({ error: 'Acesso restrito à equipe de Administração de TI e Infraestrutura' });
  }
  next();
};

export const requireAdminOrTi = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const hasAccess = req.user?.permissaoRh === true ||
                    req.user?.permissaoTi === true ||
                    req.user?.is_admin === true ||
                    req.user?.perfil === 'ADMIN_RH' ||
                    req.user?.perfil === 'ADMIN_TI';
  if (!req.user || !hasAccess) {
    return res.status(403).json({ error: 'Acesso restrito à equipe de Administração de RH ou TI' });
  }
  next();
};

export const authenticateAdminMfa = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const mfaPolicy = await ConfigService.get('MFA_POLICY', 'DESATIVADO');
    const isMfaEnforcedForRh = mfaPolicy === 'OBRIGATORIO_RH' || mfaPolicy === 'OBRIGATORIO_TODOS';

    // Se MFA estiver DESATIVADO ou OPCIONAL (padrão de desenvolvimento), autoriza diretamente
    if (!isMfaEnforcedForRh) {
      req.isAdminMfaValidated = true;
      return next();
    }

    // Se MFA for exigido por política administrativa, valida o x-admin-token
    const adminToken = req.headers['x-admin-token'] as string;
    if (!adminToken) {
      return res.status(403).json({
        requiresAdminMfa: true,
        error: 'Autenticação em duas etapas (MFA) necessária para acessar o painel administrativo.'
      });
    }

    jwt.verify(adminToken, JWT_ADMIN_SECRET, (err, decoded: any) => {
      if (err || !decoded || decoded.userId !== req.user?.userId) {
        return res.status(403).json({
          requiresAdminMfa: true,
          error: 'Sessão MFA de administrador expirada ou inválida.'
        });
      }
      req.isAdminMfaValidated = true;
      next();
    });
  } catch (error) {
    console.error('[authenticateAdminMfa] Erro ao verificar política de MFA:', error);
    return res.status(500).json({ error: 'Erro de segurança ao validar autenticação em duas etapas.' });
  }
};

