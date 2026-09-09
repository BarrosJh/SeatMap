import { Pool, PoolConfig } from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const isProductionLike = ['production', 'staging'].includes((process.env.NODE_ENV || 'development').toLowerCase());

const databaseUrl = process.env.DATABASE_URL;
const dbHost = process.env.DB_HOST || 'localhost';
const dbPort = parseInt(process.env.DB_PORT || '5432', 10);
const dbName = process.env.DB_NAME || 'seatmap_db';
const dbUser = process.env.DB_USER || 'seatmap_user';
const dbPassword = process.env.DB_PASSWORD || process.env.DB_PASS;

let poolConfig: PoolConfig;

if (databaseUrl && databaseUrl.trim() !== '') {
  poolConfig = {
    connectionString: databaseUrl.trim(),
    ssl: isProductionLike ? { rejectUnauthorized: false } : undefined,
    max: parseInt(process.env.DB_POOL_MAX || '30', 10),
    idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT || '30000', 10),
    connectionTimeoutMillis: parseInt(process.env.DB_CONNECTION_TIMEOUT || '10000', 10),
  };
} else {
  if (isProductionLike && (!dbPassword || dbPassword.trim() === '')) {
    throw new Error('DATABASE_URL ou DB_PASSWORD/DB_PASS deve ser configurado em ambiente de produção ou staging. Nenhum valor inseguro pode ser usado como fallback.');
  }

  poolConfig = {
    host: dbHost,
    port: dbPort,
    database: dbName,
    user: dbUser,
    password: dbPassword || (isProductionLike ? '' : 'seatmap_password'),
    ssl: isProductionLike ? { rejectUnauthorized: false } : undefined,
    max: parseInt(process.env.DB_POOL_MAX || '30', 10),
    idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT || '30000', 10),
    connectionTimeoutMillis: parseInt(process.env.DB_CONNECTION_TIMEOUT || '10000', 10),
  };
}

export const pool = new Pool(poolConfig);

pool.on('error', (err) => {
  console.error('[PostgreSQL Pool Error]: Inesperado erro no cliente inativo', err);
});

export const query = (text: string, params?: any[]) => pool.query(text, params);

export default pool;
