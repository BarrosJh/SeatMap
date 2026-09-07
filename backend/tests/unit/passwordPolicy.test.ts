import { validatePasswordPolicy } from '../../src/utils/passwordValidator';

describe('Enterprise Password Policy Validator', () => {
  it('deve rejeitar senhas nulas, vazias ou não-string', () => {
    // @ts-ignore
    expect(validatePasswordPolicy(null).valid).toBe(false);
    // @ts-ignore
    expect(validatePasswordPolicy(undefined).valid).toBe(false);
    expect(validatePasswordPolicy('').valid).toBe(false);
  });

  it('deve rejeitar senhas com menos de 8 caracteres', () => {
    const res = validatePasswordPolicy('Ab1@xyz');
    expect(res.valid).toBe(false);
    expect(res.message).toContain('mínimo 8 caracteres');
  });

  it('deve rejeitar senhas sem letra maiúscula', () => {
    const res = validatePasswordPolicy('senha123@#');
    expect(res.valid).toBe(false);
    expect(res.message).toContain('maiúscula');
  });

  it('deve rejeitar senhas sem letra minúscula', () => {
    const res = validatePasswordPolicy('SENHA123@#');
    expect(res.valid).toBe(false);
    expect(res.message).toContain('minúscula');
  });

  it('deve rejeitar senhas sem número', () => {
    const res = validatePasswordPolicy('SenhaSegura@#');
    expect(res.valid).toBe(false);
    expect(res.message).toContain('número');
  });

  it('deve rejeitar senhas sem caractere especial', () => {
    const res = validatePasswordPolicy('SenhaSegura123');
    expect(res.valid).toBe(false);
    expect(res.message).toContain('especial');
  });

  it('deve aprovar senhas corporativas fortes e completas', () => {
    expect(validatePasswordPolicy('Forte@2026!').valid).toBe(true);
    expect(validatePasswordPolicy('Mudar@123').valid).toBe(true);
    expect(validatePasswordPolicy('Corp#Sec999$').valid).toBe(true);
  });
});

