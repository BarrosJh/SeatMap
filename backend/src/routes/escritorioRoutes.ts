import { Router } from 'express';
import { EscritorioController } from '../controllers/escritorioController';
import { authenticateToken } from '../middleware/auth';

const router = Router();

// GET /api/escritorios
router.get('/', authenticateToken, EscritorioController.listar);

// GET /api/escritorios/ocupacao-semanal
router.get('/ocupacao-semanal', authenticateToken, EscritorioController.getOcupacaoSemanal);
router.get('/ocupacao/semanal', authenticateToken, EscritorioController.getOcupacaoSemanal);

// GET /api/escritorios/aviso
router.get('/aviso', authenticateToken, EscritorioController.getAvisoGlobal);

// GET /api/escritorios/:id/mapa?data=YYYY-MM-DD
router.get('/:id/mapa', authenticateToken, EscritorioController.getMapa);

export default router;

