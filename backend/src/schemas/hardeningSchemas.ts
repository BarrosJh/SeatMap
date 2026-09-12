import { z } from 'zod';

const dateSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Data deve estar no formato YYYY-MM-DD');
const boundedText = (max: number) => z.string().trim().max(max);

export const adminReservaQuerySchema = z.object({
  dataInicio: dateSchema.optional(),
  dataFim: dateSchema.optional(),
  escritorioId: z.string().regex(/^\d+$/, 'Escritório inválido.').or(z.literal('todos')).optional(),
  departamentoId: z.string().regex(/^\d+$/, 'Departamento inválido.').or(z.literal('todos')).optional(),
  status: z.enum(['ATIVA', 'CANCELADA', 'EXPIRADA_NOSHOW', 'CONCLUIDA', 'todos']).optional(),
  busca: boundedText(255).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(100),
  offset: z.coerce.number().int().min(0).max(100000).default(0)
}).strict();

export const justificativaSchema = z.object({
  justificativa: boundedText(1000).optional()
}).strict();

export const limpezaNoShowSchema = z.object({
  data: dateSchema.optional()
}).strict();

export const singleDateQuerySchema = z.object({
  data: dateSchema.optional()
}).strict();

export const relatorioQuerySchema = z.object({
  dataInicio: dateSchema.optional(),
  dataFim: dateSchema.optional(),
  escritorioId: z.string().regex(/^\d+$/, 'Escritório inválido.').optional(),
  departamentoId: z.string().regex(/^\d+$/, 'Departamento inválido.').optional(),
  status: boundedText(30).optional(),
  checkinStatus: boundedText(30).optional(),
  busca: boundedText(255).optional(),
  page: z.coerce.number().int().min(1).default(1).optional(),
  limit: z.coerce.number().int().min(1).max(10000).default(100).optional(),
  offset: z.coerce.number().int().min(0).max(100000).default(0).optional(),
  formato: z.enum(['excel', 'pdf', 'csv']).optional()
}).strict();

export const facilitiesQuerySchema = z.object({
  escritorioId: z.string().regex(/^\d+$/, 'Escritório inválido.').optional(),
  busca: boundedText(255).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).max(100000).default(0)
}).strict();

export const tiConfigSchema = z.object({
  emailProvider: z.enum(['RESEND', 'SMTP']).optional(),
  resendApiKey: boundedText(500).optional(),
  smtpHost: boundedText(255).optional(),
  smtpPort: z.union([z.string().regex(/^\d{1,5}$/), z.number().int().min(1).max(65535)]).optional(),
  smtpSecure: z.union([z.boolean(), z.string().max(5)]).optional(),
  smtpUser: boundedText(255).optional(),
  smtpPass: boundedText(500).optional(),
  emailFrom: boundedText(255).optional(),
  mfaPolicy: z.enum(['DESATIVADO', 'OPCIONAL', 'OBRIGATORIO_RH', 'OBRIGATORIO_TODOS']).optional(),
  mfaEmailEnabled: z.boolean().optional(),
  mfaTotpEnabled: z.boolean().optional(),
  mfaExpiracaoMinutos: z.coerce.number().int().min(1).max(1440).optional(),
  mfaMaxTentativas: z.coerce.number().int().min(1).max(10).optional(),
  autoLockAtivo: z.boolean().optional(),
  autoLockMinutos: z.coerce.number().int().min(1).max(1440).optional(),
  ssoEnabled: z.boolean().optional(),
  ssoAllowedDomains: boundedText(1000).optional(),
  ssoAutoProvision: z.boolean().optional(),
  ssoDefaultRole: z.enum(['COLABORADOR', 'GESTAO', 'ADMIN_RH', 'ADMIN_TI']).optional(),
  ssoEnforceForDomains: z.boolean().optional(),
  ssoAzureEnabled: z.boolean().optional(),
  ssoAzureTenantType: z.enum(['single_tenant', 'multi_tenant', 'common']).optional(),
  ssoAzureTenantId: boundedText(255).optional(),
  ssoAzureClientId: boundedText(500).optional(),
  ssoAzureClientSecret: boundedText(500).optional(),
  ssoAzureScopes: boundedText(1000).optional(),
  ssoAzureSecurityGroup: boundedText(255).optional(),
  ssoAzureRedirectUri: z.string().url().max(1000).optional()
}).strict();

export const testarEmailSchema = z.object({
  emailDestino: z.string().email('E-mail de destino inválido').max(255)
}).strict();

export const auditoriaQuerySchema = z.object({
  pagina: z.coerce.number().int().min(1).max(100000).default(1),
  limite: z.coerce.number().int().min(10).max(100).default(25),
  tipoEvento: boundedText(50).optional(),
  sucesso: z.enum(['true', 'false']).optional(),
  termo: boundedText(255).optional()
}).strict();

export const scimListQuerySchema = z.object({
  startIndex: z.coerce.number().int().min(1).max(100000).default(1),
  count: z.coerce.number().int().min(1).max(500).default(100),
  filter: boundedText(500).optional()
}).strict();

const scimNameSchema = z.object({
  formatted: boundedText(255).optional(),
  givenName: boundedText(120).optional(),
  familyName: boundedText(120).optional()
}).strict();

const scimEmailSchema = z.object({
  value: z.string().email().max(255),
  type: boundedText(30).optional(),
  primary: z.boolean().optional()
}).strict();

export const scimUserSchema = z.object({
  schemas: z.array(z.string().max(255)).max(10).optional(),
  userName: z.string().email().max(255).optional(),
  name: scimNameSchema.optional(),
  displayName: boundedText(255).optional(),
  emails: z.array(scimEmailSchema).max(5).optional(),
  externalId: boundedText(100).optional(),
  active: z.boolean().optional()
}).strict().refine(data => Boolean(data.userName || data.emails?.length), {
  message: 'userName ou emails é obrigatório.'
});

export const scimPatchSchema = z.object({
  schemas: z.array(z.string().max(255)).max(10).optional(),
  Operations: z.array(z.object({
    op: z.enum(['add', 'replace', 'remove']),
    path: boundedText(255).optional(),
    value: z.union([z.string().max(1000), z.boolean(), z.record(z.string(), z.unknown())]).optional()
  }).strict()).min(1).max(20)
}).strict();

