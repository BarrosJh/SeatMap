import { z } from 'zod';

const TIME_REGEX = /^([01]\d|2[0-3]):[0-5]\d$/;

export const WHITELIST_PARAMETROS = [
  'LIMITE_SEMANAL_RESERVAS',
  'DIA_ABERTURA_GESTAO',
  'DIA_ABERTURA_COLABORADOR',
  'HORARIO_CORTE_NOSHOW',
  'HORARIO_INICIO_CHECKIN',
  'HORARIO_LIMITE_CHECKIN',
  'HORARIO_INICIO_RESERVA_TARDIA',
  'HORARIO_ABERTURA_GESTAO',
  'HORARIO_ABERTURA_COLABORADOR',
  'MFA_EXPIRACAO_MINUTOS',
  'MFA_MAX_TENTATIVAS',
  'AUTO_LOCK_MINUTOS',
  'TOLERANCIA_CHECKIN_RESERVA_TARDIA_MINUTOS',
  'AUTO_LOCK_ATIVO',
  'SSO_AZURE_ATIVO',
  'EXIGIR_MFA_ADMINS',
  'EXIGIR_MFA_GLOBAL',
  'SCIM_PROVISIONING_ATIVO',
  'PERMITIR_TROCA_MESMO_DIA',
  'CHECKIN_AUTOMATICO_GESTAO',
  'MFA_EMAIL_ENABLED',
  'MFA_TOTP_ENABLED',
  'SSO_ENABLED',
  'SSO_AUTO_PROVISION',
  'SSO_ENFORCE_FOR_DOMAINS',
  'SSO_AZURE_ENABLED',
  'SMTP_SECURE',
  'AVISO_GLOBAL_SISTEMA',
  'SMTP_PORT',
  'SMTP_HOST',
  'SMTP_USER',
  'SMTP_PASS',
  'SMTP_FROM'
] as const;

export function validateSingleParam(chave: string, valor: string): { valid: boolean; error?: string } {
  const val = String(valor).trim();

  switch (chave) {
    case 'LIMITE_SEMANAL_RESERVAS': {
      const num = parseInt(val, 10);
      if (isNaN(num) || num < 1 || num > 7) {
        return { valid: false, error: 'LIMITE_SEMANAL_RESERVAS deve ser um número inteiro entre 1 e 7.' };
      }
      return { valid: true };
    }
    case 'DIA_ABERTURA_GESTAO':
    case 'DIA_ABERTURA_COLABORADOR': {
      const num = parseInt(val, 10);
      if (isNaN(num) || num < 1 || num > 7) {
        return { valid: false, error: `${chave} deve ser um dia da semana válido (1=Segunda a 7=Domingo).` };
      }
      return { valid: true };
    }
    case 'HORARIO_CORTE_NOSHOW':
    case 'HORARIO_INICIO_CHECKIN':
    case 'HORARIO_LIMITE_CHECKIN':
    case 'HORARIO_INICIO_RESERVA_TARDIA':
    case 'HORARIO_ABERTURA_GESTAO':
    case 'HORARIO_ABERTURA_COLABORADOR': {
      if (!TIME_REGEX.test(val)) {
        return { valid: false, error: `${chave} deve estar no formato de horário HH:mm (00:00 a 23:59).` };
      }
      return { valid: true };
    }
    case 'MFA_EXPIRACAO_MINUTOS':
    case 'MFA_MAX_TENTATIVAS':
    case 'AUTO_LOCK_MINUTOS':
    case 'TOLERANCIA_CHECKIN_RESERVA_TARDIA_MINUTOS': {
      const num = parseInt(val, 10);
      if (isNaN(num) || num < 1 || num > 1440) {
        return { valid: false, error: `${chave} deve ser um valor inteiro positivo (1 a 1440).` };
      }
      return { valid: true };
    }
    case 'AUTO_LOCK_ATIVO':
    case 'SSO_AZURE_ATIVO':
    case 'EXIGIR_MFA_ADMINS':
    case 'EXIGIR_MFA_GLOBAL':
    case 'SCIM_PROVISIONING_ATIVO':
    case 'PERMITIR_TROCA_MESMO_DIA':
    case 'CHECKIN_AUTOMATICO_GESTAO':
    case 'MFA_EMAIL_ENABLED':
    case 'MFA_TOTP_ENABLED':
    case 'SSO_ENABLED':
    case 'SSO_AUTO_PROVISION':
    case 'SSO_ENFORCE_FOR_DOMAINS':
    case 'SSO_AZURE_ENABLED':
    case 'SMTP_SECURE': {
      if (val !== 'true' && val !== 'false') {
        return { valid: false, error: `${chave} deve ser um valor booleano ('true' ou 'false').` };
      }
      return { valid: true };
    }
    case 'AVISO_GLOBAL_SISTEMA': {
      if (val.length > 1000) {
        return { valid: false, error: 'AVISO_GLOBAL_SISTEMA não pode exceder 1000 caracteres.' };
      }
      return { valid: true };
    }
    case 'SMTP_PORT': {
      const port = parseInt(val, 10);
      if (isNaN(port) || !/^\d+$/.test(val) || port < 1 || port > 65535) {
        return { valid: false, error: 'SMTP_PORT deve ser um número de porta TCP válido entre 1 e 65535.' };
      }
      return { valid: true };
    }
    case 'SMTP_HOST':
    case 'SMTP_USER':
    case 'SMTP_PASS':
    case 'SMTP_FROM': {
      if (val.length > 500) {
        return { valid: false, error: `${chave} excede o limite máximo permitido de caracteres.` };
      }
      return { valid: true };
    }
    default:
      return { valid: false, error: `A chave de configuração '${chave}' não é permitida ou não existe na whitelist.` };
  }
}

export const updateParametrosSchema = z.object({
  configuracoes: z.union([
    z.array(
      z.object({
        chave: z.string(),
        valor: z.any(),
        descricao: z.string().optional()
      })
    ),
    z.record(z.string(), z.any())
  ], {
    message: 'Nenhuma configuração enviada para atualização.'
  })
}).superRefine((data, ctx) => {
  const configs = data.configuracoes;
  if (Array.isArray(configs)) {
    for (const item of configs) {
      const res = validateSingleParam(item.chave, String(item.valor ?? ''));
      if (!res.valid) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: res.error || 'Valor inválido.',
          path: ['configuracoes', item.chave]
        });
      }
    }
  } else if (typeof configs === 'object' && configs !== null) {
    for (const [chave, valor] of Object.entries(configs)) {
      const res = validateSingleParam(chave, String(valor ?? ''));
      if (!res.valid) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: res.error || 'Valor inválido.',
          path: ['configuracoes', chave]
        });
      }
    }
  }
});
