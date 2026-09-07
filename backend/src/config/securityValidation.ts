/**
 * Validação de Segurança Fail-Fast para Ambientes de Produção (SEC-02)
 */
export function validateSecurityConfig(): void {
  const isProd = process.env.NODE_ENV === 'production';
  if (!isProd) return;

  const defaultPatterns = ['change_in_prod', 'super_secret', 'default', 'secret_key'];

  const jwtSecret = process.env.JWT_SECRET;
  if (!jwtSecret || jwtSecret.length < 32 || defaultPatterns.some(p => jwtSecret.toLowerCase().includes(p))) {
    console.error('❌ [ERRO CRÍTICO DE SEGURANÇA]: A variável JWT_SECRET deve estar configurada em ambiente de produção com pelo menos 32 caracteres e sem chaves padrão!');
    process.exit(1);
  }

  const jwtAdminSecret = process.env.JWT_ADMIN_SECRET;
  if (!jwtAdminSecret || jwtAdminSecret.length < 32 || defaultPatterns.some(p => jwtAdminSecret.toLowerCase().includes(p))) {
    console.error('❌ [ERRO CRÍTICO DE SEGURANÇA]: A variável JWT_ADMIN_SECRET deve estar configurada em ambiente de produção com chave forte e exclusiva!');
    process.exit(1);
  }

  const encryptionKey = process.env.ENCRYPTION_KEY;
  if (!encryptionKey || encryptionKey.length < 32 || defaultPatterns.some(p => encryptionKey.toLowerCase().includes(p))) {
    console.error('❌ [ERRO CRÍTICO DE SEGURANÇA]: A variável ENCRYPTION_KEY (AES-256) deve estar configurada em ambiente de produção com pelo menos 32 caracteres!');
    process.exit(1);
  }
}

