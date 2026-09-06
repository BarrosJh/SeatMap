import { Router } from 'express';
import authRoutes from './authRoutes';
import escritorioRoutes from './escritorioRoutes';
import reservaRoutes from './reservaRoutes';
import adminRoutes from './adminRoutes';

const router = Router();

router.use('/auth', authRoutes);
router.use('/escritorios', escritorioRoutes);
router.use('/reservas', reservaRoutes);
router.use('/admin', adminRoutes);

export default router;

