import pool from '../../src/config/db';
import { getDbClient } from '../../src/utils/dbClient';
import { NoShowJobService } from '../../src/services/cron/jobs/noShowJobService';
import { AutoConclusionJobService } from '../../src/services/cron/jobs/autoConclusionJobService';
import { CronService } from '../../src/services/cronService';
import { EscritorioService } from '../../src/services/escritorioService';
import { ReservaHistoryService } from '../../src/services/reservaHistoryService';
import { wsManager } from '../../src/websocket/wsServer';

jest.mock('../../src/config/db');
jest.mock('../../src/utils/dbClient');
jest.mock('../../src/services/reservaHistoryService');
jest.mock('../../src/websocket/wsServer');

describe('Modular Cron Jobs & Historical Map Query', () => {
  let mockClient: any;

  beforeEach(() => {
    jest.clearAllMocks();
    mockClient = {
      query: jest.fn(),
      release: jest.fn()
    };
    (getDbClient as jest.Mock).mockResolvedValue(mockClient);
  });

  describe('AutoConclusionJobService.execute', () => {
    it('deve concluir em lote reservas de datas anteriores que possuem check-in realizado', async () => {
      // 1. BEGIN
      mockClient.query.mockResolvedValueOnce({});
      // 2. Lock obtido com sucesso
      mockClient.query.mockResolvedValueOnce({ rows: [{ obtido: true }] });
      // 3. Select de reservas passadas ativas com check-in
      mockClient.query.mockResolvedValueOnce({
        rowCount: 2,
        rows: [
          {
            id: 10,
            cadeira_id: 1,
            usuario_id: 100,
            data_reserva: '2026-09-01',
            checkin_em: new Date('2026-09-01T09:00:00Z'),
            checkout_em: null,
            codigo_comprovante: 'RES-10',
            escritorio_id: 1,
            cadeira_identificador: '01'
          },
          {
            id: 11,
            cadeira_id: 2,
            usuario_id: 101,
            data_reserva: '2026-09-01',
            checkin_em: new Date('2026-09-01T08:30:00Z'),
            checkout_em: null,
            codigo_comprovante: 'RES-11',
            escritorio_id: 1,
            cadeira_identificador: '02'
          }
        ]
      });
      // 4. UPDATE reservas SET status = 'CONCLUIDA'
      mockClient.query.mockResolvedValueOnce({ rowCount: 2 });
      // 5. COMMIT
      mockClient.query.mockResolvedValueOnce({});

      const result = await AutoConclusionJobService.execute('2026-09-12');

      expect(result.totalConcluidas).toBe(2);
      expect(result.reservas).toHaveLength(2);
      expect(ReservaHistoryService.registrarEvento).toHaveBeenCalledTimes(2);
      expect(mockClient.release).toHaveBeenCalled();
    });

    it('não deve fazer alterações quando não houver reservas passadas pendentes de conclusão', async () => {
      mockClient.query.mockResolvedValueOnce({}); // BEGIN
      mockClient.query.mockResolvedValueOnce({ rows: [{ obtido: true }] }); // Lock
      mockClient.query.mockResolvedValueOnce({ rowCount: 0, rows: [] }); // Select vazio
      mockClient.query.mockResolvedValueOnce({}); // COMMIT

      const result = await AutoConclusionJobService.execute('2026-09-12');

      expect(result.totalConcluidas).toBe(0);
      expect(result.reservas).toEqual([]);
      expect(ReservaHistoryService.registrarEvento).not.toHaveBeenCalled();
      expect(mockClient.release).toHaveBeenCalled();
    });

    it('deve ignorar execução se o lock distribuído já foi adquirido por outra instância', async () => {
      mockClient.query.mockResolvedValueOnce({}); // BEGIN
      mockClient.query.mockResolvedValueOnce({ rows: [{ obtido: false }] }); // Lock negado
      mockClient.query.mockResolvedValueOnce({}); // ROLLBACK

      const result = await AutoConclusionJobService.execute('2026-09-12');

      expect(result.totalConcluidas).toBe(0);
      expect(result.reservas).toEqual([]);
      expect(mockClient.release).toHaveBeenCalled();
    });
  });

  describe('CronService Facade', () => {
    it('deve delegar concluirReservasPassadas para o AutoConclusionJobService', async () => {
      mockClient.query.mockResolvedValueOnce({}); // BEGIN
      mockClient.query.mockResolvedValueOnce({ rows: [{ obtido: true }] }); // Lock
      mockClient.query.mockResolvedValueOnce({ rowCount: 0, rows: [] }); // Select
      mockClient.query.mockResolvedValueOnce({}); // COMMIT

      const res = await CronService.concluirReservasPassadas('2026-09-12');
      expect(res.totalConcluidas).toBe(0);
    });
  });

  describe('EscritorioService.getMapa com filtro histórico', () => {
    it('deve buscar status CONCLUIDA para datas passadas', async () => {
      (pool.query as jest.Mock)
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [{ id: 1, nome: 'Sede SP', cidade: 'São Paulo' }]
        })
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [{ id: 10, nome: 'Baia TI' }]
        })
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [
            {
              cadeira_id: 1,
              baia_id: 10,
              identificador: '01',
              posicao_x: 10,
              posicao_y: 10,
              ativa: true,
              status_operacional: 'DISPONIVEL',
              motivo_manutencao: null,
              previsao_retorno: null,
              reserva_id: 99,
              usuario_id: 50,
              checkin_realizado: true,
              checkin_em: new Date(),
              checkout_em: new Date(),
              reserva_status: 'CONCLUIDA',
              ocupante_nome: 'Carlos Silva',
              ocupante_matricula: '1234',
              ocupante_perfil: 'COLABORADOR',
              ocupante_departamento_id: 2,
              ocupante_departamento_nome: 'Tecnologia'
            }
          ]
        });

      const dataPassada = '2020-01-01';
      const mapa = await EscritorioService.getMapa(1, dataPassada, 999);

      expect(mapa).not.toBeNull();
      const cadeira = mapa?.baias[0].cadeiras[0];
      expect(cadeira.status).toBe('ocupada');
      expect(cadeira.ocupante.nome).toBe('Carlos Silva');

      // Verifica se a query recebeu status 'CONCLUIDA'
      const lastQueryCall = (pool.query as jest.Mock).mock.calls[2];
      expect(lastQueryCall[1][2]).toBe('CONCLUIDA');
    });

    it('deve buscar status ATIVA para datas presentes ou futuras', async () => {
      (pool.query as jest.Mock)
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [{ id: 1, nome: 'Sede SP', cidade: 'São Paulo' }]
        })
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [{ id: 10, nome: 'Baia TI' }]
        })
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [
            {
              cadeira_id: 1,
              baia_id: 10,
              identificador: '01',
              posicao_x: 10,
              posicao_y: 10,
              ativa: true,
              status_operacional: 'DISPONIVEL',
              motivo_manutencao: null,
              previsao_retorno: null,
              reserva_id: 105,
              usuario_id: 50,
              checkin_realizado: false,
              checkin_em: null,
              checkout_em: null,
              reserva_status: 'ATIVA',
              ocupante_nome: 'Mariana Costa',
              ocupante_matricula: '5678',
              ocupante_perfil: 'COLABORADOR',
              ocupante_departamento_id: 2,
              ocupante_departamento_nome: 'Tecnologia'
            }
          ]
        });

      const dataFutura = '2099-12-31';
      const mapa = await EscritorioService.getMapa(1, dataFutura, 999);

      expect(mapa).not.toBeNull();
      const cadeira = mapa?.baias[0].cadeiras[0];
      expect(cadeira.status).toBe('ocupada');
      expect(cadeira.ocupante.nome).toBe('Mariana Costa');

      // Verifica se a query recebeu status 'ATIVA'
      const lastQueryCall = (pool.query as jest.Mock).mock.calls[2];
      expect(lastQueryCall[1][2]).toBe('ATIVA');
    });
  });
});

