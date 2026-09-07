import https from 'https';
import crypto from 'crypto';
import jwt, { JwtHeader } from 'jsonwebtoken';
import { ConfigService } from './configService';

export interface SsoProviderConfig {
  id: 'google' | 'azure' | 'okta';
  nome: string;
  ativo: boolean;
  clientId: string;
  tenantId?: string;
  discoveryUrl?: string;
}

export interface SsoVerifiedUser {
  email: string;
  name?: string;
  ssoId?: string;
}

interface JwkKey {
  kid: string;
  kty: string;
  n: string;
  e: string;
  x5c?: string[];
}

export class SsoService {
  private static jwksCache: Map<string, { keys: JwkKey[]; expiresAt: number }> = new Map();
  private static readonly CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24h

  /**
   * Obtém as chaves públicas (JWKS) do provedor com cache em memória
   */
  private static async fetchJwks(jwksUrl: string): Promise<JwkKey[]> {
    const cached = this.jwksCache.get(jwksUrl);
    if (cached && cached.expiresAt > Date.now()) {
      return cached.keys;
    }

    return new Promise((resolve, reject) => {
      https.get(jwksUrl, (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          try {
            const parsed = JSON.parse(data);
            const keys: JwkKey[] = parsed.keys || [];
            this.jwksCache.set(jwksUrl, {
              keys,
              expiresAt: Date.now() + this.CACHE_TTL_MS
            });
            resolve(keys);
          } catch (e) {
            reject(new Error(`Falha ao decodificar JWKS de ${jwksUrl}: ${e}`));
          }
        });
      }).on('error', (err) => {
        reject(new Error(`Erro de rede ao buscar JWKS de ${jwksUrl}: ${err.message}`));
      });
    });
  }

  /**
   * Retorna os provedores de SSO ativos para exibição na tela de login
   */
  public static async getActiveProviders(): Promise<{
    ssoEnabled: boolean;
    allowedDomains: string[];
    providers: Array<{ id: string; nome: string; icon: string; loginUrl?: string }>;
  }> {
    const ssoEnabledStr = await ConfigService.get('SSO_ENABLED', 'false');
    const ssoEnabled = ssoEnabledStr === 'true';

    if (!ssoEnabled) {
      return { ssoEnabled: false, allowedDomains: [], providers: [] };
    }

    const allowedDomainsStr = await ConfigService.get('SSO_ALLOWED_DOMAINS', '');
    const allowedDomains = allowedDomainsStr
      .split(',')
      .map(d => d.trim().toLowerCase())
      .filter(d => d.length > 0);

    const providers: Array<{ id: string; nome: string; icon: string; loginUrl?: string }> = [];

    // 1. Google Workspace
    const googleEnabled = (await ConfigService.get('SSO_GOOGLE_ENABLED', 'false')) === 'true';
    const googleClientId = (await ConfigService.get('SSO_GOOGLE_CLIENT_ID', '')).trim();
    if (googleEnabled && googleClientId) {
      providers.push({
        id: 'google',
        nome: 'Google Workspace',
        icon: 'google'
      });
    }

    // 2. Microsoft Azure AD / Entra ID
    const azureEnabled = (await ConfigService.get('SSO_AZURE_ENABLED', 'false')) === 'true';
    const azureClientId = (await ConfigService.get('SSO_AZURE_CLIENT_ID', '')).trim();
    if (azureEnabled && azureClientId) {
      providers.push({
        id: 'azure',
        nome: 'Microsoft 365 / Azure AD',
        icon: 'microsoft'
      });
    }

    // 3. Okta
    const oktaEnabled = (await ConfigService.get('SSO_OKTA_ENABLED', 'false')) === 'true';
    const oktaClientId = (await ConfigService.get('SSO_OKTA_CLIENT_ID', '')).trim();
    if (oktaEnabled && oktaClientId) {
      providers.push({
        id: 'okta',
        nome: 'Okta Enterprise SSO',
        icon: 'okta'
      });
    }

    return {
      ssoEnabled: providers.length > 0,
      allowedDomains,
      providers
    };
  }

  /**
   * Valida se o e-mail pertence aos domínios corporativos autorizados
   */
  public static async isEmailDomainAllowed(email: string): Promise<boolean> {
    const allowedDomainsStr = await ConfigService.get('SSO_ALLOWED_DOMAINS', '');
    if (!allowedDomainsStr.trim() || allowedDomainsStr.trim() === '*') {
      return true;
    }

    const domain = email.split('@')[1]?.toLowerCase();
    if (!domain) return false;

    const allowed = allowedDomainsStr.split(',').map(d => d.trim().toLowerCase().replace(/^@/, ''));
    return allowed.includes(domain);
  }

  /**
   * Valida o idToken emitido pelo provedor de identidade via JWKS
   */
  public static async verifyIdToken(provider: string, idToken: string): Promise<SsoVerifiedUser> {
    if (!idToken || typeof idToken !== 'string') {
      throw new Error('idToken não fornecido ou inválido.');
    }

    const supportedProviders = ['google', 'azure', 'okta'];
    if (!supportedProviders.includes(provider)) {
      throw new Error(`Provedor de SSO '${provider}' não suportado.`);
    }

    // Decodificar o header sem verificar para obter o `kid`
    const decoded = jwt.decode(idToken, { complete: true });
    if (!decoded || !decoded.header || typeof decoded.header !== 'object') {
      throw new Error('Token JWT em formato inválido ou corrompido.');
    }

    const header = decoded.header as JwtHeader;
    const kid = header.kid;
    if (!kid) {
      throw new Error('O cabeçalho do token JWT não possui Key ID (kid).');
    }

    let jwksUrl = '';
    let expectedAudience = '';

    if (provider === 'google') {
      jwksUrl = 'https://www.googleapis.com/oauth2/v3/certs';
      expectedAudience = (await ConfigService.get('SSO_GOOGLE_CLIENT_ID', '')).trim();
    } else if (provider === 'azure') {
      const tenantId = (await ConfigService.get('SSO_AZURE_TENANT_ID', '')).trim() || 'common';
      jwksUrl = `https://login.microsoftonline.com/${tenantId}/discovery/v2.0/keys`;
      expectedAudience = (await ConfigService.get('SSO_AZURE_CLIENT_ID', '')).trim();
    } else if (provider === 'okta') {
      const oktaDomain = (await ConfigService.get('SSO_OKTA_DOMAIN', '')).trim();
      if (!oktaDomain) throw new Error('Domínio Okta não configurado.');
      jwksUrl = `https://${oktaDomain}/oauth2/v1/keys`;
      expectedAudience = (await ConfigService.get('SSO_OKTA_CLIENT_ID', '')).trim();
    } else {
      throw new Error(`Provedor de SSO '${provider}' não suportado.`);
    }

    const keys = await this.fetchJwks(jwksUrl);
    const jwk = keys.find(k => k.kid === kid);
    if (!jwk) {
      throw new Error(`Chave pública (kid: ${kid}) não encontrada no endpoint oficial do provedor.`);
    }

    // Converter a chave JWK para PEM usando a API nativa crypto do Node.js
    const publicKey = crypto.createPublicKey({
      key: {
        kty: jwk.kty,
        n: jwk.n,
        e: jwk.e
      },
      format: 'jwk'
    }).export({ type: 'spki', format: 'pem' });

    const verifyOptions: jwt.VerifyOptions = {
      algorithms: ['RS256']
    };
    if (expectedAudience) {
      verifyOptions.audience = expectedAudience;
    }

    const verifiedPayload = jwt.verify(idToken, publicKey, verifyOptions) as Record<string, any>;
    const email = (verifiedPayload.email || verifiedPayload.preferred_username || verifiedPayload.upn || '').toLowerCase();
    const name = verifiedPayload.name || verifiedPayload.given_name || undefined;
    const ssoId = verifiedPayload.sub || verifiedPayload.oid || undefined;

    if (!email || !email.includes('@')) {
      throw new Error('O token verificado do provedor não contém um e-mail válido.');
    }

    return {
      email,
      name,
      ssoId
    };
  }
}
