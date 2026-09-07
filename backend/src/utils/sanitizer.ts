/**
 * Sanitizer utility for enterprise input sanitation and log security.
 * Prevents Stored XSS, Log Injection/Forgery (CRLF), and Sensitive Data Leaks in logs.
 */

const SENSITIVE_KEYS = new Set([
  'senha',
  'senha_hash',
  'password',
  'novasenha',
  'currentpassword',
  'newpassword',
  'totp_secret',
  'totpsecret',
  'totp_backup_codes',
  'totpbackupcodes',
  'token',
  'accesstoken',
  'refreshtoken',
  'secret',
  'scimtoken',
  'apikey',
  'authorization'
]);

/**
 * Escapes characters that can lead to XSS attacks in plain text contexts.
 */
export function sanitizeText(input: string): string {
  if (typeof input !== 'string') return input;
  return input
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;')
    .replace(/\//g, '&#x2F;');
}

/**
 * Sanitizes strings specifically for logs to prevent CRLF Log Injection / Log Forgery.
 */
export function sanitizeForLog(input: string): string {
  if (typeof input !== 'string') return String(input);
  return input
    .replace(/[\r\n\t]/g, ' ')
    .replace(/[\x00-\x1F\x7F]/g, '');
}

/**
 * Deeply masks sensitive fields in objects for safe logging.
 */
export function maskSensitiveData(data: any): any {
  if (data === null || data === undefined) return data;
  if (typeof data !== 'object') return data;

  if (Array.isArray(data)) {
    return data.map(item => maskSensitiveData(item));
  }

  const masked: Record<string, any> = {};
  for (const [key, value] of Object.entries(data)) {
    if (SENSITIVE_KEYS.has(key.toLowerCase())) {
      masked[key] = '***REDACTED***';
    } else if (typeof value === 'object' && value !== null) {
      masked[key] = maskSensitiveData(value);
    } else {
      masked[key] = value;
    }
  }

  return masked;
}

