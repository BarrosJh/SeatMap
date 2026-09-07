import { Response } from 'express';
import { DateTime } from 'luxon';
import crypto from 'crypto';
import pool from '../config/db';
import { AuthenticatedRequest } from '../middleware/auth';
import { ConfigService } from '../services/configService';
import { EmailService } from '../services/emailService';
import { ReservaHistoryService } from '../services/reservaHistoryService';
import { wsManager } from '../websocket/wsServer';
import { getWorkWeekDiff, isProximaSemanaLiberada } from '../utils/workWeekUtils';


// Interface do Evento de Mensageria (ex: RabbitMQ / Kafka / BullMQ / Outbox)
interface ReservaCriadaEvent {
  evento: 'RESERVA_CRIADA' | 'RESERVA_TROCADA';
  reservaId: number;
  codigoComprovante: string;
  usuarioId: number;
  usuarioEmail: string;
  usuarioNome: string;
  cadeiraId: number;
  cadeiraIdentificador: string;
  escritorioId: number;
  dataReserva: string;
  checkinAutomatico: boolean;
  criadoEm: string;
}

// Publicador assíncrono para fila/broker de eventos desacoplado
function dispatchAsyncEvent(eventPayload: ReservaCriadaEvent): void {
  setImmediate(async () => {
    try {
      // Ponto de extensão para RabbitMQ / Kafka / SQS / BullMQ / Webhook
      console.log(`[EventBroker] Evento emitido com sucesso: [${eventPayload.evento}] Comprovante: ${eventPayload.codigoComprovante}`);
    } catch (err) {
      console.error(`[EventBroker Error] Falha ao processar evento de reserva ${eventPayload.codigoComprovante}:`, err);
    }
  });
}

