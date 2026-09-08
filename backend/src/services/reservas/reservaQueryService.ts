import pool from '../../config/db';
import { EmailService } from '../emailService';
import { logger } from '../../utils/logger';

export class ReservaQueryService {
  /**
   * Lista reservas ativas e históricas do usuário
   */
  public static async minhasReservas(usuarioId: number, limit = 50, offset = 0) {
    const result = await pool.query(`
      SELECT 
        r.id,
        to_char(r.data_reserva, 'YYYY-MM-DD') AS data_reserva,
        r.checkin_realizado,
        r.checkin_em,
        r.checkout_em,
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
      LIMIT $2 OFFSET $3
    `, [usuarioId, limit, offset]);

    return result.rows;
  }

  /**
   * Envia comprovante por e-mail
   */
  public static async enviarComprovanteEmail(reservaId: number, userEmail: string, userPerfil: string, isRh: boolean, correlationId?: string) {
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
      return { success: false, code: 404, error: 'Reserva não encontrada.' };
    }

    const reserva = result.rows[0];
    const hasPermission = reserva.usuario_email === userEmail || userPerfil === 'ADMIN_RH' || isRh;

    if (!hasPermission) {
      return { success: false, code: 403, error: 'Você não tem permissão para acessar o comprovante desta reserva.' };
    }

    EmailService.enviarComprovanteReserva(reserva.usuario_email, reserva.usuario_nome, {
      escritorioNome: reserva.escritorio_nome,
      escritorioCidade: reserva.escritorio_cidade,
      baiaNome: reserva.baia_nome,
      cadeiraIdentificador: reserva.cadeira_identificador,
      dataReserva: reserva.data_reserva,
      codigoComprovante: reserva.codigo_comprovante,
      emitidoEm: reserva.criado_em_formatado
    }).catch(err => {
      logger.error('[ReservaQueryService.enviarComprovanteEmail] Erro ao despachar e-mail:', { correlationId, error: err });
    });

    return {
      success: true,
      code: 200,
      message: `Comprovante enviado com sucesso para ${reserva.usuario_email}`,
      email: reserva.usuario_email
    };
  }
}
