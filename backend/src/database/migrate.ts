import fs from 'fs';
import path from 'path';
import pool from '../config/db';

async function runMigrations() {
  const client = await pool.connect();
  try {
    console.log('[Migration] Iniciando execução das migrações SQL...');
    let schemaPath = path.join(__dirname, 'schema.sql');
    if (!fs.existsSync(schemaPath)) {
      schemaPath = path.join(__dirname, '../../src/database/schema.sql');
    }
    if (!fs.existsSync(schemaPath)) {
      schemaPath = path.join(process.cwd(), 'src/database/schema.sql');
    }
    const schemaSql = fs.readFileSync(schemaPath, 'utf8');

    await client.query('BEGIN');
    await client.query(schemaSql);
    await client.query('COMMIT');

    console.log('[Migration] Migrações executadas com sucesso!');

    const userCount = await client.query('SELECT COUNT(*)::int AS total FROM usuarios');
    if (userCount.rows[0]?.total === 0) {
      console.log('[Migration] Banco de dados vazio. Executando seed automático de dados iniciais...');
      client.release();
      const seedModule = await import('./seed');
      if (typeof seedModule.default === 'function') {
        await seedModule.default();
      }
      return;
    }
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('[Migration] Erro ao executar migrações:', error);
    process.exit(1);
  } finally {
    try { client.release(); } catch (_) {}
    await pool.end();
  }
}

if (require.main === module) {
  runMigrations();
}

export default runMigrations;

