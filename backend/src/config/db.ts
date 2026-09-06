import { Pool, PoolConfig } from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const poolConfig: PoolConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME || 'seatmap_db',
  user: process.env.DB_USER || 'seatmap_user',
  password: process.env.DB_PASSWORD || 'seatmap_password',
  max: parseInt(process.env.DB_POOL_MAX || '30', 10),
  idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT || '30000', 10),
  connectionTimeoutMillis: parseInt(process.env.DB_CONNECTION_TIMEOUT || '10000', 10),
};

export const pool = new Pool(poolConfig);

pool.on('error', (err) => {
  console.error('[PostgreSQL Pool Error]: Inesperado erro no cliente inativo', err);
});

export const query = (text: string, params?: any[]) => pool.query(text, params);

export default pool;
