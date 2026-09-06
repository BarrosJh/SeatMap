import rateLimit from 'express-rate-limit';

/**
 * Rate Limiter Global para toda a API REST
 * Limita cada IP a 300 requisições a cada 15 minutos
 */
export const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: 'Muitas requisições originadas deste IP. Por favor, tente novamente em alguns minutos.'
  }
});

/**
 * Rate Limiter Estrito para Autenticação e Recuperação de Senha
 * Limita cada IP a 20 requisições a cada 15 minutos para evitar força bruta
 */
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: 'Muitas tentativas de autenticação ou recuperação. Por segurança, aguarde 15 minutos.'
  }
});

/**
 * Rate Limiter para Operações de Administração e TI
 * Limita cada IP a 100 requisições a cada 15 minutos
 */
export const adminLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: 'Limite de requisições administrativas atingido. Tente novamente mais tarde.'
  }
});

