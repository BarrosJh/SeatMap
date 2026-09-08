import { ReservaCreateService, CriarReservaInput } from './reservas/reservaCreateService';
import { ReservaCheckinService, CheckinInput } from './reservas/reservaCheckinService';
import { ReservaCancelService } from './reservas/reservaCancelService';
import { ReservaCheckoutService } from './reservas/reservaCheckoutService';
import { ReservaQueryService } from './reservas/reservaQueryService';

export { CriarReservaInput, CheckinInput };

/**
 * ReservaService (Facade Pattern)
 * Centraliza a API pública de reservas e delega para os submódulos especializados:
 * - ReservaCreateService (Criação, concorrência, abertura de agenda e troca atômica)
 * - ReservaCheckinService (Check-in QR, RBAC/BOLA e tolerância de reserva tardia)
 * - ReservaCancelService (Cancelamento com auditoria)
 * - ReservaCheckoutService (Liberação/Checkout de mesa pós check-in)
 * - ReservaQueryService (Listagem e envio de comprovantes)
 */
export class ReservaService {
  /**
   * Processa a criação ou troca atômica de reserva com locks, idempotência e notificações
   */
  public static async criarReserva(input: CriarReservaInput) {
    return ReservaCreateService.criarReserva(input);
  }

  /**
   * Processa o check-in de presença com validação BOLA, QR Code e tolerância dinâmica de No-Show
   */
  public static async fazerCheckin(input: CheckinInput) {
    return ReservaCheckinService.fazerCheckin(input);
  }

  /**
   * Cancela uma reserva ativa do usuário com histórico e liberação de assento
   */
  public static async cancelarReserva(reservaId: number, usuarioId: number) {
    return ReservaCancelService.cancelarReserva(reservaId, usuarioId);
  }

  /**
   * Libera uma mesa após o check-in realizado
   */
  public static async liberarMesa(reservaId: number, usuarioId: number, correlationId?: string) {
    return ReservaCheckoutService.liberarMesa(reservaId, usuarioId, correlationId);
  }

  /**
   * Lista reservas ativas e históricas do usuário
   */
  public static async minhasReservas(usuarioId: number, limit = 50, offset = 0) {
    return ReservaQueryService.minhasReservas(usuarioId, limit, offset);
  }

  /**
   * Envia comprovante de reserva por e-mail corporativo
   */
  public static async enviarComprovanteEmail(
    reservaId: number,
    userEmail: string,
    userPerfil: string,
    isRh: boolean,
    correlationId?: string
  ) {
    return ReservaQueryService.enviarComprovanteEmail(reservaId, userEmail, userPerfil, isRh, correlationId);
  }
}


