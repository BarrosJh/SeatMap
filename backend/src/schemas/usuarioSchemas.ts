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
});

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
});

export const alterarStatusUsuarioSchema = z.object({
  ativo: z.boolean({ message: 'Campo ativo é obrigatório.' })
});

export const resetSenhaUsuarioSchema = z.object({
  novaSenha: z.string().min(6, 'Senha deve ter no mínimo 6 caracteres').max(100)
});

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
    })
  ).min(1, 'A lista de usuários para importação não pode estar vazia.'),
  defaultSenha: z.string().min(6).optional()
});
