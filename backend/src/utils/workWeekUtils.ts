import { DateTime } from 'luxon';
import { ConfigService } from '../services/configService';

/**
 * Retorna a Segunda-feira que representa o início da semana útil de trabalho de referência.
 * 
 * Regra corporativa:
 * - Se hoje for Sábado (6) ou Domingo (7), a semana anterior já encerrou e a semana útil vigente 
 *   é a que se inicia imediatamente na próxima Segunda-feira.
 * - Se hoje for Segunda (1) a Sexta (5), a semana útil vigente é a Segunda-feira desta semana.
 */
export function getMondayOfCurrentWorkWeek(date: DateTime = DateTime.now().setZone('America/Sao_Paulo')): DateTime {
  const dt = date.setZone('America/Sao_Paulo').startOf('day');
  if (dt.weekday === 6) {
    // Sábado -> Segunda-feira (+2 dias)
    return dt.plus({ days: 2 });
  } else if (dt.weekday === 7) {
    // Domingo -> Segunda-feira (+1 dia)
    return dt.plus({ days: 1 });
  } else {
    // Segunda a Sexta -> startOf('week') é a Segunda-feira
    return dt.startOf('week');
  }
}

/**
 * Calcula a diferença em semanas úteis entre uma data alvo e a semana útil corrente.
 * - 0: Mesma semana de trabalho (Semana Vigente / Esta Semana)
 * - 1: Próxima semana de trabalho (Próxima Semana)
 * - > 1: Semanas futuras adicionais
 * - < 0: Semanas passadas
 */
export function getWorkWeekDiff(targetDate: DateTime, baseDate: DateTime = DateTime.now().setZone('America/Sao_Paulo')): number {
  const currentMonday = getMondayOfCurrentWorkWeek(baseDate);
  const targetMonday = targetDate.setZone('America/Sao_Paulo').startOf('week');
  return Math.round(targetMonday.diff(currentMonday, 'weeks').weeks);
}

/**
 * Verifica se a agenda da Próxima Semana já foi liberada para o perfil do usuário
 * de acordo com as parametrizações do RH no banco de dados.
 */
export async function isProximaSemanaLiberada(
  perfil: string,
  now: DateTime = DateTime.now().setZone('America/Sao_Paulo')
): Promise<{ liberada: boolean; mensagemBloqueio?: string }> {
  // Administradores do RH sempre têm acesso total para planejar
  if (perfil === 'ADMIN_RH') {
    return { liberada: true };
  }

  const diaSemanaHoje = now.weekday; // 1 = Seg, 5 = Sex, 6 = Sáb, 7 = Dom
  const horaAtual = now.toFormat('HH:mm');

  // Nomes dos dias úteis para formatação da mensagem
  const diasNomes: Record<number, string> = {
    1: 'Segunda-feira',
    2: 'Terça-feira',
    3: 'Quarta-feira',
    4: 'Quinta-feira',
    5: 'Sexta-feira'
  };

  if (perfil === 'GESTAO') {
    const diaAberturaGestao = await ConfigService.getNumber('DIA_ABERTURA_GESTAO', 5);
    const horarioAberturaGestao = await ConfigService.get('HORARIO_ABERTURA_GESTAO', '08:00');

    // Finais de semana (Sáb/Dom) ou após o dia/horário de abertura durante a semana
    const isAberto = (diaSemanaHoje >= 6) || (
      (diaSemanaHoje > diaAberturaGestao) ||
      (diaSemanaHoje === diaAberturaGestao && horaAtual >= horarioAberturaGestao)
    );

    if (!isAberto) {
      const nomeDia = diasNomes[diaAberturaGestao] || 'Sexta-feira';
      return {
        liberada: false,
        mensagemBloqueio: `A agenda da próxima semana para Gestão abre na ${nomeDia} às ${horarioAberturaGestao}.`
      };
    }
  } else {
    // Perfil COLABORADOR (e outros)
    const diaAberturaColab = await ConfigService.getNumber('DIA_ABERTURA_COLABORADOR', 5);
    const horarioAberturaColab = await ConfigService.get('HORARIO_ABERTURA_COLABORADOR', '12:00');

    // Finais de semana (Sáb/Dom) ou após o dia/horário de abertura durante a semana
    const isAberto = (diaSemanaHoje >= 6) || (
      (diaSemanaHoje > diaAberturaColab) ||
      (diaSemanaHoje === diaAberturaColab && horaAtual >= horarioAberturaColab)
    );

    if (!isAberto) {
      const nomeDia = diasNomes[diaAberturaColab] || 'Sexta-feira';
      return {
        liberada: false,
        mensagemBloqueio: `A agenda da próxima semana abre na ${nomeDia} às ${horarioAberturaColab}.`
      };
    }
  }

  return { liberada: true };
}
