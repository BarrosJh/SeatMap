import { z } from 'zod';

export const loginSchema = z.object({
  login: z.string().min(1, 'Login é obrigatório').max(255),
  senha: z.string().min(1, 'Senha é obrigatória').max(255)
});

export const ssoLoginSchema = z.object({
  provedor: z.enum(['GOOGLE', 'AZURE', 'OKTA']),
  token: z.string().min(1, 'Token SSO é obrigatório')
});

export const validarMfaEmailSchema = z.object({
  email: z.string().email('E-mail inválido'),
  codigo: z.string().min(4, 'Código deve ter no mínimo 4 dígitos').max(8)
});

export const validarTotpSchema = z.object({
  login: z.string().optional(),
  tokenMfa: z.string().optional(),
  codigo: z.string().min(6, 'Código TOTP deve ter 6 dígitos').max(6)
});

export const esqueciSenhaSchema = z.object({
  email: z.string().email('E-mail inválido')
});

export const redefinirSenhaSchema = z.object({
  token: z.string().min(1, 'Token de recuperação é obrigatório'),
  novaSenha: z.string().min(6, 'Senha deve ter no mínimo 6 caracteres').max(100)
});

export const refreshTokenSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token é obrigatório')
});
