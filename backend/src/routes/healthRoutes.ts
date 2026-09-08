import { Router } from 'express';
import { HealthController } from '../controllers/healthController';
import { internalProbeAuth } from '../middleware/internalProbeAuth';

const router = Router();

router.get('/live', HealthController.live);
router.get('/ready', internalProbeAuth, HealthController.ready);
router.get('/metrics', internalProbeAuth, HealthController.metrics);
router.get('/', internalProbeAuth, HealthController.health);

export default router;

