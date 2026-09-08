import { Router } from 'express';
import { TiController } from '../controllers/tiController';
import { authMiddleware, requireTi } from '../middleware/auth';
import { adminLimiter, emailTestLimiter, userActionLimiter } from '../middleware/rateLimiter';
import { validateRequest } from '../middleware/validateRequest';
import { auditoriaQuerySchema, testarEmailSchema, tiConfigSchema } from '../schemas';

const router = Router();

// Todas as rotas de TI exigem rate limit, autenticação e permissão de TI
router.use(adminLimiter);
router.use(authMiddleware);
router.use(requireTi);

router.get('/configuracoes', TiController.getConfiguracoesTi);
router.put('/configuracoes', userActionLimiter, validateRequest({ body: tiConfigSchema }), TiController.updateConfiguracoesTi);
router.post('/testar-email', emailTestLimiter, validateRequest({ body: testarEmailSchema }), TiController.testarConexaoEmail);
router.get('/status', TiController.getStatusSistema);
router.get('/auditoria-mfa', TiController.getAuditoriaMfa);
router.get('/auditoria-acessos', validateRequest({ query: auditoriaQuerySchema }), TiController.getAuditoriaAcessos);

export default router;

