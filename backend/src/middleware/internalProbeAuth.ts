import { timingSafeEqual } from 'crypto';
import { NextFunction, Request, Response } from 'express';

const configuredToken = (): string => (process.env.INTERNAL_HEALTH_TOKEN || '').trim();

export function internalProbeAuth(req: Request, res: Response, next: NextFunction): void {
  const expected = configuredToken();

  if (!expected && process.env.NODE_ENV !== 'production' && process.env.NODE_ENV !== 'staging') {
    next();
    return;
  }

  const supplied = typeof req.headers['x-health-token'] === 'string'
    ? req.headers['x-health-token']
    : '';
  const expectedBuffer = Buffer.from(expected);
  const suppliedBuffer = Buffer.from(supplied);

  if (expected && expectedBuffer.length === suppliedBuffer.length && timingSafeEqual(expectedBuffer, suppliedBuffer)) {
    next();
    return;
  }

  res.status(404).json({ error: 'Not Found' });
}