import { Router } from 'express';
import { ReservaController } from '../controllers/reservaController';
import { authenticateToken } from '../middleware/auth';

const router = Router();

// POST /api/reservas (Criação com troca atômica, cota semanal e auto-checkin de gestão)
router.post('/', authenticateToken, ReservaController.criarReserva);

// GET /api/reservas/minhas (Listagem de reservas do colaborador conectado)
router.get('/minhas', authenticateToken, ReservaController.minhasReservas);

// POST /api/reservas/:id/checkin (Confirmação de presença manual com trava às 11:00)
router.post('/:id/checkin', authenticateToken, ReservaController.fazerCheckin);

// DELETE /api/reservas/:id (Cancelamento da reserva com devolução ao WebSocket)
router.delete('/:id', authenticateToken, ReservaController.cancelarReserva);

export default router;

