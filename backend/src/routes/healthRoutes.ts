import { Router } from 'express';
import { HealthController } from '../controllers/healthController';

const router = Router();

router.get('/live', HealthController.live);
router.get('/ready', HealthController.ready);
router.get('/', HealthController.health);

export default router;

