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
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('[Migration] Erro ao executar migrações:', error);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

if (require.main === module) {
  runMigrations();
}

export default runMigrations;

