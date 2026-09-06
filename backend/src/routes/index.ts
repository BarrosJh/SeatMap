import { Router } from 'express';
import authRoutes from './authRoutes';
import escritorioRoutes from './escritorioRoutes';
import reservaRoutes from './reservaRoutes';
import adminRoutes from './adminRoutes';
import tiRoutes from './tiRoutes';

const router = Router();

router.use('/auth', authRoutes);
router.use('/escritorios', escritorioRoutes);
router.use('/reservas', reservaRoutes);
router.use('/admin', adminRoutes);
router.use('/admin/ti', tiRoutes);

export default router;

