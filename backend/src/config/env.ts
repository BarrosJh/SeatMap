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
}

function getRequiredEnv(key: string, devFallback?: string): string {
  const val = process.env[key];
  if (!val || val.trim() === '') {
    if (process.env.NODE_ENV === 'test') {
      // Valor seguro para ambiente de testes unitários isolados
      return `test_mock_secure_key_for_unit_tests_${key.toLowerCase()}_32chars`;
    }
    if (process.env.NODE_ENV !== 'production') {
      // Valor padrão de desenvolvimento local
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
  const val = process.env[key];
  return val && val.trim() !== '' ? val.trim() : defaultValue;
}

export const env: EnvironmentConfig = {
  PORT: parseInt(getOptionalEnv('PORT', '3000'), 10),
  NODE_ENV: getOptionalEnv('NODE_ENV', 'development'),
  DB_HOST: getOptionalEnv('DB_HOST', 'localhost'),
  DB_PORT: parseInt(getOptionalEnv('DB_PORT', '5432'), 10),
  DB_NAME: getOptionalEnv('DB_NAME', 'seatmap_db'),
  DB_USER: getOptionalEnv('DB_USER', 'seatmap_user'),
  DB_PASS: getOptionalEnv('DB_PASSWORD', 'seatmap_password'),
  JWT_SECRET: getRequiredEnv('JWT_SECRET'),
  JWT_EXPIRATION: getOptionalEnv('JWT_EXPIRATION', '1d'),
  JWT_ADMIN_SECRET: getRequiredEnv('JWT_ADMIN_SECRET'),
  JWT_ADMIN_EXPIRATION: getOptionalEnv('JWT_ADMIN_EXPIRATION', '2h'),
  JWT_MFA_TEMP_SECRET: getRequiredEnv('JWT_MFA_TEMP_SECRET'),
  ENCRYPTION_KEY: getRequiredEnv('ENCRYPTION_KEY'),
  SCIM_BEARER_TOKEN: getOptionalEnv('SCIM_BEARER_TOKEN', ''),
  ALLOWED_ORIGINS: process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',').map((o) => o.trim())
    : ['http://localhost:3000', 'http://localhost:8080', 'http://127.0.0.1:3000', 'http://127.0.0.1:8080'],
};

export default env;

