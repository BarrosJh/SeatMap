import { Request, Response } from 'express';
import { AuthenticatedRequest } from '../middleware/auth';
import { LoginController } from './auth/loginController';
import { MfaController } from './auth/mfaController';
import { SsoController } from './auth/ssoController';
import { PasswordResetController } from './auth/passwordResetController';

export { LoginController } from './auth/loginController';
export { MfaController } from './auth/mfaController';
export { SsoController } from './auth/ssoController';
export { PasswordResetController } from './auth/passwordResetController';

export class AuthController {
  // 1. Login & Sessão
  public static login(req: Request, res: Response) {
    return LoginController.login(req, res);
  }

  public static refreshToken(req: Request, res: Response) {
    return LoginController.refreshToken(req, res);
  }

  public static logout(req: Request, res: Response) {
    return LoginController.logout(req, res);
  }

  public static logoutGlobal(req: AuthenticatedRequest, res: Response) {
    return LoginController.logoutGlobal(req, res);
  }

  public static getConfigSeguranca(req: Request, res: Response) {
    return LoginController.getConfigSeguranca(req, res);
  }

  // 2. TOTP & MFA
  public static setupTotp(req: AuthenticatedRequest, res: Response) {
    return MfaController.setupTotp(req, res);
  }

  public static ativarTotp(req: AuthenticatedRequest, res: Response) {
    return MfaController.ativarTotp(req, res);
  }

  public static desativarTotp(req: AuthenticatedRequest, res: Response) {
    return MfaController.desativarTotp(req, res);
  }

  public static validarLoginTotp(req: Request, res: Response) {
    return MfaController.validarLoginTotp(req, res);
  }

  public static validarLoginEmailMfa(req: Request, res: Response) {
    return MfaController.validarLoginEmailMfa(req, res);
  }

  public static solicitarMfa(req: AuthenticatedRequest, res: Response) {
    return MfaController.solicitarMfa(req, res);
  }

  public static validarMfa(req: AuthenticatedRequest, res: Response) {
    return MfaController.validarMfa(req, res);
  }

  // 3. Single Sign-On (SSO)
  public static getSsoConfig(req: Request, res: Response) {
    return SsoController.getSsoConfig(req, res);
  }

  public static loginSso(req: Request, res: Response) {
    return SsoController.loginSso(req, res);
  }

  // 4. Recuperação de Senha
  public static solicitarRecuperacaoSenha(req: Request, res: Response) {
    return PasswordResetController.solicitarRecuperacaoSenha(req, res);
  }

  public static redefinirSenha(req: Request, res: Response) {
    return PasswordResetController.redefinirSenha(req, res);
  }
}
