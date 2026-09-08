import { Router } from 'express';
import { LoginController } from '../controllers/auth/loginController';
import { MfaController } from '../controllers/auth/mfaController';
import { SsoController } from '../controllers/auth/ssoController';
import { PasswordResetController } from '../controllers/auth/passwordResetController';
import { authenticateToken } from '../middleware/auth';
import { authLimiter } from '../middleware/rateLimiter';
import { validateRequest } from '../middleware/validateRequest';
import { loginSchema, esqueciSenhaSchema, redefinirSenhaSchema, refreshTokenSchema } from '../schemas';

const router = Router();

// Rate limiting estrito para autenticação e recuperação de senha
router.use(authLimiter);

// 1. Login Padrão, Configurações de Segurança & SSO
router.get('/config-seguranca', LoginController.getConfigSeguranca);
router.post('/login', validateRequest({ body: loginSchema }), LoginController.login);
router.get('/sso/config', SsoController.getSsoConfig);
router.post('/sso/login', SsoController.loginSso);

// 2. Validação de Login com TOTP ou E-mail (Passo 2 do 2FA)
router.post('/totp/validar-login', MfaController.validarLoginTotp);
router.post('/mfa/validar-login-email', MfaController.validarLoginEmailMfa);

// 3. Gestão de TOTP pelo próprio Usuário Logado
router.get('/totp/setup', authenticateToken, MfaController.setupTotp);
router.post('/totp/ativar', authenticateToken, MfaController.ativarTotp);
router.post('/totp/desativar', authenticateToken, MfaController.desativarTotp);

// 4. Esqueci minha Senha & Redefinição
router.post('/esqueci-senha', PasswordResetController.solicitarRecuperacaoSenha);
router.post('/redefinir-senha', PasswordResetController.redefinirSenha);

// 5. Refresh Token (Rotação de Sessão) & Logout
router.post('/refresh-token', LoginController.refreshToken);
router.post('/logout', LoginController.logout);
router.post('/logout-global', authenticateToken, LoginController.logoutGlobal);

export default router;
