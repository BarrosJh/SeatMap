import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

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
}

export interface AuthenticatedRequest extends Request {
  user?: AuthUser;
  isAdminMfaValidated?: boolean;
}

const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_jwt_key_seatmap_2026_change_in_prod';
const JWT_ADMIN_SECRET = process.env.JWT_ADMIN_SECRET || 'super_secret_admin_mfa_jwt_key_seatmap_2026';

export const authenticateToken = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Token de autenticação não fornecido' });
  }

  jwt.verify(token, JWT_SECRET, (err, decoded) => {
    if (err) {
      return res.status(403).json({ error: 'Token inválido ou expirado' });
    }
    req.user = decoded as AuthUser;
    next();
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

export const authenticateAdminMfa = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  // MFA temporariamente desativado a pedido do usuário
  req.isAdminMfaValidated = true;
  next();
};

