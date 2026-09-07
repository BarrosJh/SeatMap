const SENSITIVE_KEYS = new Set([
  'password',
  'senha',
  'token',
  'access_token',
  'refresh_token',
  'id_token',
  'authorization',
  'secret',
  'client_secret',
  'smtp_pass',
  'db_password',
  'jwt_secret',
  'encryption_key',
  'credit_card',
  'card_number',
  'cvv',
  'cpf',
  'pin'
]);

const REDACTED_VALUE = '[REDACTED]';

export function redactSensitiveData(data: any, depth = 0): any {
  if (depth > 8) return data; // Evitar recursão infinita
  if (data === null || data === undefined) return data;

  if (typeof data === 'string') {
    // Mascarar Bearer tokens se aparecerem em strings
    if (/bearer\s+[a-zA-Z0-9_\-\.]+/i.test(data)) {
      return data.replace(/bearer\s+[a-zA-Z0-9_\-\.]+/gi, 'Bearer [REDACTED]');
    }
    return data;
  }

  if (Array.isArray(data)) {
    return data.map((item) => redactSensitiveData(item, depth + 1));
  }

  if (typeof data === 'object') {
    if (data instanceof Error) {
      return {
        name: data.name,
        message: data.message,
        stack: data.stack
      };
    }

    if (data instanceof Date) {
      return data.toISOString();
    }

    const sanitized: Record<string, any> = {};
    for (const [key, value] of Object.entries(data)) {
      const lowerKey = key.toLowerCase();
      const isSensitiveKey =
        SENSITIVE_KEYS.has(lowerKey) ||
        lowerKey.includes('password') ||
        lowerKey.includes('secret') ||
        lowerKey.includes('token');

      if (isSensitiveKey) {
        if (value && typeof value === 'object' && !Array.isArray(value)) {
          // Se for um objeto contendo chaves, sanitiza o conteúdo interno
          sanitized[key] = redactSensitiveData(value, depth + 1);
        } else {
          sanitized[key] = REDACTED_VALUE;
        }
      } else {
        sanitized[key] = redactSensitiveData(value, depth + 1);
      }
    }
    return sanitized;
  }

  return data;
}
