import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import pool from '../config/db';
import { ConfigService } from '../services/configService';
import { env } from '../config/env';
import { logger } from '../utils/logger';

export type Permission =
  | 'config:read'
  | 'config:write'
  | 'usuarios:read'
  | 'usuarios:write'
  | 'relatorios:read'
  | 'relatorios:write'
  | 'reservas:read'
  | 'reservas:write'
  | 'infra:read'
  | 'infra:write';

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
  authTime?: number;
}

export interface AuthenticatedRequest extends Request {
  user?: AuthUser;
  isAdminMfaValidated?: boolean;
}

const JWT_SECRET = env.JWT_SECRET;
const JWT_ADMIN_SECRET = env.JWT_ADMIN_SECRET;

export const ROLE_PERMISSIONS: Record<string, Permission[]> = {
  COLABORADOR: ['reservas:read'],
  GESTAO: ['reservas:read', 'reservas:write'],
  ADMIN_RH: [
    'config:read',
    'config:write',
    'usuarios:read',
    'usuarios:write',
    'relatorios:read',
    'relatorios:write',
    'reservas:read',
    'reservas:write',
    'infra:read',
    'infra:write'
  ],
  ADMIN_TI: [
    'infra:read',
    'infra:write',
    'usuarios:read',
    'usuarios:write',
    'reservas:read',
    'reservas:write'
  ]
};

export const getUserPermissions = (user?: Pick<AuthUser, 'perfil' | 'permissaoRh' | 'permissaoTi' | 'is_admin'>): Permission[] => {
  if (!user) return [];

  const permissions = new Set<Permission>(ROLE_PERMISSIONS[user.perfil] || []);

  if (user.permissaoRh === true) {
    permissions.add('config:read');
    permissions.add('config:write');
    permissions.add('usuarios:read');
    permissions.add('usuarios:write');
    permissions.add('relatorios:read');
    permissions.add('relatorios:write');
    permissions.add('reservas:read');
    permissions.add('reservas:write');
    permissions.add('infra:read');
    permissions.add('infra:write');
  }

  if (user.permissaoTi === true) {
    permissions.add('infra:read');
    permissions.add('infra:write');
    permissions.add('usuarios:read');
    permissions.add('usuarios:write');
    permissions.add('reservas:read');
    permissions.add('reservas:write');
  }

  if (user.is_admin === true) {
    permissions.add('config:read');
    permissions.add('config:write');
    permissions.add('usuarios:read');
    permissions.add('usuarios:write');
    permissions.add('infra:read');
    permissions.add('infra:write');
    permissions.add('relatorios:read');
    permissions.add('relatorios:write');
    permissions.add('reservas:read');
    permissions.add('reservas:write');
  }

  return Array.from(permissions);
};

export const userHasPermission = (
  user: Pick<AuthUser, 'perfil' | 'permissaoRh' | 'permissaoTi' | 'is_admin'> | undefined,
  permission: Permission
): boolean => {
  if (!user) return false;
  return getUserPermissions(user).includes(permission);
};

export const isRhGlobal = (
  user: Pick<AuthUser, 'perfil' | 'permissaoRh' | 'permissaoTi' | 'is_admin'> | undefined
): boolean => {
  if (!user) return false;
  return user.perfil === 'ADMIN_RH' || user.permissaoRh === true || user.is_admin === true;
};

export const requirePermission = (permission: Permission) => {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Token de autenticação não fornecido' });
    }

    if (!userHasPermission(req.user, permission)) {
      return res.status(403).json({
        error: `Permissão insuficiente para executar esta operação (${permission}).`
      });
    }

    return next();
  };
};

import { JwtCryptoUtils } from '../config/jwtCryptoUtils';

export const authenticateToken = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Token de autenticação não fornecido' });
  }

  try {
    const decoded: any = JwtCryptoUtils.verifyToken(token);
    if (!decoded || !decoded.userId) {
      return res.status(403).json({ error: 'Token inválido ou expirado' });
    }

    (async () => {
      try {
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

        // Timeout Absoluto Server-Side de 60 minutos (3600 segundos) a partir do login inicial
        const nowInSeconds = Math.floor(Date.now() / 1000);
        if (decoded.authTime && (nowInSeconds - decoded.authTime) > 3600) {
          return res.status(401).json({
            error: 'Sessão expirada pelo tempo limite absoluto de 60 minutos. Por favor, autentique-se novamente.',
            code: 'SESSION_ABSOLUTE_TIMEOUT'
          });
        }

        req.user = decoded as AuthUser;
        next();
      } catch (dbErr) {
        logger.error('[authenticateToken] Erro ao validar status do usuário no banco:', { correlationId: (req as any).correlationId, error: dbErr });
        return res.status(503).json({ error: 'Serviço temporariamente indisponível para validação de credenciais.' });
      }
    })();
  } catch (err) {
    return res.status(403).json({ error: 'Token inválido ou expirado' });
  }
};

export const authMiddleware = authenticateToken;

export const requireAdmin = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  if (!req.user || !userHasPermission(req.user, 'config:write')) {
    return res.status(403).json({ error: 'Acesso restrito à equipe de gestão e administração de RH' });
  }
  next();
};

export const requireTi = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  if (!req.user || !userHasPermission(req.user, 'infra:write')) {
    return res.status(403).json({ error: 'Acesso restrito à equipe de Administração de TI e Infraestrutura' });
  }
  next();
};

export const requireAdminOrTi = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  if (!req.user || (!userHasPermission(req.user, 'config:write') && !userHasPermission(req.user, 'infra:write'))) {
    return res.status(403).json({ error: 'Acesso restrito à equipe de Administração de RH ou TI' });
  }
  next();
};

export const authenticateAdminMfa = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const mfaPolicy = await ConfigService.get('MFA_POLICY', 'OBRIGATORIO_RH');
    const isMfaEnforcedForRh = mfaPolicy === 'OBRIGATORIO_RH' || mfaPolicy === 'OBRIGATORIO_TODOS';

    if (!isMfaEnforcedForRh) {
      req.isAdminMfaValidated = true;
      return next();
    }

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
    logger.error('[authenticateAdminMfa] Erro ao verificar política de MFA:', { correlationId: req.correlationId, error });
    return res.status(500).json({ error: 'Erro de segurança ao validar autenticação em duas etapas.' });
  }
};

