import { Request, Response } from 'express';
import { logger } from '../utils/logger';
import { AuditService } from '../services/auditService';

/**
 * Controller para recepção de relatórios de violação de Content Security Policy (CSP)
 * Endpoint de conformidade para observabilidade de segurança web
 */
export class CspReportController {
  public static handleReport(req: Request, res: Response) {
    const ip = AuditService.getClientIp(req);
    const userAgent = AuditService.getUserAgent(req);
    const report = req.body?.['csp-report'] || req.body;

    logger.warn('[CSP Violation Report] Violação de política de segurança detectada pelo navegador:', {
      ip,
      userAgent,
      blockedUri: report?.['blocked-uri'] || report?.blockedUri,
      violatedDirective: report?.['violated-directive'] || report?.violatedDirective,
      effectiveDirective: report?.['effective-directive'] || report?.effectiveDirective,
      originalPolicy: report?.['original-policy'] || report?.originalPolicy,
      documentUri: report?.['document-uri'] || report?.documentUri,
      referrer: report?.referrer,
      statusCode: report?.['status-code'] || report?.statusCode
    });

    // Resposta padrão RFC 204 No Content para coletores de telemetria
    return res.status(204).end();
  }
}

