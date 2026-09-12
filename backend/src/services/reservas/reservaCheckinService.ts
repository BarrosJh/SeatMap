import { DateTime } from 'luxon';
import pool from '../../config/db';
import { getDbClient } from '../../utils/dbClient';
import { ConfigService } from '../configService';
import { ReservaHistoryService } from '../reservaHistoryService';
import { wsManager } from '../../websocket/wsServer';
import { normalizeIsoDate } from '../../utils/workWeekUtils';
import { ReservaToleranceUtils } from './reservaToleranceUtils';

export interface CheckinInput {
  reservaId: number;
  usuarioId: number;
  usuarioPerfil: string;
  usuarioDepartamentoId?: number | null;
  isRhGlobal?: boolean;
  cadeiraIdInformada?: number;
  correlationId?: string;
}

export class ReservaCheckinService {
  /**
   * Processa o check-in de presença com validação BOLA, QR Code, e tolerância dinâmica de No-Show
   */
  public static async fazerCheckin(input: CheckinInput) {
    const {
      reservaId,
      usuarioId,
      usuarioPerfil,
      usuarioDepartamentoId,
      isRhGlobal,
      cadeiraIdInformada
    } = input;

    const client = await getDbClient();

    try {
      await client.query('BEGIN');

      const reservaRes = await client.query(`
        SELECT 
          r.id, 
          r.usuario_id, 
          r.data_reserva, 
          r.checkin_realizado, 
          r.checkin_em, 
          r.status, 
          r.codigo_comprovante, 
          r.criado_em,
          r.cadeira_id, 
          c.identificador AS cadeira_identificador, 
          b.id AS baia_id, 
          b.nome AS baia_nome, 
          e.id AS escritorio_id, 
          e.nome AS escritorio_nome, 
          e.cidade AS escritorio_cidade, 
          u.nome AS usuario_nome, 
          u.matricula AS usuario_matricula, 
          u.departamento_id AS departamento_id, 
          d.nome AS departamento_nome
        FROM reservas r
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        JOIN escritorios e ON b.escritorio_id = e.id
        JOIN usuarios u ON r.usuario_id = u.id
        LEFT JOIN departamentos d ON u.departamento_id = d.id
        WHERE r.id = $1
        FOR UPDATE OF r
      `, [reservaId]);

      if (reservaRes.rowCount === 0) {
        await client.query('ROLLBACK');
        return { success: false, code: 404, error: 'Reserva não encontrada.' };
      }

      const reserva = reservaRes.rows[0];

      if (cadeiraIdInformada && cadeiraIdInformada !== reserva.cadeira_id) {
        await client.query('ROLLBACK');
        return {
          success: false,
          code: 400,
          error: `QR Code inválido: este código pertence à mesa ${cadeiraIdInformada}, mas sua reserva é na mesa ${reserva.cadeira_identificador}.`
        };
      }

      const isOwner = reserva.usuario_id === usuarioId;
      const isGestorDoMesmoDepartamento = usuarioPerfil === 'GESTAO' && usuarioDepartamentoId != null && reserva.departamento_id === usuarioDepartamentoId;

      if (!isOwner && !isRhGlobal && !isGestorDoMesmoDepartamento) {
        await client.query('ROLLBACK');
        if (usuarioPerfil === 'GESTAO') {
          return { success: false, code: 403, error: 'Gestores só possuem permissão para realizar check-in de colaboradores do seu próprio departamento.' };
        }
        return { success: false, code: 403, error: 'Você não tem permissão para realizar check-in nesta reserva.' };
      }

      if (reserva.status !== 'ATIVA') {
        await client.query('ROLLBACK');
        return { success: false, code: 400, error: `Não é possível realizar check-in em uma reserva com status ${reserva.status}.` };
      }

      const checkinHoraAtual = new Date().toISOString();
      const dataReservaIso = normalizeIsoDate(reserva.data_reserva);

      if (reserva.checkin_realizado) {
        await client.query('COMMIT');
        return {
          success: true,
          code: 200,
          message: 'Check-in já havia sido realizado anteriormente.',
          comprovante: reserva.codigo_comprovante,
          checkinEm: reserva.checkin_em || checkinHoraAtual,
          reserva: {
            id: reserva.id,
            dataReserva: dataReservaIso,
            cadeiraId: reserva.cadeira_id,
            cadeiraIdentificador: reserva.cadeira_identificador,
            baiaNome: reserva.baia_nome,
            escritorioNome: reserva.escritorio_nome,
            escritorioCidade: reserva.escritorio_cidade,
            usuarioNome: reserva.usuario_nome,
            usuarioMatricula: reserva.usuario_matricula,
            codigoComprovante: reserva.codigo_comprovante,
            checkinEm: reserva.checkin_em || checkinHoraAtual
          }
        };
      }

      const hoje = DateTime.now().setZone('America/Sao_Paulo').startOf('day');
      const dataReservaLuxon = DateTime.fromISO(dataReservaIso, { zone: 'America/Sao_Paulo' }).startOf('day');

      if (!hoje.equals(dataReservaLuxon)) {
        await client.query('ROLLBACK');
        return { success: false, code: 400, error: 'O check-in só pode ser realizado no dia da reserva.' };
      }

      const agora = DateTime.now().setZone('America/Sao_Paulo');
      const [
        horarioInicio,
        horarioCortePadrao,
        horarioInicioTardia,
        toleranciaMinutosStr
      ] = await Promise.all([
        ConfigService.get('HORARIO_INICIO_CHECKIN', '06:00'),
        ConfigService.get('HORARIO_LIMITE_CHECKIN', '11:00'),
        ConfigService.get('HORARIO_INICIO_RESERVA_TARDIA', '10:00'),
        ConfigService.get('TOLERANCIA_CHECKIN_RESERVA_TARDIA_MINUTOS', '120')
      ]);
      const toleranciaMinutos = parseInt(toleranciaMinutosStr, 10) || 120;

      const [horaInicioH, horaInicioM] = horarioInicio.split(':').map(Number);
      const inicioCheckinHoje = agora.set({ hour: horaInicioH, minute: horaInicioM, second: 0, millisecond: 0 });

      if (agora < inicioCheckinHoje) {
        await client.query('ROLLBACK');
        return { success: false, code: 400, error: `O check-in diário só está liberado a partir das ${horarioInicio}.` };
      }

      // Calcula o limite individual considerando reservas tardias do mesmo dia
      const calculoLimite = ReservaToleranceUtils.calcularLimiteCheckin(
        dataReservaIso,
        reserva.criado_em,
        {
          horarioCortePadrao,
          horarioInicioTardia,
          toleranciaMinutos
        },
        agora
      );

      if (calculoLimite.isExpirada) {
        // Auto-expirar como No-Show e liberar assento no mapa de forma atômica
        const updateNoShowRes = await client.query(`
          UPDATE reservas
          SET status = 'EXPIRADA_NOSHOW'
          WHERE id = $1 AND status = 'ATIVA' AND checkin_realizado = false
        `, [reservaId]);

        if (updateNoShowRes.rowCount && updateNoShowRes.rowCount > 0) {
          await ReservaHistoryService.registrarEvento({
            reservaId: reserva.id,
            cadeiraId: reserva.cadeira_id,
            usuarioId: reserva.usuario_id,
            dataReserva: dataReservaIso,
            tipoEvento: 'EXPIRADA_NOSHOW',
            executadoPorUsuarioId: usuarioId,
            motivo: `Tentativa de check-in após o horário limite das ${calculoLimite.limiteFormatado}. Reserva expirada por No-Show e assento liberado.`,
            detalhes: {
              cadeiraIdentificador: reserva.cadeira_identificador,
              horarioLimite: calculoLimite.limiteFormatado,
              isReservaTardia: calculoLimite.isReservaTardia
            }
          }, client);
        }

        await client.query('COMMIT');

        if (updateNoShowRes.rowCount && updateNoShowRes.rowCount > 0) {
          wsManager.broadcastSeatUpdate({
            evento: 'assento_atualizado',
            escritorioId: reserva.escritorio_id,
            cadeiraId: reserva.cadeira_id,
            data: dataReservaIso,
            status: 'livre',
            ocupante: null
          });
        }

        return {
          success: false,
          code: 400,
          error: `O horário limite para check-in encerrou às ${calculoLimite.limiteFormatado}. Sua reserva foi cancelada por No-Show e a mesa foi liberada.`
        };
      }

      const updateRes = await client.query(`
        UPDATE reservas 
        SET checkin_realizado = true, checkin_em = $1 
        WHERE id = $2 AND status = 'ATIVA' AND checkin_realizado = false
      `, [checkinHoraAtual, reservaId]);

      if (updateRes.rowCount === 0) {
        await client.query('ROLLBACK');
        return { success: false, code: 400, error: 'A reserva não está mais ativa para confirmação de presença.' };
      }

      await ReservaHistoryService.registrarEvento({
        reservaId: reserva.id,
        cadeiraId: reserva.cadeira_id,
        usuarioId,
        dataReserva: dataReservaIso,
        tipoEvento: 'CHECKIN',
        executadoPorUsuarioId: usuarioId,
        motivo: usuarioId === reserva.usuario_id ? 'Check-in de presença realizado pelo colaborador' : 'Check-in administrativo validado pela Gestão/RH',
        detalhes: {
          checkinEm: checkinHoraAtual,
          comprovante: reserva.codigo_comprovante
        }
      }, client);

      await client.query('COMMIT');

      // Emissão do WebSocket estritamente pós-commit
      wsManager.broadcastSeatUpdate({
        evento: 'assento_atualizado',
        escritorioId: reserva.escritorio_id,
        cadeiraId: reserva.cadeira_id,
        data: dataReservaIso,
        status: 'ocupada',
        ocupante: {
          usuarioId: reserva.usuario_id,
          nome: reserva.usuario_nome,
          departamento: reserva.departamento_nome || 'Sem Departamento'
        }
      });

      return {
        success: true,
        code: 200,
        message: 'Presença confirmada com sucesso! Bom trabalho.',
        comprovante: reserva.codigo_comprovante,
        checkinEm: checkinHoraAtual,
        reserva: {
          id: reserva.id,
          dataReserva: dataReservaIso,
          cadeiraId: reserva.cadeira_id,
          cadeiraIdentificador: reserva.cadeira_identificador,
          baiaNome: reserva.baia_nome,
          escritorioNome: reserva.escritorio_nome,
          escritorioCidade: reserva.escritorio_cidade,
          usuarioNome: reserva.usuario_nome,
          usuarioMatricula: reserva.usuario_matricula,
          codigoComprovante: reserva.codigo_comprovante,
          checkinEm: checkinHoraAtual
        }
      };
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {}
      throw error;
    } finally {
      client.release();
    }
  }
}
