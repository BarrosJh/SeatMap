import { ConfigService } from './configService';

export interface SsoProviderConfig {
  id: 'google' | 'azure' | 'okta';
  nome: string;
  ativo: boolean;
  clientId: string;
  tenantId?: string;
  discoveryUrl?: string;
}

export class SsoService {
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
    const googleClientId = await ConfigService.get('SSO_GOOGLE_CLIENT_ID', '');
    if (googleEnabled && googleClientId) {
      providers.push({
        id: 'google',
        nome: 'Google Workspace',
        icon: 'google'
      });
    }

    // 2. Microsoft Azure AD / Entra ID
    const azureEnabled = (await ConfigService.get('SSO_AZURE_ENABLED', 'false')) === 'true';
    const azureClientId = await ConfigService.get('SSO_AZURE_CLIENT_ID', '');
    if (azureEnabled && azureClientId) {
      providers.push({
        id: 'azure',
        nome: 'Microsoft 365 / Azure AD',
        icon: 'microsoft'
      });
    }

    // 3. Okta
    const oktaEnabled = (await ConfigService.get('SSO_OKTA_ENABLED', 'false')) === 'true';
    const oktaClientId = await ConfigService.get('SSO_OKTA_CLIENT_ID', '');
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
}

