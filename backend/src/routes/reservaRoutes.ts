import { Router } from 'express';
import { ReservaController } from '../controllers/reservaController';
import { authenticateToken } from '../middleware/auth';
import { globalLimiter } from '../middleware/rateLimiter';

const router = Router();

router.use(globalLimiter);

// POST /api/reservas (Criação com troca atômica, cota semanal e auto-checkin de gestão)
router.post('/', authenticateToken, ReservaController.criarReserva);

// GET /api/reservas/minhas (Listagem de reservas do colaborador conectado)
router.get('/minhas', authenticateToken, ReservaController.minhasReservas);

// GET /api/reservas/historico (Linha do tempo forense de eventos do usuário)
router.get('/historico', authenticateToken, ReservaController.historicoMinhasReservas);


// POST /api/reservas/:id/checkin (Confirmação de presença manual com trava às 11:00)
router.post('/:id/checkin', authenticateToken, ReservaController.fazerCheckin);

// POST /api/reservas/:id/enviar-comprovante-email (Disparo do voucher por e-mail)
router.post('/:id/enviar-comprovante-email', authenticateToken, ReservaController.enviarComprovanteEmail);

// POST /api/reservas/:id/liberar (Liberação/Checkout voluntário da mesa pós check-in)
router.post('/:id/liberar', authenticateToken, ReservaController.liberarMesa);

// DELETE /api/reservas/:id (Cancelamento da reserva com devolução ao WebSocket)
router.delete('/:id', authenticateToken, ReservaController.cancelarReserva);

export default router;

