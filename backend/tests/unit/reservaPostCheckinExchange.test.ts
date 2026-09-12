import pool from '../../src/config/db';
import { ReservaCreateService } from '../../src/services/reservas/reservaCreateService';
import { ReservaHistoryService } from '../../src/services/reservaHistoryService';
import { wsManager } from '../../src/websocket/wsServer';
import { DateTime } from 'luxon';

jest.mock('../../src/config/db');
jest.mock('../../src/services/reservaHistoryService');
jest.mock('../../src/websocket/wsServer');
jest.mock('../../src/services/configService', () => ({
  ConfigService: {
    get: jest.fn().mockImplementation((key: string, defaultValue: string) => {
      if (key === 'PERMITIR_TROCA_MESMO_DIA') return Promise.resolve('true');
      if (key === 'LIMITE_SEMANAL_RESERVAS') return Promise.resolve('5');
      return Promise.resolve(defaultValue);
    }),
    getNumber: jest.fn().mockImplementation((key: string, defaultValue: number) => Promise.resolve(defaultValue))
  }
}));

describe('Regra de Troca de Assento: Conclusão Pós Check-in vs Troca Pré Check-in', () => {
  let mockClient: any;
  // Próxima segunda-feira para garantir dia útil
  const hojeLuxon = DateTime.now().setZone('America/Sao_Paulo').startOf('day');
  const diaUtilLuxon = hojeLuxon.weekday >= 6 ? hojeLuxon.plus({ days: 8 - hojeLuxon.weekday }) : hojeLuxon;
  const diaUtilIso = diaUtilLuxon.toISODate()!;

  beforeEach(() => {
    jest.clearAllMocks();

    const { ConfigService } = require('../../src/services/configService');
    (ConfigService.get as jest.Mock).mockImplementation((key: string, defaultValue: string) => {
      if (key === 'PERMITIR_TROCA_MESMO_DIA') return Promise.resolve('true');
      if (key === 'LIMITE_SEMANAL_RESERVAS') return Promise.resolve('5');
      return Promise.resolve(defaultValue);
    });

    mockClient = {
      query: jest.fn(),
      release: jest.fn()
    };

    (pool.connect as jest.Mock).mockResolvedValue(mockClient);
    (ReservaHistoryService.registrarEvento as jest.Mock).mockResolvedValue(1);
  });

  it('deve realizar troca simples via UPDATE se o check-in AINDA NÃO foi realizado', async () => {
    // 1. BEGIN
    // 2. SELECT cadeira (Mesa 02)
    // 3. SELECT cadeira ocupada
    // 4. SELECT reserva existente do dia
    // 5. UPDATE reservas SET cadeira_id = ...
    // 6. COMMIT
    mockClient.query
      .mockResolvedValueOnce({}) // BEGIN
      .mockResolvedValueOnce({ // SELECT cadeira 2
        rowCount: 1,
        rows: [{ id: 2, identificador: '02', ativa: true, status_operacional: 'DISPONIVEL', baia_id: 1, baia_nome: 'Baia 1', escritorio_id: 1 }]
      })
      .mockResolvedValueOnce({ rowCount: 0, rows: [] }) // Cadeira 2 livre
      .mockResolvedValueOnce({ // Reserva existente na cadeira 1 SEM check-in
        rowCount: 1,
        rows: [{
          id: 100,
          cadeira_id: 1,
          checkin_realizado: false,
          checkin_em: null,
          escritorio_id: 1,
          identificador: '01'
        }]
      })
      .mockResolvedValueOnce({ // UPDATE reserva existente
        rowCount: 1,
        rows: [{
          id: 100,
          cadeira_id: 2,
          usuario_id: 10,
          data_reserva: diaUtilIso,
          checkin_realizado: false,
          checkin_em: null,
          status: 'ATIVA',
          codigo_comprovante: 'RES-TROCADA123',
          criado_em: new Date().toISOString()
        }]
      })
      .mockResolvedValueOnce({}); // COMMIT

    const result = await ReservaCreateService.criarReserva({
      cadeiraId: 2,
      usuarioId: 10,
      usuarioNome: 'Colaborador Teste',
      usuarioEmail: 'colab@empresa.com',
      usuarioPerfil: 'COLABORADOR',
      dataReserva: diaUtilIso
    });

    if (!result.success) {
      console.log('FALHA TESTE 1:', result);
    }

    expect(result.success).toBe(true);
    expect(result.trocaRealizada).toBe(true);
    expect(result.reserva.cadeira_id).toBe(2);

    // Verifica que o histórico registrado foi TROCADA
    expect(ReservaHistoryService.registrarEvento).toHaveBeenCalledWith(
      expect.objectContaining({
        tipoEvento: 'TROCADA',
        reservaId: 100,
        cadeiraId: 2,
        usuarioId: 10
      }),
      mockClient
    );
  });

  it('deve marcar a reserva antiga como CONCLUIDA e criar uma NOVA reserva com status ATIVA se o check-in JÁ FOI realizado', async () => {
    mockClient.query
      .mockResolvedValueOnce({}) // BEGIN
      .mockResolvedValueOnce({ // SELECT cadeira 2
        rowCount: 1,
        rows: [{ id: 2, identificador: '02', ativa: true, status_operacional: 'DISPONIVEL', baia_id: 1, baia_nome: 'Baia 1', escritorio_id: 1 }]
      })
      .mockResolvedValueOnce({ rowCount: 0, rows: [] }) // Cadeira 2 livre
      .mockResolvedValueOnce({ // Reserva existente na cadeira 1 COM check-in
        rowCount: 1,
        rows: [{
          id: 100,
          cadeira_id: 1,
          checkin_realizado: true,
          checkin_em: new Date(),
          escritorio_id: 1,
          identificador: '01',
          codigo_comprovante: 'RES-ANTIGA100'
        }]
      })
      .mockResolvedValueOnce({ rowCount: 1 }) // UPDATE reserva antiga para CONCLUIDA
      .mockResolvedValueOnce({ // INSERT nova reserva na cadeira 2
        rowCount: 1,
        rows: [{
          id: 101, // Novo ID
          cadeira_id: 2,
          usuario_id: 10,
          data_reserva: diaUtilIso,
          checkin_realizado: false,
          checkin_em: null,
          status: 'ATIVA',
          codigo_comprovante: 'RES-NOVA101',
          criado_em: new Date().toISOString()
        }]
      })
      .mockResolvedValueOnce({}); // COMMIT

    const result = await ReservaCreateService.criarReserva({
      cadeiraId: 2,
      usuarioId: 10,
      usuarioNome: 'Colaborador Teste',
      usuarioEmail: 'colab@empresa.com',
      usuarioPerfil: 'COLABORADOR',
      dataReserva: diaUtilIso
    });

    expect(result.success).toBe(true);
    expect(result.trocaRealizada).toBe(true);
    expect(result.reserva.id).toBe(101);
    expect(result.reserva.cadeira_id).toBe(2);
    expect(result.reserva.status).toBe('ATIVA');

    // Verifica que foram gerados dois eventos: MESA_LIBERADA (antiga) e CRIADA (nova)
    expect(ReservaHistoryService.registrarEvento).toHaveBeenCalledWith(
      expect.objectContaining({
        tipoEvento: 'MESA_LIBERADA',
        reservaId: 100,
        cadeiraId: 1,
        usuarioId: 10
      }),
      mockClient
    );

    expect(ReservaHistoryService.registrarEvento).toHaveBeenCalledWith(
      expect.objectContaining({
        tipoEvento: 'CRIADA',
        reservaId: 101,
        cadeiraId: 2,
        usuarioId: 10,
        detalhes: expect.objectContaining({
          trocaPosCheckin: true
        })
      }),
      mockClient
    );

    // Verifica emissão do WebSocket liberando mesa 1 e ocupando mesa 2
    expect(wsManager.broadcastSeatUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        cadeiraId: 2,
        status: 'ocupada'
      })
    );

    expect(wsManager.broadcastSeatUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        cadeiraId: 1,
        status: 'livre'
      })
    );
  });
});
