import { Router } from 'express';
import { LoginController } from '../controllers/auth/loginController';
import { MfaController } from '../controllers/auth/mfaController';
import { SsoController } from '../controllers/auth/ssoController';
import { PasswordResetController } from '../controllers/auth/passwordResetController';
import { WebAuthnController } from '../controllers/auth/webAuthnController';
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
	senhaAtualSchema,
	webAuthnLoginOptionsSchema,
	webAuthnLoginVerifySchema,
	webAuthnRegisterVerifySchema,
	idParamSchema
} from '../schemas';

const router = Router();

// Rate limiting estrito para autenticação e recuperação de senha
router.use(authLimiter);

// 1. Login Padrão, Perfil Autoritativo, Configurações de Segurança & SSO
router.get('/config-seguranca', LoginController.getConfigSeguranca);
router.get('/me', authenticateToken, LoginController.getMe);
router.post('/login', authUserLimiter, validateRequest({ body: loginSchema }), LoginController.login);
router.get('/sso/config', SsoController.getSsoConfig);
router.post('/sso/login', authUserLimiter, validateRequest({ body: ssoLoginSchema }), SsoController.loginSso);

// 2. Autenticação Biométrica Nativa (WebAuthn / Passkeys / FIDO2)
router.post('/webauthn/login/options', validateRequest({ body: webAuthnLoginOptionsSchema }), WebAuthnController.loginOptions);
router.post('/webauthn/login/verify', authUserLimiter, validateRequest({ body: webAuthnLoginVerifySchema }), WebAuthnController.loginVerify);
router.post('/webauthn/register/options', authenticateToken, WebAuthnController.registerOptions);
router.post('/webauthn/register/verify', authenticateToken, validateRequest({ body: webAuthnRegisterVerifySchema }), WebAuthnController.registerVerify);
router.get('/webauthn/devices', authenticateToken, WebAuthnController.listDevices);
router.delete('/webauthn/devices/:id', authenticateToken, validateRequest({ params: idParamSchema }), WebAuthnController.deleteDevice);

// 3. Validação de Login com TOTP ou E-mail (Passo 2 do 2FA)
router.post('/totp/validar-login', validateRequest({ body: validarTotpSchema }), MfaController.validarLoginTotp);
router.post('/mfa/validar-login-email', validateRequest({ body: validarMfaEmailSchema }), MfaController.validarLoginEmailMfa);

// 4. Gestão de TOTP pelo próprio Usuário Logado
router.get('/totp/setup', authenticateToken, MfaController.setupTotp);
router.post('/totp/ativar', authenticateToken, validateRequest({ body: codigoMfaSchema }), MfaController.ativarTotp);
router.post('/totp/desativar', authenticateToken, validateRequest({ body: senhaAtualSchema }), MfaController.desativarTotp);

// 5. Esqueci minha Senha & Redefinição
router.post('/esqueci-senha', authUserLimiter, validateRequest({ body: esqueciSenhaSchema }), PasswordResetController.solicitarRecuperacaoSenha);
router.post('/redefinir-senha', authUserLimiter, validateRequest({ body: redefinirSenhaSchema }), PasswordResetController.redefinirSenha);

// 6. Refresh Token (Rotação de Sessão) & Logout
router.post('/refresh-token', validateRequest({ body: refreshTokenSchema }), LoginController.refreshToken);
router.post('/logout', validateRequest({ body: logoutSchema }), LoginController.logout);
router.post('/logout-global', authenticateToken, LoginController.logoutGlobal);

export default router;

