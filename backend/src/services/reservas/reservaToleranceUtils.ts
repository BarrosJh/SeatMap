import { DateTime } from 'luxon';
import { normalizeIsoDate } from '../../utils/workWeekUtils';

export interface ParametrosToleranciaNoShow {
  horarioCortePadrao: string; // Ex: '11:00'
  horarioInicioTardia: string; // Ex: '10:00'
  toleranciaMinutos: number; // Ex: 120
}

export interface CalculoLimiteCheckinResult {
  limiteCheckin: DateTime;
  limiteFormatado: string; // Ex: '11:00' ou '12:30'
  isReservaTardia: boolean;
  isExpirada: boolean;
}

export class ReservaToleranceUtils {
  /**
   * Calcula o limite exato de check-in para uma reserva com base na data da reserva,
   * no momento de criação (criado_em) e nas regras de tolerância para reservas tardias do mesmo dia.
   */
  public static calcularLimiteCheckin(
    dataReserva: string | Date,
    criadoEm: string | Date | undefined,
    params: ParametrosToleranciaNoShow,
    agora: DateTime = DateTime.now().setZone('America/Sao_Paulo')
  ): CalculoLimiteCheckinResult {
    const dataReservaIso = normalizeIsoDate(dataReserva);
    const dataReservaLuxon = DateTime.fromISO(dataReservaIso, { zone: 'America/Sao_Paulo' }).startOf('day');
    const hojeLuxon = agora.startOf('day');

    // Parse dos parâmetros
    const [corteH, corteM] = params.horarioCortePadrao.split(':').map(Number);
    const [tardiaH, tardiaM] = params.horarioInicioTardia.split(':').map(Number);

    // Limite padrão do dia da reserva no horário configurado.
    const limitePadrao = dataReservaLuxon.set({ hour: corteH, minute: corteM, second: 0, millisecond: 0 });

    // Se for de dia anterior, já expirou no limite padrão daquele dia
    if (dataReservaLuxon < hojeLuxon) {
      return {
        limiteCheckin: limitePadrao,
        limiteFormatado: limitePadrao.toFormat('HH:mm'),
        isReservaTardia: false,
        isExpirada: true
      };
    }

    // Se a reserva for para data futura, o limite ainda é o horário padrão daquele dia futuro
    if (dataReservaLuxon > hojeLuxon) {
      return {
        limiteCheckin: limitePadrao,
        limiteFormatado: limitePadrao.toFormat('HH:mm'),
        isReservaTardia: false,
        isExpirada: false
      };
    }

    // A reserva é para HOJE (dataReserva == hoje)
    let criadoEmLuxon: DateTime;
    if (criadoEm) {
      if (typeof criadoEm === 'string') {
        const rawStr = criadoEm.trim();
        // Se a string contiver fuso ou Z (ex: 2026-09-11T17:30:00.000Z), faz parse e converte para Sao_Paulo
        if (rawStr.endsWith('Z') || /[+-]\d{2}(:?\d{2})?$/.test(rawStr)) {
          criadoEmLuxon = DateTime.fromISO(rawStr).setZone('America/Sao_Paulo');
        } else {
          // Se for sem timezone (timestamp SQL local como '2026-09-11 14:30:00')
          const isoCandidate = rawStr.includes(' ') ? rawStr.replace(' ', 'T') : rawStr;
          criadoEmLuxon = DateTime.fromISO(isoCandidate, { zone: 'America/Sao_Paulo' });
          if (!criadoEmLuxon.isValid) {
            criadoEmLuxon = DateTime.fromSQL(rawStr, { zone: 'America/Sao_Paulo' });
          }
        }
      } else if (criadoEm instanceof Date) {
        criadoEmLuxon = DateTime.fromJSDate(criadoEm).setZone('America/Sao_Paulo');
      } else {
        criadoEmLuxon = agora;
      }
      if (!criadoEmLuxon.isValid) {
        criadoEmLuxon = agora;
      }
    } else {
      criadoEmLuxon = agora;
    }

    // Ponto de corte para considerar reserva tardia (ex: hoje às 10:00)
    const pontoInicioTardia = dataReservaLuxon.set({ hour: tardiaH, minute: tardiaM, second: 0, millisecond: 0 });

    // Uma reserva é 'Tardia do Mesmo Dia' se:
    // 1. Foi criada hoje (mesmo dia da reserva)
    // 2. O momento de criação >= pontoInicioTardia (ex: >= 10:00)
    const criadaHoje = criadoEmLuxon.startOf('day').equals(hojeLuxon);
    const isReservaTardia = criadaHoje && criadoEmLuxon >= pontoInicioTardia;

    if (isReservaTardia) {
      // Limite estendido = momento da criação + tolerância em minutos
      const limiteEstendido = criadoEmLuxon.plus({ minutes: params.toleranciaMinutos });
      
      // O limite nunca deve ser menor que o limite padrão nem ultrapassar o dia da reserva.
      const fimDoDia = dataReservaLuxon.endOf('day');
      const limiteComTolerancia = limiteEstendido > limitePadrao ? limiteEstendido : limitePadrao;
      const limiteFinal = limiteComTolerancia > fimDoDia ? fimDoDia : limiteComTolerancia;

      return {
        limiteCheckin: limiteFinal,
        limiteFormatado: limiteFinal.toFormat('HH:mm'),
        isReservaTardia: true,
        isExpirada: agora > limiteFinal
      };
    }

    // Reserva normal do mesmo dia criada antes das 10:00
    return {
      limiteCheckin: limitePadrao,
      limiteFormatado: limitePadrao.toFormat('HH:mm'),
      isReservaTardia: false,
      isExpirada: agora > limitePadrao
    };
  }
}
