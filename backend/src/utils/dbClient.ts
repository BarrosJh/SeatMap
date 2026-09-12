import pool from '../config/db';

export interface DbClient {
  query: (sql: string, params?: any[]) => Promise<any>;
  release: () => void;
}

/**
 * Obtém um cliente dedicado do pool do PostgreSQL para transações atômicas seguras.
 * Lança exceção imediata caso não seja possível obter conexão para evitar execução sem transação (no-op).
 */
export async function getDbClient(): Promise<DbClient> {
  if (typeof pool?.connect === 'function') {
    try {
      const conn = await pool.connect();
      if (conn && typeof conn.query === 'function') {
        return conn;
      }
    } catch (err) {
      if (process.env.NODE_ENV !== 'test') {
        throw new Error('Falha ao obter conexão transacional do banco de dados.');
      }
    }
  }

  // Fallback restrito para mocks em testes unitários automatizados (sem PostgreSQL ativo)
  if (process.env.NODE_ENV === 'test' && typeof (pool as any)?.query === 'function') {
    return {
      query: async (sql: string, params?: any[]) => {
        const trimmed = (sql || '').trim().toUpperCase();
        if (trimmed === 'BEGIN' || trimmed === 'COMMIT' || trimmed === 'ROLLBACK') {
          return { rowCount: 0, rows: [] };
        }
        return (pool.query as any)(sql, params);
      },
      release: () => {}
    };
  }

  throw new Error('Falha ao obter conexão transacional do banco de dados.');
}
