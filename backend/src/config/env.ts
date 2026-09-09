import dotenv from 'dotenv';

dotenv.config();

export interface EnvironmentConfig {
  PORT: number;
  NODE_ENV: string;
  DB_HOST: string;
  DB_PORT: number;
  DB_NAME: string;
  DB_USER: string;
  DB_PASS: string;
  JWT_SECRET: string;
  JWT_EXPIRATION: string;
  JWT_ADMIN_SECRET: string;
  JWT_ADMIN_EXPIRATION: string;
  JWT_MFA_TEMP_SECRET: string;
  ENCRYPTION_KEY: string;
  SCIM_BEARER_TOKEN: string;
  ALLOWED_ORIGINS: string[];
  INTERNAL_HEALTH_TOKEN: string;
  TRUST_PROXY_HOPS: number;
}

const PRODUCTION_LIKE_ENVIRONMENTS = new Set(['production', 'staging']);

export function isPlaceholderSecret(value: string): boolean {
  const normalized = value.trim().toLowerCase();

  if (!normalized) return true;

  const placeholderPatterns = [
    'dev_local_secret_key',
    'test_mock_secure_key',
    'super_secret',
    'change_in_prod',
    'your_jwt_secret',
    'your_admin_secret',
    'example',
    'changeme',
    'password',
    'secret'
  ];

  return placeholderPatterns.some((pattern) => normalized.includes(pattern));
}

export function validateEnvironmentValues(values: Record<string, any>, mode: string = 'development') {
  const environmentName = String(mode || 'development').toLowerCase();

  for (const [key, rawValue] of Object.entries(values)) {
    if (rawValue === undefined || rawValue === null || rawValue === '') continue;

    const value = typeof rawValue === 'string' ? rawValue.trim() : String(rawValue).trim();

    if (PRODUCTION_LIKE_ENVIRONMENTS.has(environmentName) && isPlaceholderSecret(value)) {
      throw new Error(`Ambiente '${environmentName}' não aceita valor placeholder para '${key}'. Defina um segredo real antes do deploy.`);
    }
  }
}

function getRequiredEnv(key: string, devFallback?: string): string {
  const val = process.env[key] || process.env[key.toUpperCase()];

  if (!val || val.trim() === '') {
    if (process.env.NODE_ENV === 'test') {
      const fallback = `test_mock_secure_key_for_unit_tests_${key.toLowerCase()}_32chars`;
      return fallback;
    }
    if (process.env.NODE_ENV !== 'production' && process.env.NODE_ENV !== 'staging') {
      const fallback = devFallback || `dev_local_secret_key_for_${key.toLowerCase()}_32chars_len`;
      console.warn(`⚠️ [CONFIGURAÇÃO DEV]: A variável '${key}' não foi definida no .env. Usando chave padrão de desenvolvimento.`);
      return fallback;
    }
    console.error(`❌ [CONFIGURAÇÃO CRÍTICA]: A variável de ambiente obrigatória '${key}' não foi definida.`);
    process.exit(1);
  }

  return val.trim();
}

function getOptionalEnv(key: string, defaultValue: string): string {
  const val = process.env[key] || process.env[key.toUpperCase()];
  return val && val.trim() !== '' ? val.trim() : defaultValue;
}

export function buildEnvironmentConfig(): EnvironmentConfig {
  const nodeEnv = getOptionalEnv('NODE_ENV', 'development');
  const dbPass = getOptionalEnv('DB_PASSWORD', getOptionalEnv('DB_PASS', 'seatmap_password'));
  const jwtSecret = getRequiredEnv('JWT_SECRET');
  const jwtAdminSecret = getOptionalEnv('JWT_ADMIN_SECRET', `${jwtSecret}_admin_secret_derived_key_32c`);
  const jwtMfaTempSecret = getOptionalEnv('JWT_MFA_TEMP_SECRET', `${jwtSecret}_mfa_temp_derived_key_32c`);
  const encryptionKey = getOptionalEnv('ENCRYPTION_KEY', `${jwtSecret}_encryption_key_derived_32c`);

  const config: EnvironmentConfig = {
    PORT: parseInt(getOptionalEnv('PORT', '3000'), 10),
    NODE_ENV: nodeEnv,
    DB_HOST: getOptionalEnv('DB_HOST', 'localhost'),
    DB_PORT: parseInt(getOptionalEnv('DB_PORT', '5432'), 10),
    DB_NAME: getOptionalEnv('DB_NAME', 'seatmap_db'),
    DB_USER: getOptionalEnv('DB_USER', 'seatmap_user'),
    DB_PASS: dbPass,
    JWT_SECRET: jwtSecret,
    JWT_EXPIRATION: getOptionalEnv('JWT_EXPIRATION', '1d'),
    JWT_ADMIN_SECRET: jwtAdminSecret,
    JWT_ADMIN_EXPIRATION: getOptionalEnv('JWT_ADMIN_EXPIRATION', '2h'),
    JWT_MFA_TEMP_SECRET: jwtMfaTempSecret,
    ENCRYPTION_KEY: encryptionKey,
    SCIM_BEARER_TOKEN: getOptionalEnv('SCIM_BEARER_TOKEN', ''),
    ALLOWED_ORIGINS: process.env.ALLOWED_ORIGINS
      ? process.env.ALLOWED_ORIGINS.split(',').map((o) => o.trim())
      : ['http://localhost:3000', 'http://localhost:8080', 'http://127.0.0.1:3000', 'http://127.0.0.1:8080'],
    INTERNAL_HEALTH_TOKEN: getOptionalEnv('INTERNAL_HEALTH_TOKEN', `${jwtSecret}_health_token_derived_32c`),
    TRUST_PROXY_HOPS: parseInt(getOptionalEnv('TRUST_PROXY_HOPS', '0'), 10),
  };

  validateEnvironmentValues(config, nodeEnv);
  return config;
}

export const env: EnvironmentConfig = buildEnvironmentConfig();

export default env;

