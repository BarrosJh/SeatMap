import { Router } from 'express';
import { LoginController } from '../controllers/auth/loginController';
import { MfaController } from '../controllers/auth/mfaController';
import { SsoController } from '../controllers/auth/ssoController';
import { PasswordResetController } from '../controllers/auth/passwordResetController';
import { authenticateToken } from '../middleware/auth';
import { authLimiter, authUserLimiter } from '../middleware/rateLimiter';
import { validateRequest } from '../middleware/validateRequest';
import {
	loginSchema,
	esqueciSenhaSchema,
	redefinirSenhaSchema,
	refreshTokenSchema,
	logoutSchema,
	ssoLoginSchema,
	validarMfaEmailSchema,
	validarTotpSchema,
	codigoMfaSchema,
	senhaAtualSchema
} from '../schemas';

const router = Router();

// Rate limiting estrito para autenticação e recuperação de senha
router.use(authLimiter);

// 1. Login Padrão, Perfil Autoritativo, Configurações de Segurança & SSO
router.get('/config-seguranca', LoginController.getConfigSeguranca);
router.get('/me', authenticateToken, LoginController.getMe);
router.post('/login', authUserLimiter, validateRequest({ body: loginSchema }), LoginController.login);
router.get('/sso/config', SsoController.getSsoConfig);
router.post('/sso/login', authUserLimiter, validateRequest({ body: ssoLoginSchema }), LoginController.loginSso);

// 2. Validação de Login com TOTP ou E-mail (Passo 2 do 2FA)
router.post('/totp/validar-login', validateRequest({ body: validarTotpSchema }), MfaController.validarLoginTotp);
router.post('/mfa/validar-login-email', validateRequest({ body: validarMfaEmailSchema }), MfaController.validarLoginEmailMfa);

// 3. Gestão de TOTP pelo próprio Usuário Logado
router.get('/totp/setup', authenticateToken, MfaController.setupTotp);
router.post('/totp/ativar', authenticateToken, validateRequest({ body: codigoMfaSchema }), MfaController.ativarTotp);
router.post('/totp/desativar', authenticateToken, validateRequest({ body: senhaAtualSchema }), MfaController.desativarTotp);

// 4. Esqueci minha Senha & Redefinição
router.post('/esqueci-senha', authUserLimiter, validateRequest({ body: esqueciSenhaSchema }), PasswordResetController.solicitarRecuperacaoSenha);
router.post('/redefinir-senha', authUserLimiter, validateRequest({ body: redefinirSenhaSchema }), PasswordResetController.redefinirSenha);

// 5. Refresh Token (Rotação de Sessão) & Logout
router.post('/refresh-token', validateRequest({ body: refreshTokenSchema }), LoginController.refreshToken);
router.post('/logout', validateRequest({ body: logoutSchema }), LoginController.logout);
router.post('/logout-global', authenticateToken, LoginController.logoutGlobal);

export default router;
