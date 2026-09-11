import { Request, Response } from 'express';
import { LoginController } from '../../src/controllers/auth/loginController';
import pool from '../../src/config/db';

describe('LoginController.getMe (Perfil Autoritativo da Sessão)', () => {
  let mockReq: Partial<Request> & { user?: any; correlationId?: string };
  let mockRes: Partial<Response>;
  let statusMock: jest.Mock;
  let jsonMock: jest.Mock;

  beforeEach(() => {
    statusMock = jest.fn().mockReturnThis();
    jsonMock = jest.fn().mockReturnThis();
    mockReq = {
      correlationId: 'test-corr-id'
    };
    mockRes = {
      status: statusMock,
      json: jsonMock
    };
    jest.clearAllMocks();
  });

  it('1. Deve rejeitar requisição sem usuário autenticado com HTTP 401', async () => {
    mockReq.user = undefined;

    await LoginController.getMe(mockReq as Request, mockRes as Response);

    expect(statusMock).toHaveBeenCalledWith(401);
    expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.stringContaining('Sessão inválida')
    }));
  });

  it('2. Deve retornar dados atualizados para usuário com perfil RH', async () => {
    mockReq.user = { userId: 10 };

    const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => ({
      rowCount: 1,
      rows: [{
        id: 10,
        nome: 'Maria RH',
        email: 'maria@empresa.com',
        matricula: 'RH001',
        perfil: 'ADMIN_RH',
        permissao_rh: true,
        permissao_ti: false,
        exigir_mfa: false,
        ativo: true,
        totp_ativo: false,
        departamento_id: 2,
        departamento_nome: 'Recursos Humanos',
        ultimo_login: '2026-09-11 00:00:00'
      }]
    } as any));

    await LoginController.getMe(mockReq as Request, mockRes as Response);

    expect(statusMock).toHaveBeenCalledWith(200);
    expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
      id: 10,
      nome: 'Maria RH',
      perfil: 'ADMIN_RH',
      permissaoRh: true,
      permissaoTi: false,
      departamentoNome: 'Recursos Humanos'
    }));

    querySpy.mockRestore();
  });

  it('3. Deve retornar dados atualizados para usuário com perfil TI', async () => {
    mockReq.user = { userId: 20 };

    const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => ({
      rowCount: 1,
      rows: [{
        id: 20,
        nome: 'Carlos TI',
        email: 'carlos@empresa.com',
        matricula: 'TI001',
        perfil: 'ADMIN_TI',
        permissao_rh: false,
        permissao_ti: true,
        exigir_mfa: false,
        ativo: true,
        totp_ativo: false,
        departamento_id: 1,
        departamento_nome: 'Tecnologia da Informação',
        ultimo_login: '2026-09-11 00:00:00'
      }]
    } as any));

    await LoginController.getMe(mockReq as Request, mockRes as Response);

    expect(statusMock).toHaveBeenCalledWith(200);
    expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
      id: 20,
      nome: 'Carlos TI',
      perfil: 'ADMIN_TI',
      permissaoRh: false,
      permissaoTi: true,
      departamentoNome: 'Tecnologia da Informação'
    }));

    querySpy.mockRestore();
  });

  it('4. Deve barrar usuário inativo com HTTP 401', async () => {
    mockReq.user = { userId: 30 };

    const querySpy = jest.spyOn(pool, 'query').mockImplementation(async () => ({
      rowCount: 1,
      rows: [{
        id: 30,
        nome: 'Inativo User',
        email: 'inativo@empresa.com',
        matricula: 'IN001',
        perfil: 'COLABORADOR',
        permissao_rh: false,
        permissao_ti: false,
        ativo: false
      }]
    } as any));

    await LoginController.getMe(mockReq as Request, mockRes as Response);

    expect(statusMock).toHaveBeenCalledWith(401);
    expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.stringContaining('Usuário inativo')
    }));

    querySpy.mockRestore();
  });
});

