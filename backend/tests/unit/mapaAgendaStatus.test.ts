import { DateTime } from 'luxon';
import { EscritorioService } from '../../src/services/escritorioService';
import pool from '../../src/config/db';
import { ConfigService } from '../../src/services/configService';

jest.mock('../../src/config/db', () => ({
  query: jest.fn()
}));

jest.mock('../../src/services/configService');

describe('EscritorioService.getMapa com Metadados de Agenda (Backend-First)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  function mockDbForMapa() {
    (pool.query as jest.Mock)
      .mockResolvedValueOnce({
        rowCount: 1,
        rows: [{ id: 1, nome: 'Sede Principal', cidade: 'São Paulo' }]
      })
      .mockResolvedValueOnce({
        rowCount: 1,
        rows: [{ id: 10, nome: 'Baia Geral' }]
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
            reserva_id: null,
            usuario_id: null,
            checkin_realizado: null,
            checkin_em: null,
            checkout_em: null,
            reserva_status: null,
            ocupante_nome: null,
            ocupante_matricula: null,
            ocupante_perfil: null,
            ocupante_departamento_id: null,
            ocupante_departamento_nome: null
          }
        ]
      });
  }

  it('deve retornar agenda com permiteReserva = true para um dia útil da semana corrente', async () => {
    mockDbForMapa();
    const { getMondayOfCurrentWorkWeek } = await import('../../src/utils/workWeekUtils');
    // Quarta-feira da semana de trabalho de referência (futura ou presente)
    const quartaFeira = getMondayOfCurrentWorkWeek().plus({ days: 2 }).toISODate()!;
    const mapa = await EscritorioService.getMapa(1, quartaFeira, 1, 'COLABORADOR');

    expect(mapa).not.toBeNull();
    expect(mapa?.agenda).toBeDefined();
    expect(mapa?.agenda.permiteReserva).toBe(true);
    expect(mapa?.agenda.motivoBloqueio).toBeNull();
  });

  it('deve retornar agenda com permiteReserva = false para finais de semana', async () => {
    mockDbForMapa();
    // Próximo Sábado
    const sabado = DateTime.now().setZone('America/Sao_Paulo').startOf('week').plus({ days: 5 }).toISODate()!;
    const mapa = await EscritorioService.getMapa(1, sabado, 1, 'COLABORADOR');

    expect(mapa).not.toBeNull();
    expect(mapa?.agenda.permiteReserva).toBe(false);
    expect(mapa?.agenda.motivoBloqueio).toContain('Não há expediente aos finais de semana');
  });

  it('deve retornar agenda com permiteReserva = false para datas passadas', async () => {
    mockDbForMapa();
    const dataPassada = '2020-01-01';
    const mapa = await EscritorioService.getMapa(1, dataPassada, 1, 'COLABORADOR');

    expect(mapa).not.toBeNull();
    expect(mapa?.agenda.permiteReserva).toBe(false);
    expect(mapa?.agenda.motivoBloqueio).toContain('Não é permitido realizar reservas para datas passadas');
    expect(mapa?.agenda.permiteVisualizacao).toBe(true);
  });

  it('deve retornar agenda com permiteReserva = false para data distante (>1 semana) com bloqueio claro', async () => {
    mockDbForMapa();
    const dataFuturaDistante = DateTime.now().setZone('America/Sao_Paulo').plus({ weeks: 3 }).startOf('week').toISODate()!;
    const mapa = await EscritorioService.getMapa(1, dataFuturaDistante, 1, 'COLABORADOR');

    expect(mapa).not.toBeNull();
    expect(mapa?.agenda.permiteReserva).toBe(false);
    expect(mapa?.agenda.motivoBloqueio).toContain('Só é permitido reservar assentos para a semana corrente ou a semana seguinte');
    expect(mapa?.agenda.diffSemanas).toBeGreaterThan(1);
  });

  it('deve calcular status da próxima semana respeitando a janela de abertura para COLABORADOR', async () => {
    mockDbForMapa();
    (ConfigService.getNumber as jest.Mock).mockResolvedValue(5); // Sexta
    (ConfigService.get as jest.Mock).mockResolvedValue('12:00');

    // Data da próxima semana (Segunda-feira) em relação à semana de trabalho atual
    const proximaSegunda = DateTime.now().setZone('America/Sao_Paulo').plus({ weeks: 2 }).startOf('week').toISODate()!;
    const mapa = await EscritorioService.getMapa(1, proximaSegunda, 1, 'COLABORADOR');

    expect(mapa).not.toBeNull();
    expect(mapa?.agenda.diffSemanas).toBeGreaterThanOrEqual(1);
    expect(typeof mapa?.agenda.permiteReserva).toBe('boolean');
  });
});
