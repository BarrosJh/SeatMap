import pool from '../../src/config/db';
import { AdminReservasController } from '../../src/controllers/admin/adminReservasController';
import { RelatorioService } from '../../src/services/relatorioService';
import { WsManager, AuthenticatedWebSocket } from '../../src/websocket/wsServer';
import { ReservaCreateService } from '../../src/services/reservas/reservaCreateService';
import { ReservaHistoryService } from '../../src/services/reservaHistoryService';
import { ConfigService } from '../../src/services/configService';

jest.mock('../../src/config/db');
jest.mock('../../src/services/reservaHistoryService');
jest.mock('../../src/websocket/wsServer', () => {
  const original = jest.requireActual('../../src/websocket/wsServer');
  return {
    ...original,
    wsManager: {
      ...original.wsManager,
      broadcastSeatUpdate: jest.fn(),
      broadcastAssento: jest.fn()
    }
  };
});

describe('Segurança e Integridade: Validação dos Achados da Auditoria (RH-Only, Concorrência, WS, Sanitização)', () => {
  let statusMock: jest.Mock;
  let jsonMock: jest.Mock;
  let mockRes: any;

  beforeEach(() => {
    jest.clearAllMocks();
    statusMock = jest.fn().mockReturnThis();
    jsonMock = jest.fn().mockReturnThis();
    mockRes = {
      status: statusMock,
      json: jsonMock
    };
  });

  describe('1. Cancelamento Administrativo Restrito ao RH (Regra Estrita)', () => {
    it('deve barrar tentativa de cancelamento de reservas por perfil GESTAO (403 Forbidden)', async () => {
      const mockReq: any = {
        user: {
          userId: 5,
          nome: 'Gestor Vendas',
          perfil: 'GESTAO',
          departamentoId: 2,
          permissaoRh: false,
          permissaoTi: false
        },
        params: { id: '42' },
        body: { justificativa: 'Tentativa de cancelamento' }
      };

      await AdminReservasController.cancelarReservaAdmin(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(403);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        error: 'Apenas a equipe de RH possui permissão para cancelar reservas de outros colaboradores.'
      }));
    });

    it('deve autorizar cancelamento de reservas para operador com perfil ADMIN_RH', async () => {
      const mockReq: any = {
        user: {
          userId: 1,
          nome: 'Administrador RH',
          perfil: 'ADMIN_RH',
          departamentoId: 1,
          permissaoRh: true,
          permissaoTi: false
        },
        params: { id: '42' },
        body: { justificativa: 'Remanejamento de equipe pelo RH' }
      };

      (pool.query as jest.Mock)
        .mockResolvedValueOnce({ // SELECT reserva FOR UPDATE
          rowCount: 1,
          rows: [{
            id: 42,
            usuario_id: 10,
            cadeira_id: 200,
            data_reserva: '2026-09-15',
            status: 'ATIVA',
            codigo_comprovante: 'RES-TEST123',
            escritorio_id: 1,
            cadeira_identificador: 'M-01',
            usuario_nome: 'Colaborador Teste'
          }]
        })
        .mockResolvedValueOnce({ rowCount: 1 }); // UPDATE reservas SET status = 'CANCELADA'

      (ReservaHistoryService.registrarEvento as jest.Mock).mockResolvedValueOnce({});

      await AdminReservasController.cancelarReservaAdmin(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(200);
      expect(jsonMock).toHaveBeenCalledWith(expect.objectContaining({
        message: 'Reserva cancelada com sucesso pela gestão/RH.',
        reservaId: '42'
      }));
    });
  });

  describe('2. Isolamento Departamental em getReservas para GESTAO', () => {
    it('deve filtrar automaticamente reservas pelo departamento do Gestor', async () => {
      const mockReq: any = {
        user: {
          userId: 5,
          nome: 'Gestor Vendas',
          perfil: 'GESTAO',
          departamentoId: 2,
          permissaoRh: false
        },
        query: {
          limit: '50',
          offset: '0'
        }
      };

      (pool.query as jest.Mock)
        .mockResolvedValueOnce({ rowCount: 1, rows: [{ total: 1 }] }) // COUNT
        .mockResolvedValueOnce({ rowCount: 1, rows: [{ id: 1, usuario_nome: 'Colab Vendas' }] }); // DATA

      await AdminReservasController.getReservas(mockReq, mockRes);

      expect(statusMock).toHaveBeenCalledWith(200);
      const queryCall = (pool.query as jest.Mock).mock.calls[0];
      const sql = queryCall[0];
      const params = queryCall[1];

      expect(sql).toContain('d.id = $');
      expect(params).toContain(2); // departamentoId do gestor
    });
  });

  describe('3. Sanitização de Caracteres Coringa na Busca de Relatórios', () => {
    it('deve escapar caracteres coringa % e _ na busca textual', () => {
      const whereResult = RelatorioService.buildWhereClause({
        busca: '50%_desconto',
        dataInicio: '2026-09-01',
        dataFim: '2026-09-30'
      });

      expect(whereResult.params).toContain('%50\\%\\_desconto%');
    });
  });

  describe('4. WebSocket: Prevenção de Memory & Event Leak no joinRoom', () => {
    it('deve desinscrever da sala anterior ao subscrever em um novo escritório', () => {
      const wsManager = WsManager.getInstance();
      const mockWs: any = {
        isAlive: true,
        readyState: 1,
        send: jest.fn()
      };

      wsManager.joinRoom(1, mockWs as AuthenticatedWebSocket);
      expect(mockWs.escritorioId).toBe(1);

      // Troca para o escritório 2
      wsManager.joinRoom(2, mockWs as AuthenticatedWebSocket);
      expect(mockWs.escritorioId).toBe(2);

      // Verificar que a sala 1 não contém mais o socket
      const rooms = (wsManager as any).rooms;
      const room1 = rooms.get(1);
      const room2 = rooms.get(2);

      expect(room1?.has(mockWs)).toBeFalsy();
      expect(room2?.has(mockWs)).toBeTruthy();
    });
  });

  describe('5. Resiliência a Deadlocks Concorrentes na Criação de Reserva', () => {
    it('deve retornar 409 Conflict amigável quando ocorrer erro de deadlock (40P01)', async () => {
      jest.spyOn(ConfigService, 'get').mockResolvedValue('11:00');

      (pool.query as jest.Mock)
        .mockResolvedValueOnce({ rowCount: 0 }) // BEGIN
        .mockRejectedValueOnce({ code: '40P01', message: 'deadlock detected' }); // Lock fail

      const result = await ReservaCreateService.criarReserva({
        cadeiraId: 10,
        usuarioId: 100,
        usuarioNome: 'Colaborador A',
        usuarioEmail: 'colab@empresa.com',
        usuarioPerfil: 'COLABORADOR',
        dataReserva: '2026-09-15'
      });

      expect(result.success).toBe(false);
      expect(result.code).toBe(409);
      expect(result.error).toContain('Conflito de Concorrência');
    });
  });
});
