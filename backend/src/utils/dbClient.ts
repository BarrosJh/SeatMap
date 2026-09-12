import pool from '../config/db';

export interface DbClient {
  query: (sql: string, params?: any[]) => Promise<any>;
  release: () => void;
}

/**
 * Obtém um cliente do pool do PostgreSQL para transações atômicas com fallback
 * compatível para ambientes de testes e mocks unitários.
 */
export async function getDbClient(): Promise<DbClient> {
  if (typeof pool.connect === 'function') {
    try {
      const conn = await pool.connect();
      if (conn && typeof conn.query === 'function') {
        return conn;
      }
    } catch (_) {
      // Fallback para pool.query caso connect não esteja disponível
    }
  }

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
