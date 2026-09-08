import { z } from 'zod';

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
}).strict();

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
  exigir_mfa: z.boolean().optional(),
  ativo: z.boolean().optional()
}).strict();

export const alterarStatusUsuarioSchema = z.object({
  ativo: z.boolean({ message: 'Campo ativo é obrigatório.' })
}).strict();

export const resetSenhaUsuarioSchema = z.object({
  novaSenha: z.string().min(6, 'Senha deve ter no mínimo 6 caracteres').max(100)
}).strict();

export const importarLoteUsuariosSchema = z.object({
  usuarios: z.array(
    z.object({
      nome: z.string().min(2),
      email: z.string().email(),
      matricula: z.string().min(2),
      perfil: z.string().optional(),
      departamento: z.string().optional(),
      permissaoTi: z.boolean().optional(),
      permissaoRh: z.boolean().optional(),
      permissao_ti: z.boolean().optional(),
      permissao_rh: z.boolean().optional()
    }).strict()
  ).min(1, 'A lista de usuários para importação não pode estar vazia.').max(1000),
  defaultSenha: z.string().min(6).max(100).optional()
}).strict();

export const criarDepartamentoSchema = z.object({
  nome: z.string().trim().min(2).max(255)
}).strict();

export const usuarioListQuerySchema = z.object({
  busca: z.string().trim().max(255).optional(),
  departamentoId: z.string().regex(/^\d+$/, 'Departamento inválido.').optional(),
  perfil: z.enum(['todos', 'COLABORADOR', 'GESTAO', 'ADMIN_RH', 'ADMIN_TI']).optional(),
  ativo: z.enum(['todos', 'true', 'false']).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(100),
  offset: z.coerce.number().int().min(0).max(100000).default(0)
}).strict();
