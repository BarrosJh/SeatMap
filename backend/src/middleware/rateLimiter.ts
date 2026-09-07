import rateLimit from 'express-rate-limit';
import { AuditService } from '../services/auditService';

/**
 * Limitador de taxa rígido para proteção contra ataques de força bruta em autenticação
 * Permite no máximo 5 tentativas falhas/requisições a cada 15 minutos por IP
 */
export const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 10, // Até 10 requisições por janela de 15 minutos por IP
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: 'Muitas tentativas de autenticação a partir deste endereço IP. Por segurança, tente novamente em 15 minutos.'
  },
  handler: (req, res, _next, options) => {
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);
    const login = req.body?.login || req.body?.email || req.body?.matricula || '';

    AuditService.log({
      loginInformado: login,
      tipoEvento: 'LOGIN_CONTA_BLOQUEADA',
      sucesso: false,
      ip,
      userAgent,
      detalhes: { motivo: 'Excedeu limite de taxa de requisições de autenticação (Rate Limit)' }
    });
    res.status(429).json(options.message);
  }
});

export const authLimiter = authRateLimiter;

export const adminLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minuto
  max: 60, // Até 60 requisições por minuto para endpoints administrativos
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: 'Muitas requisições ao painel administrativo. Por favor, aguarde alguns instantes.'
  }
});

export const globalLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minuto
  max: 300, // Até 300 requisições por minuto para navegação geral do app
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: 'Limite de tráfego excedido temporariamente. Tente novamente em alguns segundos.'
  }
});


