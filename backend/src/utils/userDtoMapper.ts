export interface UserResponseDto {
  id: number;
  nome: string;
  email: string;
  matricula: string;
  perfil: string;
  departamentoId: number | null;
  departamentoNome?: string | null;
  permissaoRh: boolean;
  permissaoTi: boolean;
  is_admin?: boolean;
  ativo: boolean;
  totpAtivo: boolean;
  exigirMfa: boolean;
  ultimoLogin?: string | null;
}

export function toUserResponseDto(user: any): UserResponseDto {
  if (!user) {
    throw new Error('Usuário inválido para mapeamento de DTO.');
  }

  return {
    id: user.id || user.userId,
    nome: user.nome,
    email: user.email,
    matricula: user.matricula,
    perfil: user.perfil,
    departamentoId: user.departamento_id !== undefined ? user.departamento_id : (user.departamentoId || null),
    departamentoNome: user.departamento_nome || user.departamentoNome || null,
    permissaoRh: Boolean(user.permissao_rh !== undefined ? user.permissao_rh : (user.permissaoRh || user.perfil === 'ADMIN_RH')),
    permissaoTi: Boolean(user.permissao_ti !== undefined ? user.permissao_ti : (user.permissaoTi || user.perfil === 'ADMIN_TI')),
    is_admin: Boolean(user.is_admin || user.perfil === 'ADMIN_RH' || user.perfil === 'ADMIN_TI'),
    ativo: user.ativo !== undefined ? Boolean(user.ativo) : true,
    totpAtivo: Boolean(user.totp_ativo !== undefined ? user.totp_ativo : user.totpAtivo),
    exigirMfa: Boolean(user.exigir_mfa !== undefined ? user.exigir_mfa : user.exigirMfa),
    ultimoLogin: user.ultimo_login || user.ultimoLogin || null
  };
}