export class ReservaController {
  public static async criarReserva(req: AuthenticatedRequest, res: Response) {
    const user = req.user!;
    const { cadeiraId, dataReserva } = req.body;
    const idempotencyKey = req.headers['x-idempotency-key'] as string | undefined;

    const numericCadeiraId = parseInt(String(cadeiraId), 10);

    if (!cadeiraId || isNaN(numericCadeiraId) || numericCadeiraId <= 0 || !dataReserva) {
      return res.status(400).json({ error: 'Cadeira e data de reserva são obrigatórios.' });
    }

    const dataLuxon = DateTime.fromISO(dataReserva, { zone: 'America/Sao_Paulo' });
    if (!dataLuxon.isValid) {
      return res.status(400).json({ error: 'Data de reserva inválida. Utilize o formato YYYY-MM-DD.' });
    }

    const hoje = DateTime.now().setZone('America/Sao_Paulo').startOf('day');
    const dataAlvo = dataLuxon.startOf('day');
    const dataAlvoIso = dataAlvo.toISODate()!;

    if (dataAlvo < hoje) {
      return res.status(400).json({ error: 'Não é permitido realizar reservas para datas passadas.' });
    }

    // Bloqueio definitivo de finais de semana (Sábado = 6, Domingo = 7 - sem expediente)
    if (dataLuxon.weekday === 6 || dataLuxon.weekday === 7) {
      return res.status(400).json({ error: 'Não há expediente aos finais de semana. Selecione um dia útil (Segunda a Sexta).' });
    }

    // Validação do ciclo de abertura (Semana útil vigente vs Próxima semana)
    const diffSemanas = getWorkWeekDiff(dataAlvo, hoje);

    if (diffSemanas > 1) {
      return res.status(400).json({ error: 'Só é permitido reservar assentos para a semana corrente ou a semana seguinte.' });
    }

    // Se a reserva for para a próxima semana, validar regras de abertura por perfil
    if (diffSemanas === 1) {
      const statusAbertura = await isProximaSemanaLiberada(user.perfil, DateTime.now().setZone('America/Sao_Paulo'));
      if (!statusAbertura.liberada) {
        return res.status(403).json({
          error: statusAbertura.mensagemBloqueio || 'A agenda da próxima semana ainda não foi aberta.'
        });
      }
    }

    // Obter limite semanal de reservas antes de abrir transação
    const limiteAtivas = await ConfigService.getNumber('LIMITE_SEMANAL_RESERVAS', 2);

    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      // Bloqueia a linha da cadeira para evitar reservas concorrentes
      const cadeiraRes = await client.query(`
        SELECT c.id, c.identificador, c.ativa, c.status_operacional, c.motivo_manutencao, c.previsao_retorno, b.id AS baia_id, b.nome AS baia_nome, b.escritorio_id
        FROM cadeiras c
        JOIN baias b ON c.baia_id = b.id
        WHERE c.id = $1 AND c.ativa = true
        FOR UPDATE
      `, [cadeiraId]);

      if (cadeiraRes.rowCount === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Cadeira selecionada não existe ou está inativa.' });
      }
      const cadeira = cadeiraRes.rows[0];

      // Bloqueio de assento em manutenção operacional
      if (cadeira.status_operacional === 'EM_MANUTENCAO') {
        await client.query('ROLLBACK');
        const prevMsg = cadeira.previsao_retorno 
          ? ` Previsão de liberação: ${DateTime.fromJSDate(new Date(cadeira.previsao_retorno)).setZone('America/Sao_Paulo').toFormat('dd/MM/yyyy HH:mm')}.` 
          : '';
        return res.status(400).json({
          error: `Este assento está temporariamente indisponível para manutenção (${cadeira.motivo_manutencao || 'Defeito técnico'}).${prevMsg}`
        });
      }

      // 2. Verificar se a cadeira já está reservada por outro colaborador para a data
      const cadeiraOcupadaRes = await client.query(`
        SELECT id, usuario_id FROM reservas
        WHERE cadeira_id = $1 AND data_reserva = $2 AND status = 'ATIVA'
      `, [cadeiraId, dataAlvoIso]);

      if (cadeiraOcupadaRes.rowCount! > 0 && cadeiraOcupadaRes.rows[0].usuario_id !== user.userId) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'Este assento acabou de ser reservado por outro colaborador.' });
      }

      // 3. Verificar se o próprio usuário já tem reserva ATIVA nesta mesma data (para troca atômica)
      const reservaExistenteDiaRes = await client.query(`
        SELECT r.id, r.cadeira_id, b.escritorio_id, c.identificador
        FROM reservas r
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        WHERE r.usuario_id = $1 AND r.data_reserva = $2 AND r.status = 'ATIVA'
        FOR UPDATE
      `, [user.userId, dataAlvoIso]);

      const isTroca = reservaExistenteDiaRes.rowCount! > 0;
      const reservaAntiga = isTroca ? reservaExistenteDiaRes.rows[0] : null;

      // Se for troca para a mesmíssima cadeira (Idempotência natural)
      if (isTroca && reservaAntiga.cadeira_id === cadeiraId) {
        await client.query('COMMIT');
        return res.status(200).json({
          message: 'Você já possui este assento reservado.',
          reservaId: reservaAntiga.id
        });
      }

      // Se for troca, verificar se a política do RH permite trocas no mesmo dia
      if (isTroca) {
        const permitirTroca = (await ConfigService.get('PERMITIR_TROCA_MESMO_DIA', 'true')) === 'true';
        if (!permitirTroca) {
          await client.query('ROLLBACK');
          return res.status(400).json({ error: 'A troca de assento no mesmo dia está desabilitada pela política de RH.' });
        }
      }

      // 4. Validar limite de cotas de reservas ativas se não for troca no mesmo dia
      if (!isTroca) {
        const contagemAtivasRes = await client.query(`
          SELECT COUNT(*) AS total
          FROM reservas
          WHERE usuario_id = $1
            AND status = 'ATIVA'
            AND data_reserva >= CURRENT_DATE
        `, [user.userId]);

        const totalAtivas = parseInt(contagemAtivasRes.rows[0].total, 10);
        if (totalAtivas >= limiteAtivas) {
          await client.query('ROLLBACK');
          return res.status(400).json({
            error: `Limite de ${limiteAtivas} reservas ativas atingido.`
          });
        }
      }

      // Geração de comprovante único da reserva
      const timestampIso = new Date().toISOString();
      const rawPayload = `${user.userId}-${cadeiraId}-${dataAlvoIso}-${timestampIso}-${idempotencyKey || ''}`;
      const codigoComprovante = 'RES-' + crypto.createHash('sha256').update(rawPayload).digest('hex').substring(0, 16).toUpperCase();

      // Check-in automático para perfil de gestão se configurado
      const checkinAutoGestao = (await ConfigService.get('CHECKIN_AUTOMATICO_GESTAO', 'true')) === 'true';
      const isGestao = user.perfil === 'GESTAO';
      const checkinRealizado = isGestao && checkinAutoGestao;
      const checkinEm = checkinRealizado ? new Date() : null;

      // Executa inserção ou troca atômica
      let novaReserva: any;
      if (isTroca && reservaAntiga) {
        const updateRes = await client.query(`
          UPDATE reservas
          SET cadeira_id = $1, checkin_realizado = $2, checkin_em = $3, status = 'ATIVA', codigo_comprovante = $4
          WHERE id = $5
          RETURNING id, cadeira_id, usuario_id, data_reserva, checkin_realizado, checkin_em, status, codigo_comprovante, criado_em
        `, [cadeiraId, checkinRealizado, checkinEm, codigoComprovante, reservaAntiga.id]);
        novaReserva = updateRes.rows[0];
      } else {
        const insertRes = await client.query(`
          INSERT INTO reservas (cadeira_id, usuario_id, data_reserva, checkin_realizado, checkin_em, status, codigo_comprovante)
          VALUES ($1, $2, $3, $4, $5, 'ATIVA', $6)
          RETURNING id, cadeira_id, usuario_id, data_reserva, checkin_realizado, checkin_em, status, codigo_comprovante, criado_em
        `, [cadeiraId, user.userId, dataAlvoIso, checkinRealizado, checkinEm, codigoComprovante]);
        novaReserva = insertRes.rows[0];
      }

      // Registra evento no histórico de auditoria
      await ReservaHistoryService.registrarEvento({
        reservaId: novaReserva.id,
        cadeiraId: cadeira.id,
        usuarioId: user.userId,
        dataReserva: dataAlvoIso,
        tipoEvento: isTroca ? 'TROCADA' : 'CRIADA',
        executadoPorUsuarioId: user.userId,
        motivo: isTroca ? `Troca atômica de assento (Mesa ${reservaAntiga?.identificador} -> Mesa ${cadeira.identificador})` : 'Reserva de assento efetuada',
        detalhes: {
          codigoComprovante,
          escritorioId: cadeira.escritorio_id,
          cadeiraAntigaId: reservaAntiga?.cadeira_id || null,
          cadeiraAntigaIdentificador: reservaAntiga?.identificador || null,
          checkinAutomatico: checkinRealizado
        }
      }, client);

      await client.query('COMMIT');


      // 8. Disparar eventos WebSocket pós-COMMIT
      // a) Broadcast para o novo assento
      wsManager.broadcastSeatUpdate({
        evento: 'assento_atualizado',
        escritorioId: cadeira.escritorio_id,
        cadeiraId: cadeira.id,
        data: dataAlvoIso,
        status: 'ocupada',
        ocupante: {
          nome: user.nome,
          departamento: user.departamentoNome || 'Colaborador',
          departamentoId: user.departamentoId || undefined
        }
      });

      // b) Se foi troca, liberar o assento antigo no WebSocket
      if (isTroca && reservaAntiga) {
        wsManager.broadcastSeatUpdate({
          evento: 'assento_atualizado',
          escritorioId: reservaAntiga.escritorio_id,
          cadeiraId: reservaAntiga.cadeira_id,
          data: dataAlvoIso,
          status: 'livre',
          ocupante: null
        });
      }

      // 9. Comunicação Assíncrona desacoplada (Broker / E-mails / Auditoria)
      dispatchAsyncEvent({
        evento: isTroca ? 'RESERVA_TROCADA' : 'RESERVA_CRIADA',
        reservaId: novaReserva.id,
        codigoComprovante: novaReserva.codigo_comprovante,
        usuarioId: user.userId,
        usuarioEmail: user.email,
        usuarioNome: user.nome,
        cadeiraId: cadeira.id,
        cadeiraIdentificador: cadeira.identificador,
        escritorioId: cadeira.escritorio_id,
        dataReserva: dataAlvoIso,
        checkinAutomatico: isGestao,
        criadoEm: timestampIso
      });

      return res.status(201).json({
        message: isTroca ? 'Troca de assento realizada com sucesso!' : 'Reserva realizada com sucesso!',
        comprovante: codigoComprovante,
        reserva: novaReserva,
        trocaRealizada: isTroca
      });
    } catch (error: any) {
      await client.query('ROLLBACK');

      // Tratamento de conflito de concorrência PostgreSQL (Código 23505 - unique_violation)
      if (error.code === '23505') {
        if (error.constraint === 'unq_cadeira_data' || error.constraint === 'unq_cadeira_data_ativa') {
          return res.status(409).json({
            error: 'Conflito de Concorrência: Este assento acabou de ser reservado por outro usuário para a mesma data.'
          });
        }
        if (error.constraint === 'unq_usuario_data' || error.constraint === 'unq_usuario_data_ativa') {
          return res.status(409).json({
            error: 'Conflito: Você já possui uma reserva ativa para esta mesma data.'
          });
        }
      }

      console.error('[ReservaController.criarReserva] Erro:', error);
      return res.status(500).json({ error: 'Erro interno ao processar a reserva.' });
    } finally {
      client.release();
    }
  }

  public static async fazerCheckin(req: AuthenticatedRequest, res: Response) {
    const user = req.user!;
    const reservaId = parseInt(req.params.id, 10);

    if (isNaN(reservaId)) {
      return res.status(400).json({ error: 'ID de reserva inválido.' });
    }

    const agora = DateTime.now().setZone('America/Sao_Paulo');
    const horarioInicio = await ConfigService.get('HORARIO_INICIO_CHECKIN', '06:00');
    const horarioLimite = await ConfigService.get('HORARIO_LIMITE_CHECKIN', '11:00');
    const [horaInicioH, horaInicioM] = horarioInicio.split(':').map(Number);
    const [horaLimiteH, horaLimiteM] = horarioLimite.split(':').map(Number);
    const inicioCheckinHoje = agora.set({ hour: horaInicioH, minute: horaInicioM, second: 0, millisecond: 0 });
    const limiteCheckinHoje = agora.set({ hour: horaLimiteH, minute: horaLimiteM, second: 0, millisecond: 0 });

    if (agora < inicioCheckinHoje) {
      return res.status(400).json({ error: `O check-in diário só está liberado a partir das ${horarioInicio}.` });
    }

    try {
      const reservaRes = await pool.query(`
        SELECT 
          r.id, 
          r.usuario_id, 
          r.data_reserva, 
          r.checkin_realizado, 
          r.checkin_em,
          r.status,
          r.codigo_comprovante,
          r.cadeira_id, 
          c.identificador AS cadeira_identificador,
          b.id AS baia_id,
          b.nome AS baia_nome,
          e.id AS escritorio_id,
          e.nome AS escritorio_nome,
          e.cidade AS escritorio_cidade,
          u.nome AS usuario_nome,
          u.matricula AS usuario_matricula
        FROM reservas r
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        JOIN escritorios e ON b.escritorio_id = e.id
        JOIN usuarios u ON r.usuario_id = u.id
        WHERE r.id = $1
      `, [reservaId]);

      if (reservaRes.rowCount === 0) {
        return res.status(404).json({ error: 'Reserva não encontrada.' });
      }

      const reserva = reservaRes.rows[0];

      // Se foi enviado um identificador de cadeira via QR Code, validar se bate com a reserva
      const { cadeiraId } = req.body || {};
      if (cadeiraId && parseInt(cadeiraId, 10) !== reserva.cadeira_id) {
        return res.status(400).json({
          error: `QR Code inválido: este código pertence à mesa ${cadeiraId}, mas sua reserva é na mesa ${reserva.cadeira_identificador}.`
        });
      }

      const hasRhAccess = user.permissaoRh === true || user.is_admin === true || user.perfil === 'ADMIN_RH';

      if (reserva.usuario_id !== user.userId && !hasRhAccess) {
        return res.status(403).json({ error: 'Você não tem permissão para realizar check-in nesta reserva.' });
      }

      if (reserva.status !== 'ATIVA') {
        return res.status(400).json({ error: `Não é possível realizar check-in em uma reserva com status ${reserva.status}.` });
      }

      const checkinHoraAtual = new Date().toISOString();

      if (reserva.checkin_realizado) {
        return res.status(200).json({
          message: 'Check-in já havia sido realizado anteriormente.',
          comprovante: reserva.codigo_comprovante,
          checkinEm: reserva.checkin_em || checkinHoraAtual,
          reserva: {
            id: reserva.id,
            dataReserva: typeof reserva.data_reserva === 'string' ? reserva.data_reserva : DateTime.fromJSDate(reserva.data_reserva).toISODate()!,
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
        });
      }

      const dataReservaIso = typeof reserva.data_reserva === 'string'
        ? reserva.data_reserva
        : DateTime.fromJSDate(reserva.data_reserva).toISODate();

      // Verificar se a reserva é de hoje
      if (dataReservaIso !== agora.toISODate()) {
        return res.status(400).json({ error: 'O check-in só pode ser realizado no próprio dia da reserva.' });
      }

      // Bloquear se passou do horário limite (11h00)
      if (agora > limiteCheckinHoje && !hasRhAccess) {
        return res.status(400).json({
          error: `O horário limite para check-in (${horarioLimite}) já foi encerrado.`
        });
      }

      await pool.query(`
        UPDATE reservas
        SET checkin_realizado = true, checkin_em = NOW()
        WHERE id = $1
      `, [reservaId]);

      // Registrar evento de Check-in na Linha do Tempo
      await ReservaHistoryService.registrarEvento({
        reservaId: reserva.id,
        cadeiraId: reserva.cadeira_id,
        usuarioId: reserva.usuario_id,
        dataReserva: dataReservaIso,
        tipoEvento: 'CHECKIN',
        executadoPorUsuarioId: user.userId,
        motivo: user.userId === reserva.usuario_id ? 'Check-in de presença realizado pelo colaborador' : 'Check-in administrativo validado pela Gestão/RH',
        detalhes: {
          checkinEm: checkinHoraAtual,
          comprovante: reserva.codigo_comprovante
        }
      });

      return res.status(200).json({
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
      });
    } catch (error) {
      console.error('[ReservaController.fazerCheckin] Erro:', error);
      return res.status(500).json({ error: 'Erro ao realizar check-in.' });
    }
  }

  public static async cancelarReserva(req: AuthenticatedRequest, res: Response) {
    const user = req.user!;
    const reservaId = parseInt(req.params.id, 10);

    if (isNaN(reservaId)) {
      return res.status(400).json({ error: 'ID de reserva inválido.' });
    }

    try {
      const reservaRes = await pool.query(`
        SELECT 
          r.id, 
          r.usuario_id, 
          r.data_reserva, 
          r.status, 
          r.cadeira_id, 
          r.codigo_comprovante,
          b.escritorio_id,
          c.identificador AS cadeira_identificador,
          e.nome AS escritorio_nome,
          e.cidade AS escritorio_cidade
        FROM reservas r
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        JOIN escritorios e ON b.escritorio_id = e.id
        WHERE r.id = $1
      `, [reservaId]);

      if (reservaRes.rowCount === 0) {
        return res.status(404).json({ error: 'Reserva não encontrada.' });
      }

      const reserva = reservaRes.rows[0];
      const hasRhAccess = user.permissaoRh === true || user.is_admin === true || user.perfil === 'ADMIN_RH';

      if (reserva.usuario_id !== user.userId && !hasRhAccess) {
        return res.status(403).json({ error: 'Você não tem permissão para cancelar esta reserva.' });
      }

      if (reserva.status !== 'ATIVA') {
        return res.status(400).json({ error: 'Apenas reservas ativas podem ser canceladas.' });
      }

      await pool.query(`
        UPDATE reservas
        SET status = 'CANCELADA'
        WHERE id = $1
      `, [reservaId]);

      const dataIso = typeof reserva.data_reserva === 'string'
        ? reserva.data_reserva
        : DateTime.fromJSDate(reserva.data_reserva).toISODate()!;

      // Registrar evento de cancelamento na Linha do Tempo
      await ReservaHistoryService.registrarEvento({
        reservaId: reserva.id,
        cadeiraId: reserva.cadeira_id,
        usuarioId: reserva.usuario_id,
        dataReserva: dataIso,
        tipoEvento: user.userId === reserva.usuario_id ? 'CANCELADA_USUARIO' : 'CANCELADA_GESTAO',
        executadoPorUsuarioId: user.userId,
        motivo: user.userId === reserva.usuario_id ? 'Cancelamento voluntário pelo colaborador' : 'Cancelamento administrativo por RH/Gestão',
        detalhes: {
          codigoComprovante: reserva.codigo_comprovante,
          cadeiraIdentificador: reserva.cadeira_identificador,
          escritorioNome: reserva.escritorio_nome
        }
      });

      // Liberar o assento via WebSocket
      wsManager.broadcastSeatUpdate({
        evento: 'assento_atualizado',
        escritorioId: reserva.escritorio_id,
        cadeiraId: reserva.cadeira_id,
        data: dataIso,
        status: 'livre',
        ocupante: null
      });

      return res.status(200).json({ 
        message: 'Reserva cancelada com sucesso.',
        data: {
          id: reserva.id,
          codigoComprovante: reserva.codigo_comprovante,
          cadeiraIdentificador: reserva.cadeira_identificador,
          escritorioNome: reserva.escritorio_nome,
          escritorioCidade: reserva.escritorio_cidade,
          dataReserva: dataIso,
          canceladoEm: new Date().toISOString()
        }
      });
    } catch (error) {
      console.error('[ReservaController.cancelarReserva] Erro:', error);
      return res.status(500).json({ error: 'Erro ao cancelar reserva.' });
    }
  }

  public static async historicoMinhasReservas(req: AuthenticatedRequest, res: Response) {
    const user = req.user!;
    const limit = parseInt(req.query.limit as string, 10) || 50;
    const offset = parseInt(req.query.offset as string, 10) || 0;

    try {
      const historico = await ReservaHistoryService.getHistoricoUsuario(user.userId, limit, offset);
      return res.status(200).json(historico);
    } catch (error) {
      console.error('[ReservaController.historicoMinhasReservas] Erro:', error);
      return res.status(500).json({ error: 'Erro ao consultar histórico de movimentações do usuário.' });
    }
  }


  public static async minhasReservas(req: AuthenticatedRequest, res: Response) {
    const user = req.user!;

    try {
      const result = await pool.query(`
        SELECT 
          r.id,
          to_char(r.data_reserva, 'YYYY-MM-DD') AS data_reserva,
          r.checkin_realizado,
          r.checkin_em,
          r.status,
          r.codigo_comprovante,
          r.criado_em,
          c.id AS cadeira_id,
          c.identificador AS cadeira_identificador,
          b.id AS baia_id,
          b.nome AS baia_nome,
          e.id AS escritorio_id,
          e.nome AS escritorio_nome,
          e.cidade AS escritorio_cidade
        FROM reservas r
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        JOIN escritorios e ON b.escritorio_id = e.id
        WHERE r.usuario_id = $1
        ORDER BY r.data_reserva DESC, r.id DESC
      `, [user.userId]);

      return res.status(200).json(result.rows);
    } catch (error) {
      console.error('[ReservaController.minhasReservas] Erro:', error);
      return res.status(500).json({ error: 'Erro ao listar reservas do usuário.' });
    }
  }

  public static async enviarComprovanteEmail(req: AuthenticatedRequest, res: Response) {
    const user = req.user!;
    const reservaId = parseInt(req.params.id, 10);

    if (isNaN(reservaId)) {
      return res.status(400).json({ error: 'ID de reserva inválido.' });
    }

    try {
      const result = await pool.query(`
        SELECT 
          r.id,
          to_char(r.data_reserva, 'YYYY-MM-DD') AS data_reserva,
          r.codigo_comprovante,
          r.status,
          to_char(r.criado_em, 'DD/MM/YYYY HH24:MI') AS criado_em_formatado,
          c.identificador AS cadeira_identificador,
          b.nome AS baia_nome,
          e.nome AS escritorio_nome,
          e.cidade AS escritorio_cidade,
          u.nome AS usuario_nome,
          u.email AS usuario_email
        FROM reservas r
        JOIN cadeiras c ON r.cadeira_id = c.id
        JOIN baias b ON c.baia_id = b.id
        JOIN escritorios e ON b.escritorio_id = e.id
        JOIN usuarios u ON r.usuario_id = u.id
        WHERE r.id = $1
      `, [reservaId]);

      if (result.rowCount === 0) {
        return res.status(404).json({ error: 'Reserva não encontrada.' });
      }

      const reserva = result.rows[0];

      // Verificar autorização (o próprio usuário ou perfil RH/ADMIN)
      const hasPermission = reserva.usuario_email === user.email || user.perfil === 'ADMIN_RH' || user.permissaoRh === true;
      if (!hasPermission) {
        return res.status(403).json({ error: 'Você não tem permissão para acessar o comprovante desta reserva.' });
      }

      // Disparar envio de e-mail assíncrono
      EmailService.enviarComprovanteReserva(reserva.usuario_email, reserva.usuario_nome, {
        escritorioNome: reserva.escritorio_nome,
        escritorioCidade: reserva.escritorio_cidade,
        baiaNome: reserva.baia_nome,
        cadeiraIdentificador: reserva.cadeira_identificador,
        dataReserva: reserva.data_reserva,
        codigoComprovante: reserva.codigo_comprovante,
        emitidoEm: reserva.criado_em_formatado
      }).catch(err => {
        console.error('[ReservaController.enviarComprovanteEmail] Erro ao despachar e-mail:', err);
      });

      return res.status(200).json({
        message: `Comprovante enviado com sucesso para ${reserva.usuario_email}`,
        email: reserva.usuario_email
      });
    } catch (error) {
      console.error('[ReservaController.enviarComprovanteEmail] Erro:', error);
      return res.status(500).json({ error: 'Erro ao enviar comprovante por e-mail.' });
    }
  }
}

