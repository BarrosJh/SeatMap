import pool from '../config/db';

export class ConfigService {
  private static cache: Map<string, string> = new Map();
  private static lastFetch: number = 0;
  private static readonly TTL_MS = 60 * 1000; // 1 minuto de cache

  public static async get(key: string, defaultValue: string = ''): Promise<string> {
    const now = Date.now();
    if (this.cache.has(key) && (now - this.lastFetch < this.TTL_MS)) {
      return this.cache.get(key) || defaultValue;
    }

    try {
      const res = await pool.query('SELECT chave, valor FROM configuracoes_sistema');
      this.cache.clear();
      for (const row of res.rows) {
        this.cache.set(row.chave, row.valor);
      }
      this.lastFetch = now;
      return this.cache.get(key) || defaultValue;
    } catch (error) {
      console.error('[ConfigService] Erro ao carregar configurações do banco:', error);
      return defaultValue;
    }
  }

  public static async getNumber(key: string, defaultValue: number): Promise<number> {
    const val = await this.get(key, defaultValue.toString());
    const parsed = parseInt(val, 10);
    return isNaN(parsed) ? defaultValue : parsed;
  }

  public static async set(key: string, value: string, descricao?: string): Promise<void> {
    if (descricao) {
      await pool.query(`
        INSERT INTO configuracoes_sistema (chave, valor, descricao)
        VALUES ($1, $2, $3)
        ON CONFLICT (chave) DO UPDATE SET valor = EXCLUDED.valor, descricao = EXCLUDED.descricao
      `, [key, value, descricao]);
    } else {
      await pool.query(`
        INSERT INTO configuracoes_sistema (chave, valor)
        VALUES ($1, $2)
        ON CONFLICT (chave) DO UPDATE SET valor = EXCLUDED.valor
      `, [key, value]);
    }
    this.cache.set(key, value);
  }

  public static async getAll(): Promise<Array<{ chave: string; valor: string; descricao: string }>> {
    const res = await pool.query('SELECT chave, valor, descricao FROM configuracoes_sistema ORDER BY chave');
    return res.rows;
  }
}

