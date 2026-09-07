import pool from '../config/db';
import { CryptoService } from './cryptoService';

export class ConfigService {
  private static cache: Map<string, string> = new Map();
  private static lastFetch: number = 0;
  private static readonly TTL_MS = 60 * 1000; // 1 minuto de cache
  private static readonly SENSITIVE_KEYS: ReadonlySet<string> = new Set([
    'SMTP_PASS',
    'SSO_GOOGLE_CLIENT_SECRET',
    'SSO_AZURE_CLIENT_SECRET',
    'SSO_OKTA_CLIENT_SECRET'
  ]);

  /**
   * Obtém o valor decifrado de uma configuração
   */
  public static async get(key: string, defaultValue: string = ''): Promise<string> {
    const now = Date.now();
    if (this.cache.has(key) && (now - this.lastFetch < this.TTL_MS)) {
      return this.cache.get(key) || defaultValue;
    }

    try {
      const res = await pool.query('SELECT chave, valor FROM configuracoes_sistema');
      this.cache.clear();
      
      for (const row of res.rows) {
        const chave = row.chave;
        let valor = row.valor || '';

        if (this.SENSITIVE_KEYS.has(chave) && valor.length > 0) {
          if (CryptoService.isEncrypted(valor)) {
            // Descriptografa para a memória
            valor = CryptoService.decrypt(valor);
          } else {
            // Migração transparente de senhas legadas em texto plano para AES-256-GCM no banco
            const encryptedValue = CryptoService.encrypt(valor);
            pool.query('UPDATE configuracoes_sistema SET valor = $1 WHERE chave = $2', [encryptedValue, chave])
              .catch(err => console.error(`[ConfigService] Erro ao auto-migrar chave sensível ${chave}:`, err));
          }
        }

        this.cache.set(chave, valor);
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

  /**
   * Salva uma configuração no banco (se for sensível, criptografa com AES-256-GCM antes de persistir)
   */
  public static async set(key: string, value: string, descricao?: string): Promise<void> {
    let dbValue = value;

    if (this.SENSITIVE_KEYS.has(key) && value && value.length > 0) {
      dbValue = CryptoService.encrypt(value);
    }

    if (descricao) {
      await pool.query(`
        INSERT INTO configuracoes_sistema (chave, valor, descricao)
        VALUES ($1, $2, $3)
        ON CONFLICT (chave) DO UPDATE SET valor = EXCLUDED.valor, descricao = EXCLUDED.descricao
      `, [key, dbValue, descricao]);
    } else {
      await pool.query(`
        INSERT INTO configuracoes_sistema (chave, valor)
        VALUES ($1, $2)
        ON CONFLICT (chave) DO UPDATE SET valor = EXCLUDED.valor
      `, [key, dbValue]);
    }

    // No cache em memória, mantém sempre o valor descriptografado
    this.cache.set(key, value);
  }

  /**
   * Retorna todas as configurações com mascaramento de chaves sensíveis
   */
  public static async getAll(): Promise<Array<{ chave: string; valor: string; descricao: string }>> {
    const res = await pool.query('SELECT chave, valor, descricao FROM configuracoes_sistema ORDER BY chave');
    return res.rows.map(row => {
      if (this.SENSITIVE_KEYS.has(row.chave)) {
        return {
          chave: row.chave,
          valor: row.valor && row.valor.length > 0 ? '••••••••••••' : '',
          descricao: row.descricao
        };
      }
      return row;
    });
  }
}


