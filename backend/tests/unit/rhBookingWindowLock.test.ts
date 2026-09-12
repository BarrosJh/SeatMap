import { DateTime } from 'luxon';
import { isProximaSemanaLiberada, getWorkWeekDiff } from '../../src/utils/workWeekUtils';
import { ConfigService } from '../../src/services/configService';
import { ReservaCreateService } from '../../src/services/reservas/reservaCreateService';
import * as dbClient from '../../src/utils/dbClient';

jest.mock('../../src/services/configService');
jest.mock('../../src/services/reservaHistoryService');
jest.mock('../../src/websocket/wsServer', () => ({
  wsManager: {
    broadcastSeatUpdate: jest.fn()
  }
}));

describe('Auditoria de Travamento de Janela de Reserva para Perfil RH / Gestão / TI', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('1. Regras de Abertura da Próxima Semana (isProximaSemanaLiberada)', () => {
    it('deve BLOQUEAR agendamento da próxima semana para ADMIN_RH antes do horário de abertura de Gestão', async () => {
      (ConfigService.getNumber as jest.Mock).mockResolvedValue(5); // Sexta
      (ConfigService.get as jest.Mock).mockResolvedValue('08:00');

      // Quinta-feira 15:00
      const quintaFeira = DateTime.fromISO('2026-09-10T15:00:00', { zone: 'America/Sao_Paulo' });
      const resultado = await isProximaSemanaLiberada('ADMIN_RH', quintaFeira);

      expect(resultado.liberada).toBe(false);
      expect(resultado.mensagemBloqueio).toContain('A agenda da próxima semana para Gestão e Administração abre na Sexta-feira às 08:00');
    });

    it('deve BLOQUEAR agendamento da próxima semana para usuário com permissaoRh = true na Quinta-feira', async () => {
      (ConfigService.getNumber as jest.Mock).mockResolvedValue(5);
      (ConfigService.get as jest.Mock).mockResolvedValue('08:00');

      const quintaFeira = DateTime.fromISO('2026-09-10T11:00:00', { zone: 'America/Sao_Paulo' });
      const resultado = await isProximaSemanaLiberada({
        perfil: 'COLABORADOR',
        permissaoRh: true
      }, quintaFeira);

      expect(resultado.liberada).toBe(false);
      expect(resultado.mensagemBloqueio).toContain('Gestão e Administração');
    });

    it('deve LIBERAR agendamento da próxima semana para ADMIN_RH na Sexta-feira após o horário de abertura', async () => {
      (ConfigService.getNumber as jest.Mock).mockResolvedValue(5);
      (ConfigService.get as jest.Mock).mockResolvedValue('08:00');

      // Sexta-feira 08:30
      const sextaFeira = DateTime.fromISO('2026-09-11T08:30:00', { zone: 'America/Sao_Paulo' });
      const resultado = await isProximaSemanaLiberada('ADMIN_RH', sextaFeira);

      expect(resultado.liberada).toBe(true);
      expect(resultado.mensagemBloqueio).toBeUndefined();
    });

    it('deve LIBERAR agendamento da próxima semana para ADMIN_RH no Sábado e Domingo', async () => {
      (ConfigService.getNumber as jest.Mock).mockResolvedValue(5);
      (ConfigService.get as jest.Mock).mockResolvedValue('08:00');

      const sabado = DateTime.fromISO('2026-09-12T10:00:00', { zone: 'America/Sao_Paulo' });
      const resultadoSabado = await isProximaSemanaLiberada('ADMIN_RH', sabado);
      expect(resultadoSabado.liberada).toBe(true);

      const domingo = DateTime.fromISO('2026-09-13T14:00:00', { zone: 'America/Sao_Paulo' });
      const resultadoDomingo = await isProximaSemanaLiberada('ADMIN_RH', domingo);
      expect(resultadoDomingo.liberada).toBe(true);
    });
  });

  describe('2. Validação no ReservaCreateService', () => {
    it('deve retornar 400 ao tentar reservar datas com mais de 1 semana à frente (>1 diffSemanas)', async () => {
      const hoje = DateTime.now().setZone('America/Sao_Paulo');
      const dataFuturaDistante = hoje.plus({ weeks: 3 }).startOf('week').toISODate()!;

      const result = await ReservaCreateService.criarReserva({
        cadeiraId: 10,
        usuarioId: 1,
        usuarioNome: 'Gestor RH',
        usuarioEmail: 'rh@empresa.com',
        usuarioPerfil: 'ADMIN_RH',
        usuarioPermissaoRh: true,
        dataReserva: dataFuturaDistante
      });

      expect(result.success).toBe(false);
      expect(result.code).toBe(400);
      expect(result.error).toContain('Só é permitido reservar assentos para a semana corrente ou a semana seguinte');
    });

    it('deve retornar 400 ao tentar reservar datas passadas', async () => {
      const dataPassada = '2020-01-15';

      const result = await ReservaCreateService.criarReserva({
        cadeiraId: 10,
        usuarioId: 1,
        usuarioNome: 'Gestor RH',
        usuarioEmail: 'rh@empresa.com',
        usuarioPerfil: 'ADMIN_RH',
        usuarioPermissaoRh: true,
        dataReserva: dataPassada
      });

      expect(result.success).toBe(false);
      expect(result.code).toBe(400);
      expect(result.error).toContain('Não é permitido realizar reservas para datas passadas');
    });

    it('deve retornar 400 ao tentar reservar em finais de semana', async () => {
      // Próximo sábado
      const sabado = DateTime.now().setZone('America/Sao_Paulo').plus({ days: 7 }).startOf('week').plus({ days: 5 }).toISODate()!;

      const result = await ReservaCreateService.criarReserva({
        cadeiraId: 10,
        usuarioId: 1,
        usuarioNome: 'Gestor RH',
        usuarioEmail: 'rh@empresa.com',
        usuarioPerfil: 'ADMIN_RH',
        usuarioPermissaoRh: true,
        dataReserva: sabado
      });

      expect(result.success).toBe(false);
      expect(result.code).toBe(400);
      expect(result.error).toContain('Não há expediente aos finais de semana');
    });
  });
});
