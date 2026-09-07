import { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';

/**
 * Middleware to authenticate SCIM 2.0 Provisioning requests (RFC 7644).
 * Expects Authorization: Bearer <SCIM_BEARER_TOKEN>
 */
export function scimAuth(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      schemas: ['urn:ietf:params:scim:api:messages:2.0:Error'],
      status: '401',
      detail: 'Missing or invalid Authorization Bearer header.'
    });
  }

  const token = authHeader.substring(7).trim();
  const configuredToken = process.env.SCIM_BEARER_TOKEN;

  if (!configuredToken) {
    return res.status(500).json({
      schemas: ['urn:ietf:params:scim:api:messages:2.0:Error'],
      status: '500',
      detail: 'SCIM authentication is not configured on the server. SCIM_BEARER_TOKEN is missing.'
    });
  }

  try {
    const tokenBuffer = Buffer.from(token, 'utf-8');
    const configuredBuffer = Buffer.from(configuredToken, 'utf-8');

    if (tokenBuffer.length !== configuredBuffer.length || !crypto.timingSafeEqual(tokenBuffer, configuredBuffer)) {
      return res.status(401).json({
        schemas: ['urn:ietf:params:scim:api:messages:2.0:Error'],
        status: '401',
        detail: 'Invalid SCIM Bearer token.'
      });
    }

    next();
  } catch (err) {
    return res.status(401).json({
      schemas: ['urn:ietf:params:scim:api:messages:2.0:Error'],
      status: '401',
      detail: 'Authentication failed.'
    });
  }
}

