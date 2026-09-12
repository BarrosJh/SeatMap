import { Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { AuthenticatedRequest } from '../../middleware/auth';
import { WebAuthnService } from '../../services/webAuthnService';
import { TokenService } from '../../services/tokenService';
import { ConfigService } from '../../services/configService';
import { AuditService } from '../../services/auditService';
import { logger } from '../../utils/logger';
import { env } from '../../config/env';
import { toUserResponseDto } from '../../utils/userDtoMapper';

const JWT_SECRET = env.JWT_SECRET;
const JWT_EXPIRATION = env.JWT_EXPIRATION;

export class WebAuthnController {
  private static async validatePwaExclusive(req: Request): Promise<boolean> {
    const isPwaExclusiva = (await ConfigService.get('BIOMETRIA_PWA_EXCLUSIVA', 'true')) === 'true';
    if (!isPwaExclusiva) return true;

    const clientMode = req.headers['x-client-mode'] as string | undefined;
    const isPwaHeader = clientMode === 'pwa-standalone' || clientMode === 'standalone';
    const referrer = req.headers['referrer'] || req.headers['referer'];
    const isAndroidApp = typeof referrer === 'string' && referrer.startsWith('android-app://');

    return isPwaHeader || Boolean(isAndroidApp);
  }

  public static async registerOptions(req: AuthenticatedRequest, res: Response) {
    try {
      if (!(await WebAuthnController.validatePwaExclusive(req))) {
        return res.status(403).json({
          error: 'A autenticação biométrica é autorizada exclusivamente no aplicativo PWA corporativo instalado.'
        });
      }

      const user = req.user;
      if (!user) {
        return res.status(401).json({ error: 'Não autenticado.' });
      }

      const rpId = WebAuthnService.getRpId(req.headers.origin as string, req.headers.host);
      const options = await WebAuthnService.generateRegisterOptions(
        { id: user.userId, email: user.email, nome: user.nome },
        rpId
      );

      return res.status(200).json(options);
    } catch (error: any) {
      logger.error('[WebAuthnController.registerOptions] Erro:', { correlationId: req.correlationId, error: error.message });
      return res.status(500).json({ error: error.message || 'Erro ao gerar opções de registro biométrico.' });
    }
  }

  public static async registerVerify(req: AuthenticatedRequest, res: Response) {
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);

    try {
      if (!(await WebAuthnController.validatePwaExclusive(req))) {
        return res.status(403).json({
          error: 'A autenticação biométrica é autorizada exclusivamente no aplicativo PWA corporativo instalado.'
        });
      }

      const user = req.user;
      if (!user) {
        return res.status(401).json({ error: 'Não autenticado.' });
      }

      const { response, deviceName } = req.body;
      if (!response) {
        return res.status(400).json({ error: 'Resposta biométrica é obrigatória.' });
      }

      const rpId = WebAuthnService.getRpId(req.headers.origin as string, req.headers.host);
      const expectedOrigin = WebAuthnService.getExpectedOrigin(req.headers.origin as string, req.headers.host);

      const result = await WebAuthnService.verifyRegister(
        user.userId,
        response,
        expectedOrigin,
        rpId,
        deviceName || 'Dispositivo Móvel'
      );

      AuditService.log({
        usuarioId: user.userId,
        tipoEvento: 'WEBAUTHN_REGISTRADO',
        sucesso: true,
        ip,
        userAgent,
        detalhes: { metodo: 'WEBAUTHN_BIOMETRIA', deviceName }
      });

      return res.status(200).json({
        success: true,
        message: 'Biometria cadastrada com sucesso neste dispositivo!'
      });
    } catch (error: any) {
      logger.error('[WebAuthnController.registerVerify] Erro:', { correlationId: req.correlationId, error: error.message });
      return res.status(400).json({ error: error.message || 'Falha ao validar biometria.' });
    }
  }

  public static async loginOptions(req: Request, res: Response) {
    try {
      if (!(await WebAuthnController.validatePwaExclusive(req))) {
        return res.status(403).json({
          error: 'A autenticação biométrica é autorizada exclusivamente no aplicativo PWA corporativo instalado.'
        });
      }

      const { emailOrMatricula } = req.body || {};
      const rpId = WebAuthnService.getRpId(req.headers.origin as string, req.headers.host);

      const { options, challengeKey } = await WebAuthnService.generateAuthOptions(rpId, emailOrMatricula);

      return res.status(200).json({
        options,
        challengeKey
      });
    } catch (error: any) {
      logger.error('[WebAuthnController.loginOptions] Erro:', { correlationId: req.correlationId, error: error.message });
      return res.status(500).json({ error: 'Erro ao gerar desafio biométrico.' });
    }
  }

  public static async loginVerify(req: Request, res: Response) {
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);
    const { challengeKey, response } = req.body;

    if (!challengeKey || !response) {
      return res.status(400).json({ error: 'Chave do desafio e resposta biométrica são obrigatórias.' });
    }

    try {
      if (!(await WebAuthnController.validatePwaExclusive(req))) {
        return res.status(403).json({
          error: 'A autenticação biométrica é autorizada exclusivamente no aplicativo PWA corporativo instalado.'
        });
      }

      const rpId = WebAuthnService.getRpId(req.headers.origin as string, req.headers.host);
      const expectedOrigin = WebAuthnService.getExpectedOrigin(req.headers.origin as string, req.headers.host);

      const result = await WebAuthnService.verifyAuth(
        challengeKey,
        response,
        expectedOrigin,
        rpId
      );

      const user = result.user;

      // Invalidação de sessões ativas anteriores
      await TokenService.incrementarTokenVersion(user.id);
      const activeTokenVersion = (user.token_version || 1) + 1;
      const authTime = Math.floor(Date.now() / 1000);

      // Emissão do Token JWT
      const token = jwt.sign({
        userId: user.id,
        nome: user.nome,
        email: user.email,
        matricula: user.matricula,
        perfil: user.perfil,
        permissaoRh: user.permissao_rh === true || user.perfil === 'ADMIN_RH',
        permissaoTi: user.permissao_ti === true || user.perfil === 'ADMIN_TI',
        departamentoId: user.departamento_id,
        departamentoNome: user.departamento_nome,
        tokenVersion: activeTokenVersion,
        authTime
      }, JWT_SECRET, { expiresIn: JWT_EXPIRATION as any });

      // Emissão de Refresh Token
      const refreshToken = await TokenService.gerarRefreshToken(user.id, ip, userAgent);

      AuditService.log({
        usuarioId: user.id,
        tipoEvento: 'LOGIN_SUCESSO',
        sucesso: true,
        ip,
        userAgent,
        detalhes: { metodo: 'WEBAUTHN_BIOMETRIA', perfil: user.perfil }
      });

      return res.status(200).json({
        token,
        refreshToken,
        user: toUserResponseDto(user)
      });
    } catch (error: any) {
      AuditService.log({
        tipoEvento: 'LOGIN_FALHA_SENHA',
        sucesso: false,
        ip,
        userAgent,
        detalhes: { motivo: 'Falha na validação biométrica', erro: error.message }
      });
      return res.status(401).json({ error: error.message || 'Falha na autenticação biométrica.' });
    }
  }

  public static async listDevices(req: AuthenticatedRequest, res: Response) {
    try {
      const user = req.user;
      if (!user) {
        return res.status(401).json({ error: 'Não autenticado.' });
      }

      const devices = await WebAuthnService.listUserPasskeys(user.userId);
      return res.status(200).json(devices);
    } catch (error: any) {
      return res.status(500).json({ error: 'Erro ao listar dispositivos biométricos.' });
    }
  }

  public static async deleteDevice(req: AuthenticatedRequest, res: Response) {
    try {
      const user = req.user;
      if (!user) {
        return res.status(401).json({ error: 'Não autenticado.' });
      }

      const passkeyId = parseInt(req.params.id, 10);
      if (isNaN(passkeyId)) {
        return res.status(400).json({ error: 'ID de dispositivo inválido.' });
      }

      const deleted = await WebAuthnService.deleteUserPasskey(user.userId, passkeyId);
      if (!deleted) {
        return res.status(404).json({ error: 'Dispositivo não encontrado.' });
      }

      return res.status(200).json({ message: 'Dispositivo biométrico removido com sucesso.' });
    } catch (error: any) {
      return res.status(500).json({ error: 'Erro ao remover dispositivo.' });
    }
  }
}

