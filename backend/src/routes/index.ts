import { Router } from 'express';
import authRoutes from './authRoutes';
import escritorioRoutes from './escritorioRoutes';
import reservaRoutes from './reservaRoutes';
import adminRoutes from './adminRoutes';
import tiRoutes from './tiRoutes';
import scimRoutes from './scimRoutes';
import healthRoutes from './healthRoutes';
import { CspReportController } from '../controllers/cspReportController';
import { cspReportLimiter } from '../middleware/rateLimiter';

const router = Router();

router.post('/csp-report', cspReportLimiter, CspReportController.handleReport);
router.use('/health', healthRoutes);
router.use('/auth', authRoutes);
router.use('/escritorios', escritorioRoutes);
router.use('/reservas', reservaRoutes);
router.use('/admin', adminRoutes);
router.use('/admin/ti', tiRoutes);
router.use('/scim/v2', scimRoutes);

export default router;

