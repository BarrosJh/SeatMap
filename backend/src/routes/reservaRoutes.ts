import { Router } from 'express';
import { ReservaController } from '../controllers/reservaController';
import { authenticateToken } from '../middleware/auth';
import { validateRequest } from '../middleware/validateRequest';
import { criarReservaSchema, fazerCheckinSchema, idParamSchema, paginationQuerySchema } from '../schemas';

const router = Router();

// POST /api/reservas (Criação com troca atômica, cota semanal e auto-checkin de gestão)
router.post('/', authenticateToken, validateRequest({ body: criarReservaSchema }), ReservaController.criarReserva);

// GET /api/reservas/minhas (Listagem de reservas do colaborador conectado)
router.get('/minhas', authenticateToken, validateRequest({ query: paginationQuerySchema }), ReservaController.minhasReservas);

// GET /api/reservas/historico (Linha do tempo forense de eventos do usuário)
router.get('/historico', authenticateToken, validateRequest({ query: paginationQuerySchema }), ReservaController.historicoMinhasReservas);


// POST /api/reservas/:id/checkin (Confirmação de presença manual com trava às 11:00)
router.post('/:id/checkin', authenticateToken, validateRequest({ params: idParamSchema, body: fazerCheckinSchema }), ReservaController.fazerCheckin);

// POST /api/reservas/:id/enviar-comprovante-email (Disparo do voucher por e-mail)
router.post('/:id/enviar-comprovante-email', authenticateToken, validateRequest({ params: idParamSchema }), ReservaController.enviarComprovanteEmail);

// POST /api/reservas/:id/liberar (Liberação/Checkout voluntário da mesa pós check-in)
router.post('/:id/liberar', authenticateToken, validateRequest({ params: idParamSchema }), ReservaController.liberarMesa);

// DELETE /api/reservas/:id (Cancelamento da reserva com devolução ao WebSocket)
router.delete('/:id', authenticateToken, validateRequest({ params: idParamSchema }), ReservaController.cancelarReserva);

export default router;

