import pool from '../../src/config/db';
import { ReservaCancelService } from '../../src/services/reservas/reservaCancelService';
import { ReservaCheckoutService } from '../../src/services/reservas/reservaCheckoutService';
import { ReservaHistoryService } from '../../src/services/reservaHistoryService';
import { wsManager } from '../../src/websocket/wsServer';

jest.mock('../../src/config/db');
jest.mock('../../src/services/reservaHistoryService');
jest.mock('../../src/websocket/wsServer');

describe('Fluxo de Liberação de Mesa (Checkout) e Bloqueio de Cancelamento Pós Check-in', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('ReservaCancelService.cancelarReserva', () => {
    it('deve barrar cancelamento se a reserva já tiver check-in realizado', async () => {
      (pool.query as jest.Mock).mockResolvedValueOnce({
        rowCount: 1,
        rows: [{
          id: 101,
          usuario_id: 5,
          cadeira_id: 12,
          data_reserva: new Date().toISOString().split('T')[0],
          checkin_realizado: true,
          status: 'ATIVA',
          codigo_comprovante: 'RES-TEST1234',
          escritorio_id: 1,
          cadeira_identificador: '01'
        }]
      });

      const result = await ReservaCancelService.cancelarReserva(101, 5);

      expect(result.success).toBe(false);
      expect(result.code).toBe(400);
      expect(result.error).toContain('check-in realizado');
      expect(result.error).toContain('Liberar Mesa');
    });

    it('deve permitir cancelamento normal se o check-in ainda não foi realizado', async () => {
      const hoje = new Date().toISOString().split('T')[0];
      (pool.query as jest.Mock)
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [{
            id: 102,
            usuario_id: 5,
            cadeira_id: 12,
            data_reserva: hoje,
            checkin_realizado: false,
            status: 'ATIVA',
            codigo_comprovante: 'RES-TEST5678',
            escritorio_id: 1,
            cadeira_identificador: '01'
          }]
        })
        .mockResolvedValueOnce({ rowCount: 1 }); // UPDATE

      (ReservaHistoryService.registrarEvento as jest.Mock).mockResolvedValueOnce(1);

      const result = await ReservaCancelService.cancelarReserva(102, 5);

      expect(result.success).toBe(true);
      expect(result.code).toBe(200);
      expect(result.reserva?.status).toBe('CANCELADA');
      expect(ReservaHistoryService.registrarEvento).toHaveBeenCalledWith(
        expect.objectContaining({
          tipoEvento: 'CANCELADA_USUARIO',
          usuarioId: 5
        }),
        expect.anything()
      );
    });
  });

  describe('ReservaCheckoutService.liberarMesa', () => {
    it('deve rejeitar liberação se a reserva não existe', async () => {
      (pool.query as jest.Mock).mockResolvedValueOnce({ rowCount: 0, rows: [] });

      const result = await ReservaCheckoutService.liberarMesa(999, 5);

      expect(result.success).toBe(false);
      expect(result.code).toBe(404);
      expect(result.error).toContain('não encontrada');
    });

    it('deve rejeitar liberação se o usuário não é o dono da reserva', async () => {
      (pool.query as jest.Mock).mockResolvedValueOnce({
        rowCount: 1,
        rows: [{
          id: 103,
          usuario_id: 8, // Outro usuário
          cadeira_id: 12,
          data_reserva: new Date().toISOString().split('T')[0],
          checkin_realizado: true,
          status: 'ATIVA'
        }]
      });

      const result = await ReservaCheckoutService.liberarMesa(103, 5);

      expect(result.success).toBe(false);
      expect(result.code).toBe(403);
      expect(result.error).toContain('suas próprias reservas');
    });

    it('deve rejeitar liberação se o check-in ainda não foi realizado', async () => {
      (pool.query as jest.Mock).mockResolvedValueOnce({
        rowCount: 1,
        rows: [{
          id: 104,
          usuario_id: 5,
          cadeira_id: 12,
          data_reserva: new Date().toISOString().split('T')[0],
          checkin_realizado: false,
          status: 'ATIVA',
          codigo_comprovante: 'RES-PENDENTE'
        }]
      });

      const result = await ReservaCheckoutService.liberarMesa(104, 5);

      expect(result.success).toBe(false);
      expect(result.code).toBe(400);
      expect(result.error).toContain('após a confirmação do check-in');
    });

    it('deve liberar mesa com sucesso, marcar CONCLUIDA, registrar evento MESA_LIBERADA e disparar WebSocket', async () => {
      const hoje = new Date().toISOString().split('T')[0];
      (pool.query as jest.Mock)
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [{
            id: 105,
            usuario_id: 5,
            cadeira_id: 12,
            data_reserva: hoje,
            checkin_realizado: true,
            checkin_em: new Date(),
            status: 'ATIVA',
            codigo_comprovante: 'RES-CHECKEDIN',
            escritorio_id: 1,
            cadeira_identificador: '01'
          }]
        })
        .mockResolvedValueOnce({ rowCount: 1 }); // UPDATE reservas SET status = 'CONCLUIDA'

      (ReservaHistoryService.registrarEvento as jest.Mock).mockResolvedValueOnce(1);

      const result = await ReservaCheckoutService.liberarMesa(105, 5);

      expect(result.success).toBe(true);
      expect(result.code).toBe(200);
      expect(result.reserva?.status).toBe('CONCLUIDA');
      expect(result.reserva?.checkoutEm).toBeDefined();

      expect(ReservaHistoryService.registrarEvento).toHaveBeenCalledWith(
        expect.objectContaining({
          tipoEvento: 'MESA_LIBERADA',
          usuarioId: 5,
          reservaId: 105,
          cadeiraId: 12
        }),
        expect.anything()
      );

      expect(wsManager.broadcastSeatUpdate).toHaveBeenCalledWith(
        expect.objectContaining({
          evento: 'assento_atualizado',
          escritorioId: 1,
          cadeiraId: 12,
          status: 'livre',
          ocupante: null
        })
      );
    });
  });
});

