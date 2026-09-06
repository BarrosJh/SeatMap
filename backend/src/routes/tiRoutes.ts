import { Router } from 'express';
import { TiController } from '../controllers/tiController';
import { authMiddleware, requireTi } from '../middleware/auth';
import { adminLimiter } from '../middleware/rateLimiter';

const router = Router();

// Todas as rotas de TI exigem rate limit, autenticação e permissão de TI
router.use(adminLimiter);
router.use(authMiddleware);
router.use(requireTi);

router.get('/configuracoes', TiController.getConfiguracoesTi);
router.put('/configuracoes', TiController.updateConfiguracoesTi);
router.post('/testar-email', TiController.testarConexaoEmail);
router.get('/status', TiController.getStatusSistema);
router.get('/auditoria-mfa', TiController.getAuditoriaMfa);

export default router;

