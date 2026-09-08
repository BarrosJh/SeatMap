import rateLimit from 'express-rate-limit';
import { AuditService } from '../services/auditService';
import { logger } from '../utils/logger';

type AbuseKind = 'AUTH' | 'API' | 'EXPORT' | 'BATCH';

const getIp = (req: any): string => AuditService.getClientIp(req);

const getUserKey = (req: any): string => {
  const userId = req.user?.userId;
  return userId ? `usuario:${userId}` : `ip:${getIp(req)}`;
};

const getLoginKey = (req: any): string => {
  const login = req.body?.login || req.body?.email || req.body?.matricula;
  return typeof login === 'string'
    ? `login:${login.trim().toLowerCase().substring(0, 255)}`
    : `ip:${getIp(req)}`;
};

const abuseEvent = (kind: AbuseKind): 'LOGIN_CONTA_BLOQUEADA' | 'ABUSO_API_BLOQUEADO' | 'ABUSO_EXPORTACAO_BLOQUEADO' | 'ABUSO_LOTE_BLOQUEADO' => {
  if (kind === 'AUTH') return 'LOGIN_CONTA_BLOQUEADA';
  if (kind === 'EXPORT') return 'ABUSO_EXPORTACAO_BLOQUEADO';
  if (kind === 'BATCH') return 'ABUSO_LOTE_BLOQUEADO';
  return 'ABUSO_API_BLOQUEADO';
};

const createAbuseLimiter = ({
  windowMs,
  max,
  keyGenerator,
  kind,
  message
}: {
  windowMs: number;
  max: number;
  keyGenerator: (req: any) => string;
  kind: AbuseKind;
  message: string;
}) => rateLimit({
  windowMs,
  max,
  keyGenerator,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    const ip = getIp(req);
    const userAgent = AuditService.getUserAgent(req);
    const userId = (req as any).user?.userId;
    const login = req.body?.login || req.body?.email || req.body?.matricula;

    logger.warn('[RateLimit] Comportamento abusivo bloqueado', {
      kind,
      ip,
      userId,
      login: login ? String(login).substring(0, 255) : undefined,
      path: req.path,
      method: req.method
    });

    AuditService.log({
      usuarioId: userId || null,
      loginInformado: login ? String(login) : undefined,
      tipoEvento: abuseEvent(kind),
      sucesso: false,
      ip,
      userAgent,
      detalhes: {
        categoria: kind,
        rota: req.path,
        metodo: req.method,
        chave: keyGenerator(req)
      }
    });

    return res.status(429).json({ error: message });
  }
});

/**
 * Limite de burst por IP para acomodar abertura corporativa concentrada.
 * A proteção por conta/login abaixo continua limitando tentativas repetidas.
 */
const authIpRateLimitMax = Number.parseInt(process.env.AUTH_IP_RATE_LIMIT_MAX || '50', 10);

export const authRateLimiter = createAbuseLimiter({
  windowMs: 60 * 1000,
  max: Number.isFinite(authIpRateLimitMax) && authIpRateLimitMax > 0 ? authIpRateLimitMax : 50,
  keyGenerator: getIp,
  kind: 'AUTH',
  message: 'Muitas tentativas de autenticação a partir deste endereço IP. Por segurança, tente novamente em alguns segundos.'
});

export const authUserLimiter = createAbuseLimiter({
  windowMs: 15 * 60 * 1000,
  max: 5,
  keyGenerator: getLoginKey,
  kind: 'AUTH',
  message: 'Muitas tentativas para esta conta. Por segurança, aguarde 15 minutos antes de tentar novamente.'
});

export const authLimiter = authRateLimiter;

export const adminLimiter = createAbuseLimiter({
  windowMs: 60 * 1000,
  max: 60,
  keyGenerator: getIp,
  kind: 'API',
  message: 'Muitas requisições ao painel administrativo. Por favor, aguarde alguns instantes.'
});

export const userActionLimiter = createAbuseLimiter({
  windowMs: 60 * 1000,
  max: 30,
  keyGenerator: getUserKey,
  kind: 'API',
  message: 'Limite de ações atingido. Aguarde alguns instantes antes de tentar novamente.'
});

export const exportLimiter = createAbuseLimiter({
  windowMs: 10 * 60 * 1000,
  max: 5,
  keyGenerator: getUserKey,
  kind: 'EXPORT',
  message: 'Limite de exportações atingido. Aguarde alguns minutos antes de gerar outro arquivo.'
});

export const emailTestLimiter = createAbuseLimiter({
  windowMs: 10 * 60 * 1000,
  max: 5,
  keyGenerator: getUserKey,
  kind: 'API',
  message: 'Limite de testes de e-mail atingido. Aguarde alguns minutos antes de tentar novamente.'
});

export const batchLimiter = createAbuseLimiter({
  windowMs: 10 * 60 * 1000,
  max: 5,
  keyGenerator: getUserKey,
  kind: 'BATCH',
  message: 'Limite de operações em lote atingido. Aguarde alguns minutos antes de tentar novamente.'
});

export const heavyQueryLimiter = createAbuseLimiter({
  windowMs: 60 * 1000,
  max: 20,
  keyGenerator: getUserKey,
  kind: 'API',
  message: 'Limite de consultas pesadas atingido. Aguarde alguns instantes antes de continuar.'
});

const loadTestMode = process.env.LOAD_TEST_MODE === 'true';
const globalRateLimitMax = loadTestMode
  ? Number.parseInt(process.env.LOAD_TEST_RATE_LIMIT_MAX || '10000', 10)
  : Number.parseInt(process.env.GLOBAL_RATE_LIMIT_MAX || '900', 10);

export const globalLimiter = createAbuseLimiter({
  windowMs: 60 * 1000,
  max: Number.isFinite(globalRateLimitMax) && globalRateLimitMax > 0 ? globalRateLimitMax : 900,
  keyGenerator: getIp,
  kind: 'API',
  message: 'Limite de tráfego excedido temporariamente. Tente novamente em alguns segundos.'
});


