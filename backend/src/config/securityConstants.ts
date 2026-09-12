/**
 * Constantes de segurança e criptografia corporativa
 * Padrões Enterprise de Cibersegurança
 */

// Fator de custo de hashing (work factor / salt rounds) mínimo
export const BCRYPT_SALT_ROUNDS = 12;

// Timeout absoluto de sessão em segundos (60 minutos)
export const MAX_ABSOLUTE_SESSION_SECONDS = 3600;

// Expiração padrão de Refresh Token em dias
export const REFRESH_TOKEN_EXPIRATION_DAYS = 7;

