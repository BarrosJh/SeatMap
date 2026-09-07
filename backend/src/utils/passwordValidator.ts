export interface PasswordValidationResult {
  valid: boolean;
  message?: string;
}

/**
 * Validador de Política de Senhas Corporativas (Enterprise Password Policy)
 * Exige:
 * - No mínimo 8 caracteres
 * - Pelo menos 1 letra maiúscula [A-Z]
 * - Pelo menos 1 letra minúscula [a-z]
 * - Pelo menos 1 dígito numérico [0-9]
 * - Pelo menos 1 caractere especial
 */
export function validatePasswordPolicy(password: string): PasswordValidationResult {
  if (!password || typeof password !== 'string') {
    return { valid: false, message: 'A senha é obrigatória.' };
  }

  if (password.length < 8) {
    return { valid: false, message: 'A senha deve ter no mínimo 8 caracteres.' };
  }

  if (!/[A-Z]/.test(password)) {
    return { valid: false, message: 'A senha deve conter pelo menos uma letra maiúscula (A-Z).' };
  }

  if (!/[a-z]/.test(password)) {
    return { valid: false, message: 'A senha deve conter pelo menos uma letra minúscula (a-z).' };
  }

  if (!/[0-9]/.test(password)) {
    return { valid: false, message: 'A senha deve conter pelo menos um número (0-9).' };
  }

  if (!/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password)) {
    return { valid: false, message: 'A senha deve conter pelo menos um caractere especial (!@#$%&*...).' };
  }

  return { valid: true };
}

