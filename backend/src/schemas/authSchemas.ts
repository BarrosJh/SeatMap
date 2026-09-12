import { z } from 'zod';

export const loginSchema = z.object({
  login: z.string().min(1, 'Login é obrigatório').max(255),
  senha: z.string().min(1, 'Senha é obrigatória').max(255)
}).strict();

export const ssoLoginSchema = z.object({
  provider: z.enum(['AZURE', 'MICROSOFT', 'azure', 'microsoft']),
  idToken: z.string().min(1, 'Token SSO é obrigatório').max(10000),
  email: z.string().email('E-mail inválido').max(255).optional(),
  name: z.string().max(255).optional(),
  ssoId: z.string().max(255).optional()
}).strict();

export const validarMfaEmailSchema = z.object({
  tempToken: z.string().min(1).max(4096),
  codigo: z.string().regex(/^\d{6}$/, 'Código MFA deve conter 6 dígitos')
}).strict();

export const validarTotpSchema = z.object({
  tempToken: z.string().min(1).max(4096),
  codigo: z.string().regex(/^\d{6}$/, 'Código TOTP deve conter 6 dígitos')
}).strict();

export const esqueciSenhaSchema = z.object({
  login: z.string().min(1, 'Login é obrigatório').max(255)
}).strict();

export const redefinirSenhaSchema = z.object({
  login: z.string().min(1).max(255),
  codigo: z.string().regex(/^\d{6}$/, 'Código deve conter 6 dígitos'),
  novaSenha: z.string().min(6, 'Senha deve ter no mínimo 6 caracteres').max(100)
}).strict();

export const refreshTokenSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token é obrigatório').max(512)
}).strict();

export const logoutSchema = z.object({
  refreshToken: z.string().min(1).max(512).optional()
}).strict().optional();

export const senhaAtualSchema = z.object({
  senha: z.string().min(1).max(255)
}).strict();

export const codigoMfaSchema = z.object({
  codigo: z.string().regex(/^\d{6}$/, 'Código deve conter 6 dígitos')
}).strict();
