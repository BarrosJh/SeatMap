// Validação de segurança para inicialização em ambiente de produção
 
export function validateSecurityConfig(): void {
  const isProd = process.env.NODE_ENV === 'production';
  const isProductionLike = isProd || process.env.NODE_ENV === 'staging';
  if (!isProductionLike) return;

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

  const jwtMfaTempSecret = process.env.JWT_MFA_TEMP_SECRET;
  if (!jwtMfaTempSecret || jwtMfaTempSecret.length < 32 || defaultPatterns.some(p => jwtMfaTempSecret.toLowerCase().includes(p))) {
    console.error('❌ [ERRO CRÍTICO DE SEGURANÇA]: A variável JWT_MFA_TEMP_SECRET deve estar configurada em ambiente de produção com pelo menos 32 caracteres e sem chaves padrão!');
    process.exit(1);
  }

  const encryptionKey = process.env.ENCRYPTION_KEY;
  if (!encryptionKey || encryptionKey.length < 32 || defaultPatterns.some(p => encryptionKey.toLowerCase().includes(p))) {
    console.error('❌ [ERRO CRÍTICO DE SEGURANÇA]: A variável ENCRYPTION_KEY (AES-256) deve estar configurada em ambiente de produção com pelo menos 32 caracteres!');
    process.exit(1);
  }

  const scimToken = process.env.SCIM_BEARER_TOKEN;
  if (scimToken && (scimToken.length < 32 || defaultPatterns.some(p => scimToken.toLowerCase().includes(p)))) {
    console.error('❌ [ERRO CRÍTICO DE SEGURANÇA]: A variável SCIM_BEARER_TOKEN deve ter pelo menos 32 caracteres e sem chaves padrão!');
    process.exit(1);
  }

  const healthToken = process.env.INTERNAL_HEALTH_TOKEN;
  if (!healthToken || healthToken.length < 32 || defaultPatterns.some(p => healthToken.toLowerCase().includes(p))) {
    console.error('❌ [ERRO CRÍTICO DE SEGURANÇA]: A variável INTERNAL_HEALTH_TOKEN deve estar configurada em produção/staging com pelo menos 32 caracteres e sem valores padrão!');
    process.exit(1);
  }

  const trustProxyHops = Number.parseInt(process.env.TRUST_PROXY_HOPS || '0', 10);
  if (!Number.isInteger(trustProxyHops) || trustProxyHops < 0) {
    console.error('❌ [ERRO DE CONFIGURAÇÃO]: TRUST_PROXY_HOPS deve ser um número inteiro maior ou igual a zero.');
    process.exit(1);
  }
}

