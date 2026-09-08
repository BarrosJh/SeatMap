import pg from '../backend/node_modules/pg/lib/index.js';

const { Pool } = pg;
const tasks = Number(process.env.POOL_TASKS || 60);
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.DB_NAME || 'seatmap_db',
  user: process.env.DB_USER || 'seatmap_user',
  password: process.env.DB_PASSWORD || 'seatmap_password',
  max: Number(process.env.DB_POOL_MAX || 30),
  connectionTimeoutMillis: 10000
});

const samples = [];
const interval = setInterval(() => {
  samples.push({ waiting: pool.waitingCount, total: pool.totalCount, idle: pool.idleCount });
}, 20);

const started = Date.now();
await Promise.all(Array.from({ length: tasks }, () => pool.query('SELECT pg_sleep(0.25)')));
clearInterval(interval);
await pool.end();

console.log(JSON.stringify({
  tasks,
  configuredMax: Number(process.env.DB_POOL_MAX || 30),
  durationMs: Date.now() - started,
  maxWaitingCount: Math.max(0, ...samples.map((sample) => sample.waiting)),
  maxTotalCount: Math.max(0, ...samples.map((sample) => sample.total)),
  samples: samples.length
}, null, 2));