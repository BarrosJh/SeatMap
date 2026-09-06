import { Router } from 'express';
import { AuthController } from '../controllers/authController';
import { authenticateToken } from '../middleware/auth';

const router = Router();

// POST /api/auth/login
router.post('/login', AuthController.login);

// POST /api/auth/mfa/solicitar (requer token de usuário ADMIN_RH)
router.post('/mfa/solicitar', authenticateToken, AuthController.solicitarMfa);

// POST /api/auth/mfa/validar (valida código de 6 dígitos e retorna admin_token)
router.post('/mfa/validar', authenticateToken, AuthController.validarMfa);

export default router;

