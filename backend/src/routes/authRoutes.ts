import { Router } from 'express';
import { AuthController } from '../controllers/authController';
import { authenticateToken } from '../middleware/auth';
import { authLimiter } from '../middleware/rateLimiter';

const router = Router();

// Rate limiting estrito para autenticação e recuperação de senha
router.use(authLimiter);

// POST /api/auth/login
router.post('/login', AuthController.login);

// POST /api/auth/esqueci-senha (solicita código de recuperação por e-mail)
router.post('/esqueci-senha', AuthController.solicitarRecuperacaoSenha);

// POST /api/auth/redefinir-senha (valida código e redefine senha)
router.post('/redefinir-senha', AuthController.redefinirSenha);

// POST /api/auth/mfa/solicitar (requer token de usuário ADMIN_RH)
router.post('/mfa/solicitar', authenticateToken, AuthController.solicitarMfa);

// POST /api/auth/mfa/validar (valida código de 6 dígitos e retorna admin_token)
router.post('/mfa/validar', authenticateToken, AuthController.validarMfa);

export default router;

