import { DateTime } from 'luxon';
import { ReservaToleranceUtils } from '../../src/services/reservas/reservaToleranceUtils';
import { ReservaService } from '../../src/services/reservaService';

describe('Regra de Tolerância de No-Show para Reservas Tardias do Mesmo Dia', () => {
  const params = {
    horarioCortePadrao: '11:00',
    horarioInicioTardia: '10:00',
    toleranciaMinutos: 120 // 2 horas
  };

  const hojeIso = '2026-09-07';

  it('1. Reserva feita antecipadamente (ou antes das 10h00) deve manter o horário de corte fixo às 11h00', () => {
    const criadoEm = '2026-09-07T08:30:00-03:00';

    // Às 10:55, ainda dentro do prazo
    const agoraAntes = DateTime.fromISO('2026-09-07T10:55:00-03:00', { zone: 'America/Sao_Paulo' });
    const resAntes = ReservaToleranceUtils.calcularLimiteCheckin(hojeIso, criadoEm, params, agoraAntes);

    expect(resAntes.limiteFormatado).toBe('11:00');
    expect(resAntes.isReservaTardia).toBe(false);
    expect(resAntes.isExpirada).toBe(false);

    // Às 11:01, expirada por No-Show
    const agoraDepois = DateTime.fromISO('2026-09-07T11:01:00-03:00', { zone: 'America/Sao_Paulo' });
    const resDepois = ReservaToleranceUtils.calcularLimiteCheckin(hojeIso, criadoEm, params, agoraDepois);

    expect(resDepois.limiteFormatado).toBe('11:00');
    expect(resDepois.isExpirada).toBe(true);
  });

  it('2. Reserva feita às 10h30 para o mesmo dia deve receber 120 min de tolerância (limite até 12h30)', () => {
    const criadoEm = '2026-09-07T10:30:00-03:00';

    // Às 11:15 (após as 11h00 normais), NÃO deve estar expirada
    const agora1115 = DateTime.fromISO('2026-09-07T11:15:00-03:00', { zone: 'America/Sao_Paulo' });
    const res1115 = ReservaToleranceUtils.calcularLimiteCheckin(hojeIso, criadoEm, params, agora1115);

    expect(res1115.isReservaTardia).toBe(true);
    expect(res1115.limiteFormatado).toBe('12:30');
    expect(res1115.isExpirada).toBe(false);

    // Às 12h29, ainda válida
    const agora1229 = DateTime.fromISO('2026-09-07T12:29:00-03:00', { zone: 'America/Sao_Paulo' });
    const res1229 = ReservaToleranceUtils.calcularLimiteCheckin(hojeIso, criadoEm, params, agora1229);
    expect(res1229.isExpirada).toBe(false);

    // Às 12h31, expirada por tolerância de No-Show
    const agora1231 = DateTime.fromISO('2026-09-07T12:31:00-03:00', { zone: 'America/Sao_Paulo' });
    const res1231 = ReservaToleranceUtils.calcularLimiteCheckin(hojeIso, criadoEm, params, agora1231);
    expect(res1231.isExpirada).toBe(true);
  });

  it('3. Reserva realizada à tarde às 14h00 deve permitir check-in até 16h00', () => {
    const criadoEm = '2026-09-07T14:00:00-03:00';

    const agora1530 = DateTime.fromISO('2026-09-07T15:30:00-03:00', { zone: 'America/Sao_Paulo' });
    const res1530 = ReservaToleranceUtils.calcularLimiteCheckin(hojeIso, criadoEm, params, agora1530);

    expect(res1530.isReservaTardia).toBe(true);
    expect(res1530.limiteFormatado).toBe('16:00');
    expect(res1530.isExpirada).toBe(false);

    const agora1605 = DateTime.fromISO('2026-09-07T16:05:00-03:00', { zone: 'America/Sao_Paulo' });
    const res1605 = ReservaToleranceUtils.calcularLimiteCheckin(hojeIso, criadoEm, params, agora1605);
    expect(res1605.isExpirada).toBe(true);
  });

  it('4. Reserva de dia anterior deve ser marcada como expirada imediatamente', () => {
    const dataPassada = '2026-09-06';
    const criadoEm = '2026-09-05T15:00:00-03:00';
    const agoraHoje = DateTime.fromISO('2026-09-07T09:00:00-03:00', { zone: 'America/Sao_Paulo' });

    const res = ReservaToleranceUtils.calcularLimiteCheckin(dataPassada, criadoEm, params, agoraHoje);
    expect(res.isExpirada).toBe(true);
  });

  it('5. Fachada ReservaService deve exportar e expor todos os métodos delegados corretamente', () => {
    expect(typeof ReservaService.criarReserva).toBe('function');
    expect(typeof ReservaService.fazerCheckin).toBe('function');
    expect(typeof ReservaService.cancelarReserva).toBe('function');
    expect(typeof ReservaService.minhasReservas).toBe('function');
    expect(typeof ReservaService.enviarComprovanteEmail).toBe('function');
  });
});
