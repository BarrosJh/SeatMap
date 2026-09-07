import { PoolClient } from 'pg';
import pool from '../config/db';

export type TipoEventoReserva = 
  | 'CRIADA' 
  | 'TROCADA' 
  | 'CHECKIN' 
  | 'CANCELADA_USUARIO' 
  | 'CANCELADA_GESTAO' 
  | 'CANCELADA_MANUTENCAO' 
  | 'EXPIRADA_NOSHOW';

export interface RegistrarEventoReservaParams {
  reservaId?: number | null;
  cadeiraId: number;
  usuarioId: number;
  dataReserva: string | Date;
  tipoEvento: TipoEventoReserva;
  executadoPorUsuarioId?: number | null;
  motivo?: string | null;
  detalhes?: Record<string, any> | null;
}

export class ReservaHistoryService {
  /**
   * Registra um evento imutável no histórico de reservas.
   * Suporta ser executado dentro de uma transação ativa (passando PoolClient) ou usando o pool global.
   */
  public static async registrarEvento(
    params: RegistrarEventoReservaParams,
    client?: PoolClient
  ): Promise<number | null> {
    const db = client || pool;

    try {
      const dataIso = typeof params.dataReserva === 'string'
        ? params.dataReserva.split('T')[0]
        : params.dataReserva.toISOString().split('T')[0];

      const res = await db.query(`
        INSERT INTO historico_reservas (
          reserva_id,
          cadeira_id,
          usuario_id,
          data_reserva,
          tipo_evento,
          executado_por_usuario_id,
          motivo,
          detalhes
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING id
      `, [
        params.reservaId || null,
        params.cadeiraId,
        params.usuarioId,
        dataIso,
        params.tipoEvento,
        params.executadoPorUsuarioId || null,
        params.motivo || null,
        params.detalhes ? JSON.stringify(params.detalhes) : null
      ]);

      return res.rows[0]?.id || null;
    } catch (error) {
      console.error('[ReservaHistoryService.registrarEvento] Erro ao registrar evento de histórico:', error);
      if (client) {
        throw error;
      }
      return null;
    }
  }

  /**
   * Busca a linha do tempo completa de eventos de uma cadeira física.
   */
  public static async getHistoricoCadeira(cadeiraId: number, limit = 50, offset = 0) {
    const result = await pool.query(`
      SELECT 
        h.id,
        h.reserva_id,
        h.cadeira_id,
        h.usuario_id,
        to_char(h.data_reserva, 'YYYY-MM-DD') AS data_reserva,
        h.tipo_evento,
        h.executado_por_usuario_id,
        h.motivo,
        h.detalhes,
        h.criado_em,
        u.nome AS usuario_nome,
        u.email AS usuario_email,
        u.matricula AS usuario_matricula,
        d.nome AS departamento_nome,
        e_exec.nome AS executado_por_nome,
        e_exec.email AS executado_por_email,
        c.identificador AS cadeira_identificador,
        b.nome AS baia_nome
      FROM historico_reservas h
      JOIN usuarios u ON h.usuario_id = u.id
      LEFT JOIN departamentos d ON u.departamento_id = d.id
      LEFT JOIN usuarios e_exec ON h.executado_por_usuario_id = e_exec.id
      JOIN cadeiras c ON h.cadeira_id = c.id
      JOIN baias b ON c.baia_id = b.id
      WHERE h.cadeira_id = $1
      ORDER BY h.criado_em DESC, h.id DESC
      LIMIT $2 OFFSET $3
    `, [cadeiraId, limit, offset]);

    return result.rows;
  }

  /**
   * Busca o histórico de todas as reservas e movimentações de um usuário específico.
   */
  public static async getHistoricoUsuario(usuarioId: number, limit = 50, offset = 0) {
    const result = await pool.query(`
      SELECT 
        h.id,
        h.reserva_id,
        h.cadeira_id,
        to_char(h.data_reserva, 'YYYY-MM-DD') AS data_reserva,
        h.tipo_evento,
        h.executado_por_usuario_id,
        h.motivo,
        h.detalhes,
        h.criado_em,
        c.identificador AS cadeira_identificador,
        b.nome AS baia_nome,
        esc.nome AS escritorio_nome,
        esc.cidade AS escritorio_cidade,
        e_exec.nome AS executado_por_nome
      FROM historico_reservas h
      JOIN cadeiras c ON h.cadeira_id = c.id
      JOIN baias b ON c.baia_id = b.id
      JOIN escritorios esc ON b.escritorio_id = esc.id
      LEFT JOIN usuarios e_exec ON h.executado_por_usuario_id = e_exec.id
      WHERE h.usuario_id = $1
      ORDER BY h.criado_em DESC, h.id DESC
      LIMIT $2 OFFSET $3
    `, [usuarioId, limit, offset]);

    return result.rows;
  }
}

