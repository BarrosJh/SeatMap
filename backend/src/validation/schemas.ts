import { z } from 'zod';

export const dateIsoRegex = /^\d{4}-\d{2}-\d{2}$/;
export const timeRegex = /^([01]\d|2[0-3]):([0-5]\d)$/;

// Schemas para Autenticação
export const loginSchema = z.object({
  login: z.string().min(1, 'Login é obrigatório').max(255),
  senha: z.string().min(1, 'Senha é obrigatória').max(255)
});

// Schemas para Reserva
export const criarReservaSchema = z.object({
  cadeiraId: z.number().int().positive('ID de cadeira inválido'),
  data: z.string().regex(dateIsoRegex, 'Data deve estar no formato YYYY-MM-DD')
});

// Schemas para Manutenção (Facilities)
export const colocarManutencaoSchema = z.object({
  motivo: z.string().min(1, 'O motivo da manutenção é obrigatório').max(500),
  previsaoRetorno: z.string().datetime({ offset: true }).or(z.string().regex(/^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2}(\.\d{1,3})?)?Z?)?$/)).optional().nullable()
});

// Schemas para Criação de Usuário
export const criarUsuarioSchema = z.object({
  nome: z.string().min(2, 'Nome deve ter pelo menos 2 caracteres').max(255),
  email: z.string().email('E-mail inválido').max(255),
  matricula: z.string().min(2, 'Matrícula inválida').max(50),
  senha: z.string().min(6, 'Senha deve ter no mínimo 6 caracteres').max(100),
  departamentoId: z.number().int().positive().optional().nullable(),
  perfil: z.enum(['COLABORADOR', 'GESTAO', 'ADMIN_RH', 'ADMIN_TI']),
  permissaoRh: z.boolean().optional(),
  permissaoTi: z.boolean().optional(),
  permissao_rh: z.boolean().optional(),
  permissao_ti: z.boolean().optional(),
  exigirMfa: z.boolean().optional(),
  exigir_mfa: z.boolean().optional()
});

// Schemas para Edição de Usuário
export const editarUsuarioSchema = z.object({
  nome: z.string().min(2).max(255).optional(),
  email: z.string().email('E-mail inválido').max(255).optional(),
  matricula: z.string().min(2).max(50).optional(),
  departamentoId: z.number().int().positive().optional().nullable(),
  perfil: z.enum(['COLABORADOR', 'GESTAO', 'ADMIN_RH', 'ADMIN_TI']).optional(),
  permissaoRh: z.boolean().optional(),
  permissaoTi: z.boolean().optional(),
  permissao_rh: z.boolean().optional(),
  permissao_ti: z.boolean().optional(),
  exigirMfa: z.boolean().optional(),
  exigir_mfa: z.boolean().optional()
});

// Schemas para Parâmetros
export const updateParametrosSchema = z.object({
  configuracoes: z.record(z.string(), z.string()).refine(obj => Object.keys(obj).length > 0, {
    message: 'Nenhuma configuração enviada para atualização.'
  })
});

