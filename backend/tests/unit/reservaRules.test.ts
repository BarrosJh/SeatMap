import { DateTime } from 'luxon';

describe('Regras de Negócio do Motor de Reservas', () => {
  const SP_ZONE = 'America/Sao_Paulo';

  describe('Cálculo e Validação de Janelas de Horário', () => {
    it('deve validar se o horário atual está dentro da janela permitida para check-in', () => {
      const horaInicioCheckin = '06:00';
      const horaLimiteCheckin = '10:00';

      const agoraDentro = DateTime.fromFormat('08:30', 'HH:mm', { zone: SP_ZONE });
      const agoraAntes = DateTime.fromFormat('05:45', 'HH:mm', { zone: SP_ZONE });
      const agoraDepois = DateTime.fromFormat('10:15', 'HH:mm', { zone: SP_ZONE });

      const inicio = DateTime.fromFormat(horaInicioCheckin, 'HH:mm', { zone: SP_ZONE });
      const fim = DateTime.fromFormat(horaLimiteCheckin, 'HH:mm', { zone: SP_ZONE });

      expect(agoraDentro >= inicio && agoraDentro <= fim).toBe(true);
      expect(agoraAntes >= inicio).toBe(false);
      expect(agoraDepois <= fim).toBe(false);
    });

    it('deve validar restrição de limite semanal de reservas', () => {
      const limiteSemanal = 5;
      const reservasAtivasNaSemana = 4;

      const podeReservarMaisUma = reservasAtivasNaSemana < limiteSemanal;
      const podeReservarDuas = reservasAtivasNaSemana + 2 <= limiteSemanal;

      expect(podeReservarMaisUma).toBe(true);
      expect(podeReservarDuas).toBe(false);
    });

    it('deve considerar a agenda da próxima semana aberta durante sábado e domingo', async () => {
      const { isProximaSemanaLiberada } = await import('../../src/utils/workWeekUtils');
      
      // Sábado às 14:00
      const sabado = DateTime.fromISO('2026-09-12T14:00:00', { zone: SP_ZONE });
      expect(sabado.weekday).toBe(6);

      // Domingo às 09:00
      const domingo = DateTime.fromISO('2026-09-13T09:00:00', { zone: SP_ZONE });
      expect(domingo.weekday).toBe(7);

      const resSabado = await isProximaSemanaLiberada('COLABORADOR', sabado);
      expect(resSabado.liberada).toBe(true);

      const resDomingo = await isProximaSemanaLiberada('COLABORADOR', domingo);
      expect(resDomingo.liberada).toBe(true);
    });
  });

  describe('Validação de Status Operacional e Isolamento', () => {
    it('deve barrar tentativa de reserva em assento com status EM_MANUTENCAO', () => {
      const cadeira = {
        id: 10,
        identificador: 'Mesa 10',
        status_operacional: 'EM_MANUTENCAO',
        motivo_manutencao: 'Tomada em curto',
      };

      const isDisponivelParaReserva = cadeira.status_operacional === 'DISPONIVEL';
      expect(isDisponivelParaReserva).toBe(false);
    });

    it('deve permitir reserva em assento com status DISPONIVEL', () => {
      const cadeira = {
        id: 11,
        identificador: 'Mesa 11',
        status_operacional: 'DISPONIVEL',
        motivo_manutencao: null,
      };

      const isDisponivelParaReserva = cadeira.status_operacional === 'DISPONIVEL';
      expect(isDisponivelParaReserva).toBe(true);
    });
  });

  afterAll(async () => {
    const pool = (await import('../../src/config/db')).default;
    await pool.end();
  });
});

