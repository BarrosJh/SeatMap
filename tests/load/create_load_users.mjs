import bcrypt from '../backend/node_modules/bcrypt/bcrypt.js';
import pg from '../backend/node_modules/pg/lib/index.js';

const { Pool } = pg;
const count = Number(process.env.LOAD_USER_COUNT || 300);
const password = process.env.LOAD_TEST_PASSWORD || 'Carga@2026!';
const prefix = process.env.LOAD_USER_PREFIX || 'CARGA_';
const emailDomain = process.env.LOAD_USER_DOMAIN || 'loadtest.local';

if (!Number.isInteger(count) || count < 1 || count > 1000) {
  throw new Error('LOAD_USER_COUNT deve ser um inteiro entre 1 e 1000.');
}

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.DB_NAME || 'seatmap_db',
  user: process.env.DB_USER || 'seatmap_user',
  password: process.env.DB_PASSWORD || 'seatmap_password',
  max: 4
});

const client = await pool.connect();
try {
  await client.query('BEGIN');
  const department = await client.query('SELECT id FROM departamentos ORDER BY id LIMIT 1');
  const departmentId = department.rows[0]?.id || null;
  const passwordHash = await bcrypt.hash(password, 10);
  const insertedIds = [];

  for (let index = 1; index <= count; index += 1) {
    const sequence = String(index).padStart(3, '0');
    const email = `carga${sequence}@${emailDomain}`;
    const matricula = `${prefix}${sequence}`;
    const result = await client.query(`
      INSERT INTO usuarios (
        nome, email, matricula, senha_hash, departamento_id, perfil,
        permissao_rh, permissao_ti, ativo, exigir_mfa, token_version
      ) VALUES ($1, $2, $3, $4, $5, 'COLABORADOR', false, false, true, false, 1)
      ON CONFLICT (email) DO UPDATE
      SET ativo = true, perfil = 'COLABORADOR', departamento_id = EXCLUDED.departamento_id,
          exigir_mfa = false, token_version = usuarios.token_version
      RETURNING id
    `, [`Carga ${sequence}`, email, matricula, passwordHash, departmentId]);
    insertedIds.push(result.rows[0].id);
  }

  await client.query('COMMIT');
  console.log(JSON.stringify({
    prefix,
    emailDomain,
    requested: count,
    ids: { first: Math.min(...insertedIds), last: Math.max(...insertedIds) },
    passwordConfigured: true
  }, null, 2));
} catch (error) {
  await client.query('ROLLBACK');
  throw error;
} finally {
  client.release();
  await pool.end();
}