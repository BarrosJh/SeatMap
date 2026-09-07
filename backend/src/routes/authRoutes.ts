import { Router } from 'express';
import { AuthController } from '../controllers/authController';
import { authenticateToken } from '../middleware/auth';
import { authLimiter } from '../middleware/rateLimiter';

const router = Router();

// Rate limiting estrito para autenticação e recuperação de senha
router.use(authLimiter);

// 1. Login Padrão & SSO
router.post('/login', AuthController.login);
router.get('/sso/config', AuthController.getSsoConfig);
router.post('/sso/login', AuthController.loginSso);

// 2. Validação de Login com TOTP ou E-mail (Passo 2 do 2FA)
router.post('/totp/validar-login', AuthController.validarLoginTotp);
router.post('/mfa/validar-login-email', AuthController.validarLoginEmailMfa);

// 3. Gestão de TOTP pelo próprio Usuário Logado
router.get('/totp/setup', authenticateToken, AuthController.setupTotp);
router.post('/totp/ativar', authenticateToken, AuthController.ativarTotp);
router.post('/totp/desativar', authenticateToken, AuthController.desativarTotp);

// 4. Esqueci minha Senha & Redefinição
router.post('/esqueci-senha', AuthController.solicitarRecuperacaoSenha);
router.post('/redefinir-senha', AuthController.redefinirSenha);

// 6. Refresh Token (Rotação de Sessão) & Logout
router.post('/refresh-token', AuthController.refreshToken);
router.post('/logout', AuthController.logout);

export default router;
